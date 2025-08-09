import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/painting.dart';

// Re-export existing types from image_service.dart
export 'image_service.dart' show ImageType, ImageFormat, ProcessedImage, ImageMetadata, ImageServiceException;

/// Image status enum for state tracking
enum ImageStatus {
  none,         // No image
  loading,      // Downloading from Firebase
  stored,       // Available in permanent local storage, synced with cloud
  uploading,    // Uploading to Firebase
  pendingSync,  // In local storage only, waiting to sync to cloud
  error,        // Failed to load/upload
}

/// Upload queue item for offline support
class UploadQueueItem {
  final String relativePath;
  final String localTempPath;
  final DateTime timestamp;
  final int retryCount;
  
  UploadQueueItem({
    required this.relativePath,
    required this.localTempPath,
    required this.timestamp,
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'localTempPath': localTempPath,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };
  
  factory UploadQueueItem.fromJson(Map<String, dynamic> json) => UploadQueueItem(
    relativePath: json['relativePath'],
    localTempPath: json['localTempPath'],
    timestamp: DateTime.parse(json['timestamp']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Image state information
class ImageState {
  final String? relativePath;
  final ImageStatus status;
  final File? localFile;
  final bool hasPendingUpload;
  final DateTime? lastSyncTime;
  final String? error;
  final double? uploadProgress;
  
  ImageState({
    this.relativePath,
    required this.status,
    this.localFile,
    this.hasPendingUpload = false,
    this.lastSyncTime,
    this.error,
    this.uploadProgress,
  });
}

/// Enhanced ImageService with permanent local storage and offline-first architecture
/// Uses Application Documents Directory for persistent storage (NOT temporary cache)
/// Ensures images remain available offline for construction site usage
class EnhancedImageService {
  // Singleton instance
  static EnhancedImageService? _instance;
  
  // Reset singleton for testing
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
  
  // Dependencies
  late final FirebaseStorage _storage;
  late final ImagePicker _imagePicker;
  late final http.Client _httpClient;
  late final Connectivity _connectivity;
  
  // Permanent local storage directory (Application Documents Directory)
  // NOT a temporary cache - images persist until explicitly deleted
  Directory? _localStorageDir;
  
  // State management
  final Map<String, ImageStatus> _imageStates = {};
  final Map<String, StreamController<ImageStatus>> _stateControllers = {};
  
  // Connection state cache
  bool? _isOnline;
  DateTime? _lastConnectionCheck;
  
  // Upload queue
  static const String _uploadQueueKey = 'image_upload_queue';
  static const String _manualRetryQueueKey = 'image_manual_retry_queue';
  static const int _maxRetries = 3;
  
  // Retry delays with exponential backoff
  static const List<Duration> _retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];
  
  // Factory constructor
  factory EnhancedImageService({
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
    http.Client? httpClient,
    Connectivity? connectivity,
  }) {
    _instance ??= EnhancedImageService._internal();
    
    // Allow dependency injection for testing
    if (storage != null) {
      try {
        _instance!._storage;
      } catch (_) {
        _instance!._storage = storage;
      }
    }
    
    if (imagePicker != null) {
      try {
        _instance!._imagePicker;
      } catch (_) {
        _instance!._imagePicker = imagePicker;
      }
    }
    
    if (httpClient != null) {
      try {
        _instance!._httpClient;
      } catch (_) {
        _instance!._httpClient = httpClient;
      }
    }
    
    if (connectivity != null) {
      try {
        _instance!._connectivity;
      } catch (_) {
        _instance!._connectivity = connectivity;
      }
    }
    
    return _instance!;
  }
  
  // Private constructor
  EnhancedImageService._internal() {
    _initializeConnectivityListener();
  }
  
  /// Initialize dependencies
  void _ensureInitialized() {
    try {
      _storage;
    } catch (_) {
      _storage = FirebaseStorage.instance;
    }
    
    try {
      _imagePicker;
    } catch (_) {
      _imagePicker = ImagePicker();
    }
    
    try {
      _httpClient;
    } catch (_) {
      _httpClient = http.Client();
    }
    
    try {
      _connectivity;
    } catch (_) {
      _connectivity = Connectivity();
    }
  }
  
  /// Initialize connectivity listener for auto-sync
  void _initializeConnectivityListener() {
    _ensureInitialized();
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Check if any of the results indicate we have connectivity
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        // Process pending uploads when connection is restored
        processPendingUploads();
      }
    });
  }
  
