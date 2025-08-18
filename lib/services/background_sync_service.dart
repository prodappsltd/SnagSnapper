import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import 'sync_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      
      // Get database instance
      final db = await AppDatabase.getInstance();
      
      // Get sync service instance
      final syncService = SyncService.instance;
      
      // Check user preferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');
      
      if (userId == null) {
        if (kDebugMode) {
          print('Background sync: No user logged in');
        }
        return Future.value(true);
      }
      
      // Check sync preferences
      final autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
      final wifiOnly = prefs.getBool('wifi_only_sync') ?? true;
      
      if (!autoSyncEnabled) {
        if (kDebugMode) {
          print('Background sync: Auto-sync disabled by user');
        }
        return Future.value(true);
      }
      
      // Handle different task types
      switch (task) {
        case BackgroundSyncService.periodicTaskName:
          if (kDebugMode) {
            print('Background sync: Starting periodic sync');
          }
          
          // Check battery level
          if (!await _checkBatteryLevel()) {
            if (kDebugMode) {
              print('Background sync: Battery too low, skipping sync');
            }
            return Future.value(true);
          }
          
          // Check storage space
          if (!await _checkStorageSpace()) {
            if (kDebugMode) {
              print('Background sync: Storage too low, skipping sync');
            }
            return Future.value(true);
          }
          
          // Perform sync
          await syncService.performBackgroundSync(userId);
          
          // Update last sync time
          await prefs.setInt('last_background_sync', 
              DateTime.now().millisecondsSinceEpoch);
          
          if (kDebugMode) {
            print('Background sync: Completed successfully');
          }
          break;
          
        case BackgroundSyncService.oneOffTaskName:
          if (kDebugMode) {
            print('Background sync: Starting one-off sync');
          }
          
          // Perform sync without constraints check
          await syncService.syncNow();
          
          if (kDebugMode) {
            print('Background sync: One-off sync completed');
          }
          break;
          
        default:
          if (kDebugMode) {
            print('Background sync: Unknown task: $task');
          }
      }
      
      return Future.value(true);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Background sync failed: $e');
        print('Stack trace: $stackTrace');
      }
      
      // Log error for later analysis
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_background_sync_error', e.toString());
      await prefs.setInt('last_background_sync_error_time', 
          DateTime.now().millisecondsSinceEpoch);
      
      return Future.value(false);
    }
  });
}

/// Check if battery level is sufficient for sync
Future<bool> _checkBatteryLevel() async {
  // Note: Actual battery level check would require platform-specific code
  // For now, we'll use a mock implementation
  // In production, use battery_plus package or platform channels
  
  // Mock: always return true for now
  // TODO: Implement actual battery check
  return true;
}

/// Check if storage space is sufficient
Future<bool> _checkStorageSpace() async {
  // Note: Actual storage check would require platform-specific code
  // For now, we'll use a mock implementation
  // In production, use disk_space package or platform channels
  
  // Mock: always return true for now
  // TODO: Implement actual storage check
  return true;
}

/// Background sync service for handling periodic and one-off sync tasks
class BackgroundSyncService {
  static const String periodicTaskName = 'periodic-sync';
  static const String oneOffTaskName = 'one-off-sync';
  
  // Sync intervals
  static const Duration minimumInterval = Duration(minutes: 15); // iOS minimum
  static const Duration defaultInterval = Duration(minutes: 30);
  static const Duration extendedInterval = Duration(hours: 2);
  
  // Singleton instance
  static BackgroundSyncService? _instance;
  static BackgroundSyncService get instance {
    _instance ??= BackgroundSyncService._();
    return _instance!;
  }
  
  BackgroundSyncService._();
  
