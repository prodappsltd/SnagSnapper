import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/sync_event_bus.dart';

/// Global sync manager that handles background synchronization
/// independently of UI navigation.
/// 
/// This service runs at the app level and ensures that:
/// - Profile changes sync within 2 seconds when online
/// - Sync resumes automatically when connectivity is restored
/// - Periodic sync checks occur every 5 minutes
/// - All sync operations are non-blocking (fire-and-forget)
class GlobalSyncManager {
  // Singleton instance
  static GlobalSyncManager? _instance;
  static GlobalSyncManager get instance {
    _instance ??= GlobalSyncManager._();
    return _instance!;
  }
  
  GlobalSyncManager._();
  
  // Dependencies
  SyncService? _syncService;
  AppDatabase? _database;
  
  // Subscriptions and timers
  StreamSubscription? _profileWatchSubscription;
  StreamSubscription? _connectivitySubscription;
  Timer? _periodicSyncTimer;
  Timer? _debounceTimer;
  
  // State
  bool _isInitialized = false;
  String? _currentUserId;
  DateTime? _lastSyncAttempt;
  
  // Configuration
  static const Duration _debounceDuration = Duration(seconds: 2);
  static const Duration _periodicSyncInterval = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;
  
  /// Check if the manager is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get current user ID
  String? get currentUserId => _currentUserId;
  
