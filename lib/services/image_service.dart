import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Enum defining different image types with their specifications
enum ImageType {
  profile(1200, 1200, 400000, 0.85, ImageFormat.jpeg),
  signature(600, 300, 200000, 1.0, ImageFormat.png),
  site(1200, 1200, 400000, 0.85, ImageFormat.jpeg),
  snag(800, 800, 250000, 0.85, ImageFormat.jpeg),
  thumbnail(200, 200, 25000, 0.80, ImageFormat.jpeg);
  
  final int maxWidth;
  final int maxHeight;
  final int maxSizeBytes;
  final double initialQuality;
  final ImageFormat format;
  
  const ImageType(
    this.maxWidth,
    this.maxHeight,
    this.maxSizeBytes,
    this.initialQuality,
    this.format,
  );
}

/// Enum for image formats
enum ImageFormat { jpeg, png }

/// Data class for processed images
class ProcessedImage {
  final Uint8List data;
  final Uint8List? thumbnail;
  final ImageMetadata metadata;
  final ImageFormat format;
  final double quality;
  final int maxWidth;
  final int maxHeight;
  
  ProcessedImage({
    required this.data,
    this.thumbnail,
    required this.metadata,
    required this.format,
    required this.quality,
    required this.maxWidth,
    required this.maxHeight,
  });
}

/// Metadata for cached images
class ImageMetadata {
  final String? etag;
  final DateTime? lastModified;
  final int size;
  
  ImageMetadata({
    this.etag,
    this.lastModified,
    required this.size,
  });
  
  Map<String, dynamic> toJson() => {
    'etag': etag,
    'lastModified': lastModified?.toIso8601String(),
    'size': size,
  };
  
  factory ImageMetadata.fromJson(Map<String, dynamic> json) => ImageMetadata(
    etag: json['etag'],
    lastModified: json['lastModified'] != null 
        ? DateTime.parse(json['lastModified']) 
        : null,
    size: json['size'],
  );
}

/// Custom exception for ImageService errors
class ImageServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  ImageServiceException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => 'ImageServiceException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Centralized service for all image operations
class ImageService {
  // Singleton instance
  static ImageService? _instance;
  