  /// Initialize background sync service
  static Future<void> initialize({
    bool isDebug = false,
  }) async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: isDebug,
    );
    
    if (kDebugMode) {
      print('BackgroundSyncService initialized');
    }
  }
  
  /// Register periodic sync task
  static Future<void> registerPeriodicSync({
    Duration frequency = defaultInterval,
    bool requiresCharging = false,
    bool requiresDeviceIdle = false,
    bool requiresWifi = true,
  }) async {
    // Cancel existing periodic task if any
    await cancelPeriodicSync();
    
    // Ensure frequency meets platform minimums
    final actualFrequency = frequency < minimumInterval ? minimumInterval : frequency;
    
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: actualFrequency,
      constraints: Constraints(
        networkType: requiresWifi ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: requiresCharging,
        requiresDeviceIdle: requiresDeviceIdle,
        requiresStorageNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: Duration(seconds: 10),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    // Save sync preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sync_frequency_minutes', actualFrequency.inMinutes);
    await prefs.setBool('sync_requires_wifi', requiresWifi);
    await prefs.setBool('sync_requires_charging', requiresCharging);
    
    if (kDebugMode) {
      print('Periodic sync registered: ${actualFrequency.inMinutes} minutes');
    }
  }
  
  /// Cancel periodic sync
  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(periodicTaskName);
    
    if (kDebugMode) {
      print('Periodic sync cancelled');
    }
  }
  
  /// Trigger one-off sync
  static Future<void> triggerOneOffSync({
    bool requiresWifi = false,
    Duration? delay,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await Workmanager().registerOneOffTask(
      taskId,
      oneOffTaskName,
      initialDelay: delay ?? Duration.zero,
      constraints: Constraints(
        networkType: requiresWifi ? NetworkType.unmetered : NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: Duration(seconds: 10),
    );
    
    if (kDebugMode) {
      print('One-off sync triggered: $taskId');
    }
  }
  
  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    
    if (kDebugMode) {
      print('All background tasks cancelled');
    }
  }
  
  /// Get sync statistics
  static Future<Map<String, dynamic>> getSyncStatistics() async {
    final prefs = await SharedPreferences.getInstance();
    
    final lastSync = prefs.getInt('last_background_sync');
    final lastError = prefs.getString('last_background_sync_error');
    final lastErrorTime = prefs.getInt('last_background_sync_error_time');
    final frequency = prefs.getInt('sync_frequency_minutes') ?? 30;
    final wifiOnly = prefs.getBool('sync_requires_wifi') ?? true;
    final requiresCharging = prefs.getBool('sync_requires_charging') ?? false;
    
    return {
      'lastSyncTime': lastSync != null 
          ? DateTime.fromMillisecondsSinceEpoch(lastSync).toIso8601String()
          : null,
      'lastError': lastError,
      'lastErrorTime': lastErrorTime != null
          ? DateTime.fromMillisecondsSinceEpoch(lastErrorTime).toIso8601String()
          : null,
      'syncFrequencyMinutes': frequency,
      'requiresWifi': wifiOnly,
      'requiresCharging': requiresCharging,
      'nextSyncTime': lastSync != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSync)
              .add(Duration(minutes: frequency))
              .toIso8601String()
          : null,
    };
  }
  
  /// Update sync preferences
  static Future<void> updateSyncPreferences({
    bool? autoSyncEnabled,
    bool? wifiOnly,
    Duration? frequency,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (autoSyncEnabled != null) {
      await prefs.setBool('auto_sync_enabled', autoSyncEnabled);
      
      if (autoSyncEnabled) {
        // Re-register periodic sync if enabled
        await registerPeriodicSync(
          frequency: frequency ?? defaultInterval,
          requiresWifi: wifiOnly ?? true,
        );
      } else {
        // Cancel periodic sync if disabled
        await cancelPeriodicSync();
      }
    }
    
    if (wifiOnly != null) {
      await prefs.setBool('wifi_only_sync', wifiOnly);
    }
    
    if (frequency != null) {
      await prefs.setInt('sync_frequency_minutes', frequency.inMinutes);
    }
    
    if (kDebugMode) {
      print('Sync preferences updated');
    }
  }
  
  /// Check if background sync is available on this platform
  static bool isBackgroundSyncAvailable() {
    // Background sync is available on both iOS and Android
    // but with different constraints
    return true;
  }
  
  /// Get platform-specific sync constraints
  static Map<String, dynamic> getPlatformConstraints() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return {
        'minimumInterval': minimumInterval.inMinutes,
        'backgroundRefreshAvailable': true,
        'requiresMainPowerSource': false,
        'note': 'iOS may delay or skip tasks based on system conditions',
      };
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        'minimumInterval': 15, // Android's minimum is 15 minutes
        'backgroundRefreshAvailable': true,
        'requiresMainPowerSource': false,
        'note': 'Android respects Doze mode and App Standby',
      };
    } else {
      return {
        'minimumInterval': 0,
        'backgroundRefreshAvailable': false,
        'requiresMainPowerSource': false,
        'note': 'Background sync not available on this platform',
      };
    }
  }
  
  /// Estimate battery impact
  static Future<String> estimateBatteryImpact() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getInt('sync_frequency_minutes') ?? 30;
    
    // Rough estimates based on sync frequency
    if (frequency <= 15) {
      return 'High (3-5% per day)';
    } else if (frequency <= 30) {
      return 'Medium (1-2% per day)';
    } else if (frequency <= 60) {
      return 'Low (< 1% per day)';
    } else {
      return 'Minimal (< 0.5% per day)';
    }
  }
  
  /// Estimate data usage
  static Future<String> estimateDataUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getInt('sync_frequency_minutes') ?? 30;
    
    // Calculate syncs per day
    final syncsPerDay = (24 * 60) / frequency;
    
    // Assume average 500KB per sync (profile + images)
    final dataPerDay = syncsPerDay * 0.5; // MB
    
    if (dataPerDay < 5) {
      return 'Low (< 5MB per day)';
    } else if (dataPerDay < 10) {
      return 'Medium (5-10MB per day)';
    } else if (dataPerDay < 20) {
      return 'High (10-20MB per day)';
    } else {
      return 'Very High (> 20MB per day)';
    }
  }
}