  /// Initialize permanent local storage directory
  /// Uses Application Documents Directory for persistent offline storage
  Future<void> _initLocalStorageDir() async {
    if (_localStorageDir != null) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _localStorageDir = Directory(p.join(appDir.path, 'local_image_storage'));
      
      if (!await _localStorageDir!.exists()) {
        await _localStorageDir!.create(recursive: true);
        if (kDebugMode) print('EnhancedImageService: Created local storage directory');
      }
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error initializing local storage: $e');
      _logError(e, 'Failed to initialize local image storage directory');
    }
  }
  
  /// Convert relative path to Firebase Storage URL
  String getFirebaseUrl(String relativePath) {
    _ensureInitialized();
    final encodedPath = Uri.encodeComponent(relativePath);
    return 'https://firebasestorage.googleapis.com/v0/b/${_storage.bucket}/o/$encodedPath?alt=media';
  }
  
  /// Get local storage path for relative path
  /// Returns permanent storage location in Application Documents Directory
  String getLocalPath(String relativePath) {
    if (_localStorageDir == null) {
      // Return a temporary path that won't be used until storage is initialized
      return p.join(Directory.systemTemp.path, 'local_image_storage', relativePath);
    }
    return p.join(_localStorageDir!.path, relativePath);
  }
  
  /// Resolve path to either local file or Firebase URL
  Future<String> resolvePath(String relativePath) async {
    await _initLocalStorageDir();
    
    // Check permanent local storage first
    final localPath = getLocalPath(relativePath);
    final localFile = File(localPath);
    
    if (await localFile.exists()) {
      if (kDebugMode) print('EnhancedImageService: Using locally stored file for $relativePath');
      return localPath;
    }
    
    // Fallback to Firebase URL
    if (kDebugMode) print('EnhancedImageService: Using Firebase URL for $relativePath');
    return getFirebaseUrl(relativePath);
  }
  
  /// Check if online with caching to reduce redundant checks
  Future<bool> isOnline() async {
    // Cache connection state for 5 seconds
    if (_isOnline != null && 
        _lastConnectionCheck != null &&
        DateTime.now().difference(_lastConnectionCheck!).inSeconds < 5) {
      return _isOnline!;
    }
    
    _ensureInitialized();
    final results = await _connectivity.checkConnectivity();
    // We're online if we have any connectivity that's not 'none'
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _lastConnectionCheck = DateTime.now();
    return _isOnline!;
  }
  
  /// Upload profile image with offline support
  Future<String?> uploadProfileImage({
    required Uint8List imageData,
    required String userId,
  }) async {
    final relativePath = '$userId/profile.jpg';
    
    try {
      // Update state
      setImageState(relativePath, ImageStatus.uploading);
      
      // Save to permanent local storage first
      await storeImageLocally(relativePath, imageData, null);
      
      // Check if online
      if (await isOnline()) {
        // Try to upload
        try {
          await uploadToStorage(relativePath, imageData);
          setImageState(relativePath, ImageStatus.stored);
          return relativePath;
        } catch (e) {
          if (kDebugMode) print('EnhancedImageService: Upload failed, queuing: $e');
          await queueForUpload(relativePath, imageData);
          setImageState(relativePath, ImageStatus.pendingSync);
          return relativePath; // Still return path for local display
        }
      } else {
        // Offline - queue for later
        await queueForUpload(relativePath, imageData);
        setImageState(relativePath, ImageStatus.pendingSync);
        return relativePath;
      }
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error in uploadProfileImage: $e');
      setImageState(relativePath, ImageStatus.error, error: e.toString());
      _logError(e, 'Failed to upload profile image');
      rethrow;
    }
  }
  
  /// Upload to Firebase Storage
  Future<void> uploadToStorage(String relativePath, Uint8List imageData) async {
    _ensureInitialized();
    
    // TEST: Simulate network failure
    if (const bool.fromEnvironment('TEST_NETWORK_FAILURE', defaultValue: false)) {
      if (kDebugMode) print('EnhancedImageService: TEST - Simulating network failure');
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'network-error',
        message: 'A network error occurred',
      );
    }
    
    final ref = _storage.ref(relativePath);
    final contentType = relativePath.endsWith('.png') ? 'image/png' : 'image/jpeg';
    
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
    
    await ref.putData(imageData, metadata);
    if (kDebugMode) print('EnhancedImageService: Upload complete for $relativePath');
  }
  
  /// Queue image for upload when offline
  Future<void> queueForUpload(String relativePath, Uint8List imageData) async {
    await _initLocalStorageDir();
    
    // Save to temporary location for pending uploads
    final tempPath = p.join(_localStorageDir!.path, 'pending', relativePath);
    final tempFile = File(tempPath);
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(imageData);
    
    // Add to upload queue
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_uploadQueueKey) ?? [];
    
    final queueItem = UploadQueueItem(
      relativePath: relativePath,
      localTempPath: tempPath,
      timestamp: DateTime.now(),
    );
    
    queue.add(jsonEncode(queueItem.toJson()));
    await prefs.setStringList(_uploadQueueKey, queue);
    
    if (kDebugMode) print('EnhancedImageService: Queued upload for $relativePath');
  }
  
  /// Process pending uploads
  Future<void> processPendingUploads() async {
    if (!await isOnline()) return;
    
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_uploadQueueKey) ?? [];
    final updatedQueue = <String>[];
    final manualRetryQueue = prefs.getStringList(_manualRetryQueueKey) ?? [];
    
    for (final itemJson in queue) {
      final item = UploadQueueItem.fromJson(jsonDecode(itemJson));
      
      try {
        // Read image data
        final tempFile = File(item.localTempPath);
        if (!await tempFile.exists()) {
          if (kDebugMode) print('EnhancedImageService: Temp file missing for ${item.relativePath}');
          continue; // Skip this item
        }
        
        final imageData = await tempFile.readAsBytes();
        
        // Try upload
        await uploadToStorage(item.relativePath, imageData);
        
        // Success - update state and clean up
        setImageState(item.relativePath, ImageStatus.stored);
        await tempFile.delete();
        
        if (kDebugMode) print('EnhancedImageService: Uploaded queued item ${item.relativePath}');
      } catch (e) {
        if (kDebugMode) print('EnhancedImageService: Failed to upload queued item: $e');
        
        // Increment retry count
        final updatedItem = UploadQueueItem(
          relativePath: item.relativePath,
          localTempPath: item.localTempPath,
          timestamp: item.timestamp,
          retryCount: item.retryCount + 1,
        );
        
        if (updatedItem.retryCount >= _maxRetries) {
          // Move to manual retry queue
          manualRetryQueue.add(jsonEncode(updatedItem.toJson()));
          if (kDebugMode) print('EnhancedImageService: Moved to manual retry: ${item.relativePath}');
        } else {
          // Keep in automatic queue
          updatedQueue.add(jsonEncode(updatedItem.toJson()));
        }
      }
    }
    
    // Update queues
    await prefs.setStringList(_uploadQueueKey, updatedQueue);
    await prefs.setStringList(_manualRetryQueueKey, manualRetryQueue);
  }
  
  /// Get manual retry queue items
  Future<List<UploadQueueItem>> getManualRetryQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_manualRetryQueueKey) ?? [];
    return queue.map((json) => UploadQueueItem.fromJson(jsonDecode(json))).toList();
  }
  
  /// Retry manual upload
  Future<void> retryManualUpload(String relativePath) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_manualRetryQueueKey) ?? [];
    final updatedQueue = <String>[];
    
    for (final itemJson in queue) {
      final item = UploadQueueItem.fromJson(jsonDecode(itemJson));
      
      if (item.relativePath == relativePath) {
        // Move back to automatic queue with reset retry count
        final resetItem = UploadQueueItem(
          relativePath: item.relativePath,
          localTempPath: item.localTempPath,
          timestamp: item.timestamp,
          retryCount: 0,
        );
        
        final autoQueue = prefs.getStringList(_uploadQueueKey) ?? [];
        autoQueue.add(jsonEncode(resetItem.toJson()));
        await prefs.setStringList(_uploadQueueKey, autoQueue);
        
        // Process immediately
        await processPendingUploads();
      } else {
        updatedQueue.add(itemJson);
      }
    }
    
    await prefs.setStringList(_manualRetryQueueKey, updatedQueue);
  }
  
  /// Store image in permanent local storage
  /// Images persist in Application Documents Directory until explicitly deleted
  Future<void> storeImageLocally(String relativePath, Uint8List data, dynamic metadata) async {
    try {
      await _initLocalStorageDir();
      
      final localFile = File(getLocalPath(relativePath));
      
      // If file already exists, evict it from Flutter's memory cache (different from our permanent storage)
      if (await localFile.exists()) {
        final fileImage = FileImage(localFile);
        PaintingBinding.instance.imageCache.evict(fileImage);
        if (kDebugMode) print('EnhancedImageService: Evicted old image from Flutter memory cache');
      }
      
      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(data);
      
      // Save metadata
      final metadataFile = File('${localFile.path}.metadata');
      final metadataJson = {
        'etag': metadata is FullMetadata ? metadata.md5Hash : null,
        'lastModified': DateTime.now().toIso8601String(),
        'size': data.length,
      };
      await metadataFile.writeAsString(jsonEncode(metadataJson));
      
      if (kDebugMode) print('EnhancedImageService: Stored image locally at: ${localFile.path}');
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error storing image locally: $e');
      // Don't throw - local storage errors shouldn't break the app
    }
  }
  
  /// Get image from permanent local storage
  /// Returns null if image not found in local storage
  Future<Uint8List?> getLocallyStoredImage(String relativePath) async {
    try {
      await _initLocalStorageDir();
      
      final localFile = File(getLocalPath(relativePath));
      if (await localFile.exists()) {
        return await localFile.readAsBytes();
      }
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error reading locally stored image: $e');
    }
    return null;
  }
  
  /// Validate local storage using ETag
  /// Checks if locally stored image is still current by comparing ETags
  Future<bool> validateLocalStorage(String relativePath, String url) async {
    // Skip validation if offline
    if (!await isOnline()) {
      if (kDebugMode) print('EnhancedImageService: Offline - assuming local storage valid');
      return true;
    }
    
    try {
      // Get locally stored metadata
      final metadataFile = File('${getLocalPath(relativePath)}.metadata');
      if (!await metadataFile.exists()) return false;
      
      final storedMetadata = jsonDecode(await metadataFile.readAsString());
      final storedEtag = storedMetadata['etag'];
      
      if (storedEtag == null) return false;
      
      // Get current metadata from Firebase
      _ensureInitialized();
      final ref = _storage.refFromURL(url);
      final currentMetadata = await ref.getMetadata();
      
      // Compare ETags
      final isValid = storedEtag == currentMetadata.md5Hash;
      if (kDebugMode) {
        print('EnhancedImageService: Local storage validation for $relativePath: '
              '${isValid ? "valid" : "stale"}');
      }
      return isValid;
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error validating local storage: $e');
      return false;
    }
  }
  
  /// Get image with background validation
  Future<Uint8List?> getImageWithBackgroundValidation({
    required String relativePath,
  }) async {
    if (kDebugMode) print('EnhancedImageService: getImageWithBackgroundValidation for $relativePath');
    
    // First, return locally stored image immediately if available
    final storedData = await getLocallyStoredImage(relativePath);
    
    if (kDebugMode) print('EnhancedImageService: Local storage check for $relativePath: ${storedData != null ? "Found (${storedData.length} bytes)" : "Not found"}');
    
    if (storedData != null) {
      // Validate in background
      final url = getFirebaseUrl(relativePath);
      validateLocalStorage(relativePath, url).then((isValid) async {
        if (!isValid && await isOnline()) {
          // Download fresh version in background
          try {
            final response = await _httpClient.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await storeImageLocally(relativePath, response.bodyBytes, null);
              // Notify listeners about the update
              setImageState(relativePath, ImageStatus.stored);
            }
          } catch (e) {
            if (kDebugMode) print('EnhancedImageService: Background refresh failed: $e');
            _logError(e, 'Background image refresh failed for $relativePath');
            // Don't update state to error - keep showing locally stored version
          }
        }
      }).catchError((e) {
        if (kDebugMode) print('EnhancedImageService: Local storage validation error: $e');
        // Continue using locally stored image on validation error
      });
      
      return storedData;
    }
    
    // No local storage - download if online
    if (await isOnline()) {
      try {
        final url = getFirebaseUrl(relativePath);
        final response = await _httpClient.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = response.bodyBytes;
          await storeImageLocally(relativePath, data, null);
          return data;
        }
      } catch (e) {
        if (kDebugMode) print('EnhancedImageService: Download failed: $e');
      }
    }
    
    return null;
  }
  
  /// Set image state
  void setImageState(String relativePath, ImageStatus status, {String? error}) {
    _imageStates[relativePath] = status;
    
    // Notify listeners
    if (_stateControllers.containsKey(relativePath)) {
      _stateControllers[relativePath]!.add(status);
    }
    
    if (kDebugMode) {
      print('EnhancedImageService: State for $relativePath: $status'
            '${error != null ? " (Error: $error)" : ""}');
    }
  }
  
  /// Get image state
  ImageStatus getImageState(String relativePath) {
    return _imageStates[relativePath] ?? ImageStatus.none;
  }
  
  /// Stream of image state changes
  Stream<ImageStatus> imageStateStream(String relativePath) {
    // Clean up closed controllers
    _stateControllers.removeWhere((key, controller) => controller.isClosed);
    
    _stateControllers[relativePath] ??= StreamController<ImageStatus>.broadcast(
      onCancel: () {
        // Clean up controller when no more listeners
        Future.delayed(const Duration(seconds: 1), () {
          if (_stateControllers[relativePath]?.hasListener == false) {
            _stateControllers[relativePath]?.close();
            _stateControllers.remove(relativePath);
          }
        });
      },
    );
    return _stateControllers[relativePath]!.stream;
  }
  
  /// Clean orphaned files from local storage
  /// Removes files that exist locally but are no longer referenced in Firestore
  Future<void> cleanOrphanedLocalStorage({
    required List<String> localFiles,
    required List<String> firestorePaths,
  }) async {
    await _initLocalStorageDir();
    
    final pathSet = firestorePaths.toSet();
    
    for (final localFile in localFiles) {
      if (!pathSet.contains(localFile)) {
        try {
          final file = File(getLocalPath(localFile));
          if (await file.exists()) {
            await file.delete();
            if (kDebugMode) print('EnhancedImageService: Deleted orphaned local file: $localFile');
          }
          
          // Also delete metadata
          final metadataFile = File('${file.path}.metadata');
          if (await metadataFile.exists()) {
            await metadataFile.delete();
          }
        } catch (e) {
          if (kDebugMode) print('EnhancedImageService: Error deleting orphaned local file: $e');
        }
      }
    }
  }
  
  /// Clear all user local storage
  /// Completely removes all locally stored images for privacy and logout
  Future<void> clearAllUserLocalStorage() async {
    try {
      await _initLocalStorageDir();
      
      if (_localStorageDir != null && await _localStorageDir!.exists()) {
        await _localStorageDir!.delete(recursive: true);
        await _localStorageDir!.create(recursive: true);
        if (kDebugMode) print('EnhancedImageService: All user local storage cleared');
      }
      
      // Clear upload queues
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_uploadQueueKey);
      await prefs.remove(_manualRetryQueueKey);
      
      // Clear state
      _imageStates.clear();
      for (final controller in _stateControllers.values) {
        await controller.close();
      }
      _stateControllers.clear();
    } catch (e) {
      if (kDebugMode) print('EnhancedImageService: Error clearing all user local storage: $e');
      _logError(e, 'Failed to clear all user local image storage');
    }
  }
  
  /// Smart image widget for easy UI integration
  Widget smartImage({
    required String? relativePath,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    Key? imageKey,
  }) {
    if (relativePath == null || relativePath.isEmpty) {
      return placeholder ?? Container();
    }
    
    return StreamBuilder<ImageStatus>(
      stream: imageStateStream(relativePath),
      initialData: getImageState(relativePath),
      builder: (context, snapshot) {
        final status = snapshot.data ?? ImageStatus.none;
        
        switch (status) {
          case ImageStatus.none:
          case ImageStatus.loading:
            return FutureBuilder<Uint8List?>(
              future: getImageWithBackgroundValidation(relativePath: relativePath),
              builder: (context, imageSnapshot) {
                if (imageSnapshot.hasData && imageSnapshot.data != null) {
                  return Image.memory(
                    imageSnapshot.data!,
                    width: width,
                    height: height,
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) =>
                        errorWidget ?? _buildErrorWidget(context),
                  );
                }
                if (kDebugMode) print('EnhancedImageService.smartImage: Showing placeholder for $relativePath');
                return placeholder ?? _buildLoadingWidget(context);
              },
            );
            
          case ImageStatus.stored:
          case ImageStatus.uploading:
          case ImageStatus.pendingSync:
            return FutureBuilder<String>(
              future: resolvePath(relativePath),
              builder: (context, pathSnapshot) {
                if (!pathSnapshot.hasData) {
                  return placeholder ?? _buildLoadingWidget(context);
                }
                
                final path = pathSnapshot.data!;
                Widget imageWidget;
                
                if (path.startsWith('http')) {
                  // Network image
                  imageWidget = Image.network(
                    path,
                    width: width,
                    height: height,
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) =>
                        errorWidget ?? _buildErrorWidget(context),
                  );
                } else {
                  // Local file
                  imageWidget = Image.file(
                    File(path),
                    width: width,
                    height: height,
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) =>
                        errorWidget ?? _buildErrorWidget(context),
                  );
                }
                
                // Add overlay indicators
                if (status == ImageStatus.uploading) {
                  return Stack(
                    children: [
                      imageWidget,
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (status == ImageStatus.pendingSync) {
                  return Stack(
                    children: [
                      imageWidget,
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.sync,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                
                return imageWidget;
              },
            );
            
          case ImageStatus.error:
            return errorWidget ?? _buildErrorWidget(context);
        }
      },
    );
  }
  
  Widget _buildLoadingWidget(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
  
  /// Log error to Crashlytics
  void _logError(dynamic error, String reason) {
    try {
      FirebaseCrashlytics.instance.recordError(error, null, reason: reason);
    } catch (_) {
      // Firebase not initialized in tests - ignore
    }
  }
  
  /// Dispose resources
  void dispose() {
    for (final controller in _stateControllers.values) {
      controller.close();
    }
    _stateControllers.clear();
    _imageStates.clear();
  }
}