  // Reset singleton for testing
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }
  
  // Dependencies
  late final FirebaseStorage _storage;
  late final ImagePicker _imagePicker;
  late final http.Client _httpClient;
  
  // Cache directory
  Directory? _cacheDir;
  
  // Factory constructor returns singleton instance
  factory ImageService({
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
    http.Client? httpClient,
  }) {
    // Create instance if it doesn't exist
    _instance ??= ImageService._internal();
    
    // Allow dependency injection for testing only if not already initialized
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
    
    return _instance!;
  }
  
  // Private constructor - defer initialization for testing
  ImageService._internal();
  
  /// Initialize dependencies if not already set (for production use)
  void _ensureInitialized() {
    // Initialize Firebase Storage if not injected
    try {
      _storage;
    } catch (_) {
      _storage = FirebaseStorage.instance;
    }
    
    // Initialize ImagePicker if not injected
    try {
      _imagePicker;
    } catch (_) {
      _imagePicker = ImagePicker();
    }
    
    // Initialize HTTP Client if not injected
    try {
      _httpClient;
    } catch (_) {
      _httpClient = http.Client();
    }
  }
  
  /// Initialize cache directory
  Future<void> _initCacheDir() async {
    if (_cacheDir != null) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(p.join(appDir.path, 'image_cache'));
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        if (kDebugMode) print('ImageService: Created cache directory');
      }
    } catch (e) {
      if (kDebugMode) print('ImageService: Error initializing cache: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, null,
            reason: 'Failed to initialize image cache directory');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
    }
  }
  
  /// Capture image from camera or gallery
  Future<ProcessedImage?> captureImage({
    required ImageSource source,
    required ImageType type,
  }) async {
    try {
      _ensureInitialized();
      if (kDebugMode) print('ImageService: Capturing image from $source');
      
      
      // Pick image with initial size constraints
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: type.maxWidth.toDouble(),
        maxHeight: type.maxHeight.toDouble(),
      );
      
      if (pickedFile == null) {
        if (kDebugMode) print('ImageService: User cancelled image selection');
        return null;
      }
      
      // Read image bytes
      final imageBytes = await pickedFile.readAsBytes();
      if (kDebugMode) print('ImageService: Read ${imageBytes.length} bytes');
      
      // Process the image
      return await processImage(
        imageBytes: imageBytes,
        type: type,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error capturing image: $e');
      // Only log to Crashlytics if Firebase is initialized
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to capture image from $source');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
      throw ImageServiceException(
        'Failed to capture image',
        originalError: e,
      );
    }
  }
  
  /// Process image according to type specifications
  Future<ProcessedImage> processImage({
    required Uint8List imageBytes,
    required ImageType type,
    bool generateThumbnail = false,
  }) async {
    try {
      if (kDebugMode) print('ImageService: Processing image of type $type');
      
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw ImageServiceException('Failed to decode image - corrupt or unsupported format');
      }
      
      // Resize if needed
      if (image.width > type.maxWidth || image.height > type.maxHeight) {
        if (kDebugMode) {
          print('ImageService: Resizing from ${image.width}x${image.height} '
                'to max ${type.maxWidth}x${type.maxHeight}');
        }
        
        // Calculate new dimensions maintaining aspect ratio
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // Landscape
          newWidth = type.maxWidth;
          newHeight = (type.maxWidth / aspectRatio).round();
        } else {
          // Portrait or square
          newHeight = type.maxHeight;
          newWidth = (type.maxHeight * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Convert and compress
      Uint8List processedData;
      double quality = type.initialQuality;
      ImageFormat format = type.format;
      
      if (type.format == ImageFormat.jpeg) {
        // Convert to JPEG with quality compression
        processedData = Uint8List.fromList(
          img.encodeJpg(image, quality: (quality * 100).round()),
        );
        
        // Recursive compression if size exceeds limit
        while (processedData.length > type.maxSizeBytes && quality > 0.6) {
          quality -= 0.05;
          if (kDebugMode) {
            print('ImageService: Size ${processedData.length} exceeds limit '
                  '${type.maxSizeBytes}, reducing quality to $quality');
          }
          processedData = Uint8List.fromList(
            img.encodeJpg(image, quality: (quality * 100).round()),
          );
        }
      } else {
        // Keep as PNG (for signatures)
        processedData = Uint8List.fromList(img.encodePng(image));
        format = ImageFormat.png;
      }
      
      if (kDebugMode) {
        print('ImageService: Final size: ${processedData.length} bytes, '
              'quality: $quality, format: $format');
      }
      
      // Generate thumbnail if requested
      Uint8List? thumbnailData;
      if (generateThumbnail) {
        if (kDebugMode) print('ImageService: Generating thumbnail');
        
        final thumbnailImage = img.copyResize(
          image,
          width: ImageType.thumbnail.maxWidth,
          height: ImageType.thumbnail.maxHeight,
        );
        
        thumbnailData = Uint8List.fromList(
          img.encodeJpg(thumbnailImage, quality: 80),
        );
        
        if (kDebugMode) {
          print('ImageService: Thumbnail size: ${thumbnailData.length} bytes');
        }
      }
      
      return ProcessedImage(
        data: processedData,
        thumbnail: thumbnailData,
        metadata: ImageMetadata(size: processedData.length),
        format: format,
        quality: quality,
        maxWidth: type.maxWidth,
        maxHeight: type.maxHeight,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error processing image: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to process image');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
      
      if (e is ImageServiceException) rethrow;
      
      throw ImageServiceException(
        'Failed to process image',
        originalError: e,
      );
    }
  }
  
  /// Upload image to Firebase Storage
  Future<String> uploadImage({
    required Uint8List imageData,
    required String path,
    String? contentType,
  }) async {
    try {
      _ensureInitialized();
      if (kDebugMode) print('ImageService: Uploading to path: $path');
      
      // Determine content type from path if not provided
      contentType ??= path.endsWith('.png') ? 'image/png' : 'image/jpeg';
      
      // Create reference
      final ref = _storage.ref(path);
      
      // Debug: Log storage bucket URL
      if (kDebugMode) {
        print('ImageService: Storage bucket: ${_storage.bucket}');
        print('ImageService: Full reference path: ${ref.fullPath}');
      }
      
      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      
      final uploadTask = ref.putData(imageData, metadata);
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) print('ImageService: Upload complete, URL: $downloadUrl');
      
      // Cache the uploaded image
      await _cacheImage(path, imageData, metadata);
      
      return downloadUrl;
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Upload error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to upload image to Firebase Storage');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
      
      if (e is FirebaseException && e.code == 'unauthorized') {
        throw ImageServiceException(
          'Permission denied - please check your authentication',
          code: 'unauthorized',
          originalError: e,
        );
      }
      
      throw ImageServiceException(
        'Failed to upload image',
        originalError: e,
      );
    }
  }
  
  /// Get image with caching support
  Future<Uint8List?> getImage({
    required String url,
    bool thumbnail = false,
    bool forceRefresh = false,
  }) async {
    try {
      await _initCacheDir();
      
      if (kDebugMode) print('ImageService: Getting image from: $url');
      
      // Extract path from URL
      final path = _extractPathFromUrl(url);
      if (path == null) {
        throw ImageServiceException('Invalid Firebase Storage URL');
      }
      
      // Check cache first (unless force refresh)
      if (!forceRefresh) {
        final cachedData = await _getCachedImage(path);
        if (cachedData != null) {
          // Validate cache with ETag
          final isValid = await _validateCache(path, url);
          if (isValid) {
            if (kDebugMode) print('ImageService: Using cached image');
            return cachedData;
          }
        }
      }
      
      // Download from Firebase Storage
      if (kDebugMode) print('ImageService: Downloading from Firebase Storage');
      
      _ensureInitialized();
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw ImageServiceException(
          'Failed to download image: ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }
      
      final imageData = response.bodyBytes;
      
      // Get metadata from Firebase Storage
      _ensureInitialized();
      final ref = _storage.refFromURL(url);
      final metadata = await ref.getMetadata();
      
      // Cache the downloaded image
      await _cacheImage(path, imageData, metadata);
      
      return imageData;
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error getting image: $e');
      
      if (e is SocketException) {
        // Network error - try to return cached version if available
        final path = _extractPathFromUrl(url);
        if (path != null) {
          final cachedData = await _getCachedImage(path);
          if (cachedData != null) {
            if (kDebugMode) print('ImageService: Network error, using cached image');
            return cachedData;
          }
        }
        
        throw ImageServiceException(
          'Network error - no cached image available',
          code: 'network_error',
          originalError: e,
        );
      }
      
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to get image');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
      
      if (e is ImageServiceException) rethrow;
      
      throw ImageServiceException(
        'Failed to get image',
        originalError: e,
      );
    }
  }
  
  /// Delete image from Firebase Storage and cache
  Future<void> deleteImage(String url) async {
    try {
      _ensureInitialized();
      if (kDebugMode) print('ImageService: Deleting image: $url');
      
      // Delete from Firebase Storage
      final ref = _storage.refFromURL(url);
      await ref.delete();
      
      // Delete from cache
      final path = _extractPathFromUrl(url);
      if (path != null) {
        await _deleteCachedImage(path);
      }
      
      if (kDebugMode) print('ImageService: Image deleted successfully');
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error deleting image: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to delete image');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
      
      throw ImageServiceException(
        'Failed to delete image',
        originalError: e,
      );
    }
  }
  
  /// Clear cache
  Future<void> clearCache({String? path}) async {
    try {
      await _initCacheDir();
      
      if (path != null) {
        // Clear specific path
        await _deleteCachedImage(path);
      } else {
        // Clear entire cache
        if (_cacheDir != null && await _cacheDir!.exists()) {
          await _cacheDir!.delete(recursive: true);
          await _cacheDir!.create(recursive: true);
        }
      }
      
      if (kDebugMode) print('ImageService: Cache cleared');
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error clearing cache: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to clear image cache');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
    }
  }
  
  /// Clear all user cache (called on signout)
  Future<void> clearAllUserCache() async {
    try {
      await _initCacheDir();
      
      // Clear entire cache directory
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        if (kDebugMode) print('ImageService: All user cache cleared');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('ImageService: Error clearing all user cache: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Failed to clear all user image cache');
      } catch (_) {
        // Firebase not initialized in tests - ignore
      }
    }
  }
  
  /// Get cached image file for UI display
  Future<File?> getCachedImageFile({
    required String url,
    bool forceRefresh = false,
  }) async {
    try {
      // First ensure we have the image cached
      final imageData = await getImage(url: url, forceRefresh: forceRefresh);
      if (imageData == null) return null;
      
      // Extract path from URL
      final path = _extractPathFromUrl(url);
      if (path == null) return null;
      
      // Return the cached file
      await _initCacheDir();
      final cacheFile = File(p.join(_cacheDir!.path, path));
      if (await cacheFile.exists()) {
        return cacheFile;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('ImageService: Error getting cached file: $e');
      return null;
    }
  }
  
  // Private helper methods
  
  /// Extract storage path from Firebase Storage URL
  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathMatch = RegExp(r'/o/(.+)\?').firstMatch(uri.path);
      if (pathMatch != null) {
        return Uri.decodeComponent(pathMatch.group(1)!);
      }
    } catch (e) {
      if (kDebugMode) print('ImageService: Error extracting path from URL: $e');
    }
    return null;
  }
  
  /// Cache image locally
  Future<void> _cacheImage(String path, Uint8List data, dynamic metadata) async {
    try {
      await _initCacheDir();
      
      final cacheFile = File(p.join(_cacheDir!.path, path));
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(data);
      
      // Save metadata
      final metadataFile = File('${cacheFile.path}.metadata');
      final metadataJson = {
        'etag': metadata is FullMetadata ? metadata.md5Hash : null,
        'lastModified': DateTime.now().toIso8601String(),
        'size': data.length,
      };
      await metadataFile.writeAsString(jsonEncode(metadataJson));
      
      if (kDebugMode) print('ImageService: Cached image at: ${cacheFile.path}');
    } catch (e) {
      if (kDebugMode) print('ImageService: Error caching image: $e');
      // Don't throw - caching is optional
    }
  }
  
  /// Get cached image
  Future<Uint8List?> _getCachedImage(String path) async {
    try {
      await _initCacheDir();
      
      final cacheFile = File(p.join(_cacheDir!.path, path));
      if (await cacheFile.exists()) {
        return await cacheFile.readAsBytes();
      }
    } catch (e) {
      if (kDebugMode) print('ImageService: Error reading cached image: $e');
    }
    return null;
  }
  
  /// Validate cache using ETag
  Future<bool> _validateCache(String path, String url) async {
    try {
      // Get cached metadata
      final metadataFile = File(p.join(_cacheDir!.path, '$path.metadata'));
      if (!await metadataFile.exists()) return false;
      
      final cachedMetadata = jsonDecode(await metadataFile.readAsString());
      final cachedEtag = cachedMetadata['etag'];
      
      if (cachedEtag == null) return false;
      
      // Get current metadata from Firebase
      _ensureInitialized();
      final ref = _storage.refFromURL(url);
      final currentMetadata = await ref.getMetadata();
      
      // Compare ETags
      return cachedEtag == currentMetadata.md5Hash;
    } catch (e) {
      if (kDebugMode) print('ImageService: Error validating cache: $e');
      return false;
    }
  }
  
  /// Delete cached image
  Future<void> _deleteCachedImage(String path) async {
    try {
      await _initCacheDir();
      
      final cacheFile = File(p.join(_cacheDir!.path, path));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      
      final metadataFile = File('${cacheFile.path}.metadata');
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
      
      if (kDebugMode) print('ImageService: Deleted cached image: $path');
    } catch (e) {
      if (kDebugMode) print('ImageService: Error deleting cached image: $e');
    }
  }
}