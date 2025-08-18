import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';
import 'package:snagsnapper/services/sync/network_monitor.dart';
import 'package:snagsnapper/services/sync/queue_manager.dart';
import 'package:snagsnapper/services/sync/device_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:snagsnapper/services/image_storage_service.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  SyncService._();

  late AppDatabase _database;
  late ProfileSyncHandler _profileHandler;
  late NetworkMonitor _networkMonitor;
  late SyncQueueManager _queueManager;
  late DeviceManager _deviceManager;
  late SharedPreferences _prefs;
  
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _errorController = StreamController<SyncError>.broadcast();
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  bool _isPaused = false;
  bool _isCancelled = false;
  String? _userId;
  Timer? _debounceTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Function? _forceLogoutCallback;
  Function? _syncCompleteCallback;
  
  // Test helpers
  bool _simulateOffline = false;
  bool _simulateFirebaseOutage = false;

  bool get isInitialized => _isInitialized;
  bool get isPaused => _isPaused;
  String? get userId => _userId;
  bool get isSyncing => _isSyncing;
  
  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<SyncError> get errorStream => _errorController.stream;

  Future<void> initialize(String userId) async {
    if (_isInitialized) {
      return;
    }

    _userId = userId;
    _prefs = await SharedPreferences.getInstance();
    _database = await AppDatabase.getInstance();
    
    // Initialize components
    _networkMonitor = NetworkMonitor(prefs: _prefs);
    _deviceManager = DeviceManager(prefs: _prefs);
    
    _profileHandler = ProfileSyncHandler(
      database: _database,
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
      imageStorage: ImageStorageService.instance,
    );
    
    _queueManager = SyncQueueManager(
      database: _database,
      profileHandler: _profileHandler,
      networkMonitor: _networkMonitor,
      prefs: _prefs,
    );
    
    _isInitialized = true;
    
    // Broadcast initial status
    updateStatus(SyncStatus.idle);
  }

  void setupAutoSync() {
    _networkMonitor.setupAutoSync(() async {
      if (!_isPaused && !_isSyncing) {
        await syncNow();
      }
    });

    _networkMonitor.onQueueProcess(() async {
      if (!_isPaused && !_isSyncing) {
        await _queueManager.processQueue();
      }
    });

    // Listen for connectivity changes
    _connectivitySubscription = _networkMonitor.connectivityStream.listen((result) async {
      if (result != ConnectivityResult.none) {
        // Check if there are items to sync
        if (await _queueManager.hasItemsToSync()) {
          await _queueManager.processQueue();
        }
      }
    });
  }

  Future<SyncResult> syncNow() async {
    if (kDebugMode) {
      print('SyncService.syncNow: Starting sync attempt');
    }
    
    // Debounce rapid sync requests
    if (_debounceTimer?.isActive ?? false) {
      if (kDebugMode) {
        print('SyncService.syncNow: Sync debounced - already in progress');
      }
      return SyncResult.failure(
        message: 'Sync already in progress',
      );
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {});

    // Check if paused
    if (_isPaused) {
      if (kDebugMode) {
        print('SyncService.syncNow: Sync is paused');
      }
      return SyncResult.failure(
        message: 'Sync is paused',
      );
    }

    // Check if already syncing
    if (_isSyncing) {
      if (kDebugMode) {
        print('SyncService.syncNow: Already syncing');
      }
      return SyncResult.failure(
        message: 'Sync already in progress',
      );
    }

    // Check if offline (or simulating offline)
    final isOnline = await _networkMonitor.isOnline();
    if (kDebugMode) {
      print('SyncService.syncNow: Network status - online: $isOnline, simulating offline: $_simulateOffline');
    }
    
    if (_simulateOffline || !isOnline) {
      // Queue the sync
      final item = SyncQueueItem(
        id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
        userId: _userId!,
        type: SyncType.profile,
        action: SyncAction.upload,
        createdAt: DateTime.now(),
      );
      
      await _queueManager.addToQueue(item);
      
      if (kDebugMode) {
        print('SyncService.syncNow: Device is offline, sync queued');
      }
      
      return SyncResult.failure(
        message: 'Device is offline, sync queued',
        wasQueued: true,
      );
    }

    // Check Firebase outage
    if (_simulateFirebaseOutage) {
      final item = SyncQueueItem(
        id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
        userId: _userId!,
        type: SyncType.profile,
        action: SyncAction.upload,
        createdAt: DateTime.now(),
      );
      
      await _queueManager.addToQueue(item);
      
      if (kDebugMode) {
        print('SyncService.syncNow: Firebase simulated outage, sync queued');
      }
      
      return SyncResult.failure(
        message: 'Firebase service unavailable',
        wasQueued: true,
      );
    }

    // Validate device
    final deviceValid = await _deviceManager.validateDevice(_userId!);
    if (kDebugMode) {
      print('SyncService.syncNow: Device validation result: $deviceValid');
    }
    
    if (!deviceValid) {
      return SyncResult.failure(
        message: 'Different device is logged in',
        requiresDeviceSwitch: true,
      );
    }

    try {
      _isSyncing = true;
      _isCancelled = false;
      updateStatus(SyncStatus.syncing);
      updateProgress(0.0);
      
      if (kDebugMode) {
        print('SyncService.syncNow: Starting sync operations');
      }

      final syncedItems = <String>[];

      // Check cancellation
      if (_isCancelled) {
        if (kDebugMode) {
          print('SyncService.syncNow: Sync cancelled');
        }
        return SyncResult.cancelled();
      }

      // Sync profile data
      updateProgress(0.25);
      if (kDebugMode) {
        print('SyncService.syncNow: Syncing profile data...');
      }
      final profileSuccess = await _profileHandler.syncProfileData(_userId!);
      if (kDebugMode) {
        print('SyncService.syncNow: Profile sync result: $profileSuccess');
      }
      if (profileSuccess) {
        syncedItems.add('profile');
      }

      // Check cancellation
      if (_isCancelled) {
        if (kDebugMode) {
          print('SyncService.syncNow: Sync cancelled');
        }
        return SyncResult.cancelled();
      }

      // Sync profile image if needed (including deletions)
      updateProgress(0.5);
      final localUser = await _database.profileDao.getProfile(_userId!);
      if (localUser != null) {
        if (localUser.needsImageSync) {
          if (kDebugMode) {
            print('SyncService.syncNow: Syncing profile image...');
          }
          // Pass empty string if path is null (indicates deletion)
          final imageSuccess = await _profileHandler.syncProfileImage(
            _userId!,
            localUser.imageLocalPath ?? '',
          );
          if (kDebugMode) {
            print('SyncService.syncNow: Image sync result: $imageSuccess');
          }
          if (imageSuccess) {
            syncedItems.add('profile_image');
          }
        }

        // Sync signature if needed (including deletions)
        updateProgress(0.75);
        if (localUser.needsSignatureSync) {
          if (kDebugMode) {
            print('SyncService.syncNow: Syncing signature...');
          }
          // Pass empty string if path is null (indicates deletion)
          final signatureSuccess = await _profileHandler.syncSignatureImage(
            _userId!,
            localUser.signatureLocalPath ?? '',
          );
          if (kDebugMode) {
            print('SyncService.syncNow: Signature sync result: $signatureSuccess');
          }
          if (signatureSuccess) {
            syncedItems.add('profile_signature');
          }
        }
      }

      updateProgress(1.0);
      updateStatus(SyncStatus.synced);
      
      _syncCompleteCallback?.call();
      
      if (kDebugMode) {
        print('SyncService.syncNow: Sync completed successfully. Synced items: $syncedItems');
      }
      
      return SyncResult.success(
        syncedItems: syncedItems,
      );
    } catch (e) {
      if (kDebugMode) {
        print('SyncService.syncNow: Sync failed with error: $e');
      }
      
      updateStatus(SyncStatus.error);
      handleError(SyncError(
        type: SyncErrorType.unknown,
        message: e.toString(),
      ));
      
      return SyncResult.failure(
        message: 'Sync failed: ${e.toString()}',
      );
    } finally {
      _isSyncing = false;
      if (kDebugMode) {
        print('SyncService.syncNow: Sync process ended');
      }
    }
  }

  void cancelSync() {
    _isCancelled = true;
  }

  void pauseSync() {
    _isPaused = true;
    _networkMonitor.pauseAutoSync();
  }

  void resumeSync() {
    _isPaused = false;
    _networkMonitor.resumeAutoSync();
  }

  void updateStatus(SyncStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void updateProgress(double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  void handleError(SyncError error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  Future<void> onAppForeground() async {
    if (await _networkMonitor.isOnline() && await _queueManager.hasItemsToSync()) {
      await _queueManager.processQueue();
    }
  }

  void onForceLogout(Function callback) {
    _forceLogoutCallback = callback;
    _deviceManager.onForceLogout(() {
      _forceLogoutCallback?.call();
    });
  }

  void onSyncComplete(Function callback) {
    _syncCompleteCallback = callback;
  }

  Future<QueueStatus> getQueueStatus() async {
    return await _queueManager.getQueueStatus();
  }

  Future<SyncResult> syncBatch(List<String> userIds) async {
    // For testing - batch sync multiple profiles
    int processed = 0;
    int succeeded = 0;
    
    for (final id in userIds) {
      processed++;
      final result = await syncNow();
      if (result.success) {
        succeeded++;
      }
    }
    
    return SyncResult(
      success: succeeded == processed,
      message: 'Batch sync completed',
      batchedOperations: true,
      processed: processed,
      succeeded: succeeded,
    );
  }

  Future<void> performBackgroundSync(String userId) async {
    // Background sync implementation for use with workmanager
    try {
      // Initialize if needed
      if (!_isInitialized || _userId != userId) {
        await initialize(userId);
      }
      
      // Check if sync is needed
      final status = await checkSyncStatus(userId);
      if (status == SyncStatus.synced) {
        return; // Nothing to sync
      }
      
      // Perform sync with timeout
      final result = await syncNow().timeout(
        Duration(seconds: 30),
        onTimeout: () => SyncResult(
          success: false,
          message: 'Background sync timed out',
        ),
      );
      
      if (!result.success) {
        throw Exception('Background sync failed: ${result.message}');
      }
    } catch (e) {
      // Log error but don't throw - background tasks should handle errors gracefully
      print('Background sync error: $e');
    }
  }

  // Legacy methods for backward compatibility
  Future<bool> syncProfile(String userId) async {
    if (_userId != userId) {
      await initialize(userId);
    }
    final result = await syncNow();
    return result.success;
  }

  Future<bool> syncProfileImage(String userId, String localPath) async {
    return await _profileHandler.syncProfileImage(userId, localPath);
  }

  Future<bool> syncSignatureImage(String userId, String localPath) async {
    return await _profileHandler.syncSignatureImage(userId, localPath);
  }

  Future<SyncStatus> checkSyncStatus(String userId) async {
    final user = await _database.profileDao.getProfile(userId);
    if (user == null) return SyncStatus.error;
    
    if (user.needsProfileSync || user.needsImageSync || user.needsSignatureSync) {
      return SyncStatus.pending;
    }
    
    return SyncStatus.synced;
  }

  // Test helper methods
  Future<void> simulateOffline() async {
    _simulateOffline = true;
  }

  Future<void> simulateOnline() async {
    _simulateOffline = false;
  }

  Future<void> simulateReconnect() async {
    _simulateOffline = false;
    await _networkMonitor.simulateConnectivityChange(ConnectivityResult.wifi);
  }

  Future<void> simulateFirebaseOutage() async {
    _simulateFirebaseOutage = true;
  }

  Future<void> restoreFirebaseService() async {
    _simulateFirebaseOutage = false;
    await _queueManager.processQueue();
  }

  void dispose() {
    // Check if initialized before clearing the flag
    final wasInitialized = _isInitialized;
    
    _isInitialized = false;
    _userId = null;
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    
    if (!_statusController.isClosed) {
      _statusController.close();
    }
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    if (!_errorController.isClosed) {
      _errorController.close();
    }
    
    // Only dispose if they were initialized
    if (wasInitialized) {
      _networkMonitor.dispose();
      _deviceManager.dispose();
      _queueManager.dispose();
    }
  }
}