  /// Initialize the global sync manager
  /// Should be called after Firebase initialization and user login
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('GlobalSyncManager: Already initialized');
      }
      return;
    }
    
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('GlobalSyncManager: No user logged in, skipping initialization');
        }
        return;
      }
      
      _currentUserId = user.uid;
      
      if (kDebugMode) {
        print('GlobalSyncManager: Initializing for user $_currentUserId');
      }
      
      // Get database instance
      _database = await AppDatabase.getInstance();
      
      // Initialize sync service
      _syncService = SyncService.instance;
      if (!_syncService!.isInitialized) {
        await _syncService!.initialize(_currentUserId!);
        if (kDebugMode) {
          print('GlobalSyncManager: SyncService initialized');
        }
      }
      
      // Setup watchers and listeners
      await _setupDatabaseWatcher();
      _setupConnectivityListener();
      _setupPeriodicSync();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('GlobalSyncManager: Initialization complete');
      }
      
      // Initial sync check after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _checkAndSync(reason: 'Initial check after initialization');
      });
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('GlobalSyncManager: Initialization error: $e');
        print('Stack trace: $stackTrace');
      }
      // Notify UI of initialization failure
      SyncEventBus.notifyError('Sync initialization failed: ${e.toString()}');
    }
  }
  
  /// Setup database watcher for profile changes
  Future<void> _setupDatabaseWatcher() async {
    if (_database == null || _currentUserId == null) return;
    
    try {
      // Cancel existing subscription if any
      await _profileWatchSubscription?.cancel();
      
      // Watch for profile changes that need syncing
      _profileWatchSubscription = _database!.profileDao
          .watchProfile(_currentUserId!)
          .listen((profile) {
        if (profile != null) {
          final needsSync = profile.needsProfileSync || 
                           profile.needsImageSync || 
                           profile.needsSignatureSync;
          
          if (needsSync) {
            if (kDebugMode) {
              print('GlobalSyncManager: Profile needs sync detected');
              print('  - needsProfileSync: ${profile.needsProfileSync}');
              print('  - needsImageSync: ${profile.needsImageSync}');
              print('  - needsSignatureSync: ${profile.needsSignatureSync}');
            }
            
            // Debounce sync calls to batch multiple changes
            _debouncedSync(reason: 'Profile change detected');
          }
        }
      });
      
      if (kDebugMode) {
        print('GlobalSyncManager: Database watcher setup complete');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('GlobalSyncManager: Error setting up database watcher: $e');
      }
    }
  }
  
  /// Setup connectivity listener to sync when connection is restored
  void _setupConnectivityListener() {
    try {
      // Cancel existing subscription if any
      _connectivitySubscription?.cancel();
      
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> results) async {
        
        // Check if we have a real connection (not just bluetooth)
        final hasConnection = results.any((result) => 
          result != ConnectivityResult.none && 
          result != ConnectivityResult.bluetooth);
        
        if (hasConnection) {
          if (kDebugMode) {
            print('GlobalSyncManager: Connection restored - ${results.join(", ")}');
          }
          
          // Check for pending sync after connection is restored
          // Add a small delay to ensure connection is stable
          Future.delayed(const Duration(seconds: 3), () {
            _checkAndSync(reason: 'Connection restored');
          });
        } else {
          if (kDebugMode) {
            print('GlobalSyncManager: No connection - ${results.join(", ")}');
          }
        }
      });
      
      if (kDebugMode) {
        print('GlobalSyncManager: Connectivity listener setup complete');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('GlobalSyncManager: Error setting up connectivity listener: $e');
      }
    }
  }
  
  /// Setup periodic sync timer as a fallback mechanism
  void _setupPeriodicSync() {
    // Cancel existing timer if any
    _periodicSyncTimer?.cancel();
    
    _periodicSyncTimer = Timer.periodic(
      _periodicSyncInterval,
      (_) {
        if (kDebugMode) {
          print('GlobalSyncManager: Periodic sync check triggered');
        }
        _checkAndSync(reason: 'Periodic sync');
      },
    );
    
    if (kDebugMode) {
      print('GlobalSyncManager: Periodic sync timer setup (every ${_periodicSyncInterval.inMinutes} minutes)');
    }
  }
  
  /// Debounced sync to prevent rapid successive sync attempts
  void _debouncedSync({required String reason}) {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();
    
    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      _checkAndSync(reason: reason);
    });
    
    if (kDebugMode) {
      print('GlobalSyncManager: Sync debounced for ${_debounceDuration.inSeconds} seconds - $reason');
    }
  }
  
  /// Check conditions and perform sync if needed
  Future<void> _checkAndSync({required String reason}) async {
    if (!_isInitialized || _syncService == null || _database == null || _currentUserId == null) {
      if (kDebugMode) {
        print('GlobalSyncManager: Cannot sync - not initialized');
      }
      return;
    }
    
    try {
      // Check if we're already syncing
      if (_syncService!.isSyncing) {
        if (kDebugMode) {
          print('GlobalSyncManager: Sync already in progress, skipping - $reason');
        }
        return;
      }
      
      // Rate limiting - don't sync more than once per second
      if (_lastSyncAttempt != null) {
        final timeSinceLastSync = DateTime.now().difference(_lastSyncAttempt!);
        if (timeSinceLastSync.inSeconds < 1) {
          if (kDebugMode) {
            print('GlobalSyncManager: Sync rate limited, skipping - $reason');
          }
          return;
        }
      }
      
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.any((result) => 
        result != ConnectivityResult.none && 
        result != ConnectivityResult.bluetooth);
      
      if (!hasConnection) {
        if (kDebugMode) {
          print('GlobalSyncManager: No connection available, skipping sync - $reason');
        }
        // Notify UI that sync is waiting for connection
        SyncEventBus.notifyStatus(SyncStatus.waitingForNetwork);
        return;
      }
      
      // Check if sync is actually needed
      final profile = await _database!.profileDao.getProfile(_currentUserId!);
      if (profile == null) {
        if (kDebugMode) {
          print('GlobalSyncManager: No profile found for user $_currentUserId');
        }
        return;
      }
      
      final needsSync = profile.needsProfileSync || 
                       profile.needsImageSync || 
                       profile.needsSignatureSync;
      
      if (!needsSync) {
        if (kDebugMode) {
          print('GlobalSyncManager: No sync needed - $reason');
        }
        // Notify UI that everything is up to date
        SyncEventBus.notifyStatus(SyncStatus.success);
        return;
      }
      
      // Perform sync
      if (kDebugMode) {
        print('GlobalSyncManager: Starting sync - $reason');
        print('  - Profile needs sync: ${profile.needsProfileSync}');
        print('  - Image needs sync: ${profile.needsImageSync}');
        print('  - Signature needs sync: ${profile.needsSignatureSync}');
      }
      
      _lastSyncAttempt = DateTime.now();
      
      // Notify UI that sync is starting
      SyncEventBus.notifyStatus(SyncStatus.syncing);
      
      // Perform the actual sync (fire-and-forget)
      final result = await _syncService!.syncNow();
      
      // Handle sync result
      if (result.success) {
        if (kDebugMode) {
          print('GlobalSyncManager: Sync completed successfully');
          print('  - Items synced: ${result.itemsSynced}');
          print('  - Duration: ${result.duration?.inMilliseconds}ms');
        }
        
        // Notify UI of success
        SyncEventBus.notifyStatus(SyncStatus.success);
        
        // Clear last sync attempt on success
        _lastSyncAttempt = null;
        
      } else {
        if (kDebugMode) {
          print('GlobalSyncManager: Sync failed');
          print('  - Error: ${result.error?.message}');
          print('  - Code: ${result.error?.code}');
        }
        
        // Notify UI of error
        final errorMessage = result.error?.message ?? 'Sync failed';
        SyncEventBus.notifyError(errorMessage);
        SyncEventBus.notifyStatus(SyncStatus.error);
        
        // Retry logic for certain error codes
        if (result.error?.code == 'network_error' || 
            result.error?.code == 'timeout') {
          // Schedule retry with exponential backoff
          final retryDelay = Duration(seconds: 10);
          if (kDebugMode) {
            print('GlobalSyncManager: Scheduling retry in ${retryDelay.inSeconds} seconds');
          }
          Future.delayed(retryDelay, () {
            _checkAndSync(reason: 'Retry after error');
          });
        }
      }
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('GlobalSyncManager: Error during sync check: $e');
        print('Stack trace: $stackTrace');
      }
      
      // Notify UI of unexpected error
      SyncEventBus.notifyError('Unexpected sync error: ${e.toString()}');
      SyncEventBus.notifyStatus(SyncStatus.error);
    }
  }
  
  /// Force an immediate sync check
  /// Used for manual sync triggers from UI
  Future<void> triggerSync() async {
    if (kDebugMode) {
      print('GlobalSyncManager: Manual sync triggered');
    }
    
    // Cancel any pending debounce
    _debounceTimer?.cancel();
    
    // Trigger immediate sync
    await _checkAndSync(reason: 'Manual trigger');
  }
  
  /// Reinitialize after user login
  /// Disposes existing resources and starts fresh
  Future<void> reinitialize() async {
    if (kDebugMode) {
      print('GlobalSyncManager: Reinitializing');
    }
    
    // Dispose existing resources
    dispose();
    
    // Wait a moment for cleanup
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Initialize fresh
    await initialize();
  }
  
  /// Clean up all resources
  /// Should be called on user logout
  void dispose() {
    if (kDebugMode) {
      print('GlobalSyncManager: Disposing resources');
    }
    
    // Cancel all subscriptions and timers
    _profileWatchSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _debounceTimer?.cancel();
    
    // Clear state
    _isInitialized = false;
    _currentUserId = null;
    _lastSyncAttempt = null;
    _syncService = null;
    _database = null;
    
    if (kDebugMode) {
      print('GlobalSyncManager: Disposal complete');
    }
  }
}