import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceConflictResult {
  final bool hasConflict;
  final String? otherDeviceName;
  final DateTime? lastActiveTime;
  final bool canForceLogout;

  DeviceConflictResult({
    required this.hasConflict,
    this.otherDeviceName,
    this.lastActiveTime,
    this.canForceLogout = false,
  });
}

class DeviceManager {
  final FirebaseDatabase database;
  final FirebaseAuth auth;
  final DeviceInfoPlugin deviceInfo;
  late final SharedPreferences prefs;
  
  final _forceLogoutController = StreamController<bool>.broadcast();
  Function? _forceLogoutCallback;
  StreamSubscription<DatabaseEvent>? _forceLogoutSubscription;
  bool _initialized = false;

  DeviceManager({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfo,
  })  : database = database ?? FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://snagsnapperpro-default-rtdb.europe-west1.firebasedatabase.app',
        ),
        auth = auth ?? FirebaseAuth.instance,
        deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      prefs = await SharedPreferences.getInstance();
      _initialized = true;
      if (kDebugMode) {
        print('🔍 DeviceManager: SharedPreferences initialized');
      }
    }
  }

  Stream<bool> get forceLogoutStream => _forceLogoutController.stream;

  Future<bool> validateDevice(String userId) async {
    try {
      // No need to call _ensureInitialized() here since getDeviceId() will do it
      final deviceId = await getDeviceId();
      
      if (kDebugMode) {
        print('DeviceManager.validateDevice: Checking device for user $userId');
        print('DeviceManager.validateDevice: Current device ID: $deviceId');
      }
      
      final snapshot = await database
          .ref('device_sessions/$userId/current_device')
          .get();

      if (!snapshot.exists) {
        if (kDebugMode) {
          print('DeviceManager.validateDevice: No device session found in Realtime DB - allowing');
        }
        // No device registered yet
        return true;
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        if (kDebugMode) {
          print('DeviceManager.validateDevice: Device session data is null - allowing');
        }
        return true;
      }

      if (kDebugMode) {
        print('DeviceManager.validateDevice: Found device session data: $data');
        print('DeviceManager.validateDevice: Registered device ID: ${data['device_id']}');
        print('DeviceManager.validateDevice: Device match: ${data['device_id'] == deviceId}');
      }

      // Check if it's the same device
      if (data['device_id'] == deviceId) {
        // Check if session is not expired (30 days)
        final lastActive = data['last_active'] as int?;
        if (lastActive != null) {
          final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
          final daysDiff = DateTime.now().difference(lastActiveTime).inDays;
          if (kDebugMode) {
            print('DeviceManager.validateDevice: Session age: $daysDiff days');
          }
          if (daysDiff > 30) {
            if (kDebugMode) {
              print('DeviceManager.validateDevice: Session expired (${daysDiff} days) - rejecting');
            }
            return false; // Session expired
          }
        }
        if (kDebugMode) {
          print('DeviceManager.validateDevice: Device validation successful');
        }
        return true;
      }

      if (kDebugMode) {
        print('DeviceManager.validateDevice: Different device detected - rejecting');
      }
      return false; // Different device
    } catch (e) {
      if (kDebugMode) {
        print('DeviceManager.validateDevice: Error during validation: $e - allowing offline operation');
      }
      // Allow local operation when offline
      return true;
    }
  }

  Future<String> getDeviceId() async {
    try {
      if (kDebugMode) {
        print('🔍 DeviceManager: Starting getDeviceId()');
      }
      
      await _ensureInitialized();
      
      String? deviceId = prefs.getString('device_id');
      
      if (kDebugMode) {
        print('🔍 DeviceManager: Retrieved from prefs: $deviceId');
      }
      
      if (deviceId == null) {
        if (kDebugMode) {
          print('🔍 DeviceManager: No device ID found, generating new one');
        }
        
        // Generate new device ID
        deviceId = await _generateDeviceId();
        
        if (kDebugMode) {
          print('🔍 DeviceManager: Generated device ID: $deviceId');
        }
        
        await prefs.setString('device_id', deviceId);
        
        if (kDebugMode) {
          print('🔍 DeviceManager: Stored device ID in prefs');
        }
        
        await storeDeviceInfo();
        
        if (kDebugMode) {
          print('🔍 DeviceManager: Stored device info');
        }
      }
      
      if (kDebugMode) {
        print('🔍 DeviceManager: Returning device ID: $deviceId');
      }
      
      return deviceId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔍 DeviceManager: ERROR in getDeviceId():');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');
        print('  Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  Future<String> _generateDeviceId() async {
    try {
      if (kDebugMode) {
        print('🔍 DeviceManager: Starting _generateDeviceId()');
      }
      
      String baseId;
      
      if (Platform.isAndroid) {
        if (kDebugMode) {
          print('🔍 DeviceManager: Getting Android device info');
        }
        final androidInfo = await deviceInfo.androidInfo;
        baseId = androidInfo.id ?? '';
        if (kDebugMode) {
          print('🔍 DeviceManager: Android base ID: $baseId');
        }
      } else if (Platform.isIOS) {
        if (kDebugMode) {
          print('🔍 DeviceManager: Getting iOS device info');
        }
        final iosInfo = await deviceInfo.iosInfo;
        baseId = iosInfo.identifierForVendor ?? '';
        if (kDebugMode) {
          print('🔍 DeviceManager: iOS base ID: $baseId');
        }
      } else {
        baseId = '';
        if (kDebugMode) {
          print('🔍 DeviceManager: Unknown platform, using empty base ID');
        }
      }
      
      // Use just the base device ID without UUID
      // This ensures consistency across app reinstalls on the same device
      // The base ID (like BP2A.250705.008 on Android) remains constant for the device
      final deviceId = baseId;
      
      if (kDebugMode) {
        print('🔍 DeviceManager: Using base device ID (no UUID): $deviceId');
      }
      
      return deviceId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔍 DeviceManager: ERROR in _generateDeviceId():');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');
        print('  Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  Future<void> storeDeviceInfo() async {
    String model = 'Unknown Device';
    String os = Platform.operatingSystem;
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      model = '${androidInfo.brand} ${androidInfo.model}';
      os = 'Android ${androidInfo.version.release}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      model = iosInfo.model ?? 'iPhone';
      os = 'iOS ${iosInfo.systemVersion}';
    }
    
    await prefs.setString('device_model', model);
    await prefs.setString('device_os', os);
  }

  Future<DeviceConflictResult> checkForDeviceConflict(String userId) async {
    try {
      final deviceId = await getDeviceId();
      
      final snapshot = await database
          .ref('device_sessions/$userId/current_device')
          .get();

      if (!snapshot.exists) {
        return DeviceConflictResult(hasConflict: false);
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return DeviceConflictResult(hasConflict: false);
      }

      if (data['device_id'] != deviceId) {
        final lastActive = data['last_active'] as int?;
        DateTime? lastActiveTime;
        if (lastActive != null) {
          lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
        }

        return DeviceConflictResult(
          hasConflict: true,
          otherDeviceName: data['device_name']?.toString(),
          lastActiveTime: lastActiveTime,
          canForceLogout: true,
        );
      }

      return DeviceConflictResult(hasConflict: false);
    } catch (e) {
      return DeviceConflictResult(hasConflict: false);
    }
  }

  Future<bool> forceLogoutOtherDevice(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final deviceModel = prefs.getString('device_model') ?? 'Unknown Device';
      
      // Set force logout flag
      await database
          .ref('device_sessions/$userId/force_logout')
          .set(true);

      // Register this device as current
      await database
          .ref('device_sessions/$userId/current_device')
          .set({
        'device_id': deviceId,
        'device_name': deviceModel,
        'last_active': ServerValue.timestamp,
        'force_logout': false,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> registerDevice(String userId) async {
    try {
      final deviceId = await getDeviceId();
      final deviceModel = prefs.getString('device_model') ?? 'Unknown Device';
      
      await database
          .ref('device_sessions/$userId/current_device')
          .set({
        'device_id': deviceId,
        'device_name': deviceModel,
        'last_active': ServerValue.timestamp,
        'session_start': ServerValue.timestamp,
        'force_logout': false,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Stream<bool> setupForceLogoutListener(String userId) {
    final controller = StreamController<bool>.broadcast();
    
    _forceLogoutSubscription?.cancel();
    _forceLogoutSubscription = database
        .ref('device_sessions/$userId/force_logout')
        .onValue
        .listen((event) {
      final forceLogout = event.snapshot.value as bool? ?? false;
      if (forceLogout) {
        controller.add(true);
        _forceLogoutController.add(true);
        _forceLogoutCallback?.call();
      }
    });

    return controller.stream;
  }

  void onForceLogout(Function callback) {
    _forceLogoutCallback = callback;
  }

  Future<void> updateDeviceActivity(String userId) async {
    try {
      await database
          .ref('device_sessions/$userId/current_device/last_active')
          .set(ServerValue.timestamp);
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> cleanupDeviceSession(String userId) async {
    try {
      await database
          .ref('device_sessions/$userId/current_device')
          .remove();
      await database
          .ref('device_sessions/$userId/force_logout')
          .remove();
      await prefs.remove('device_id');
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> createSession(String userId) async {
    final deviceId = await getDeviceId();
    final deviceModel = prefs.getString('device_model') ?? 'Unknown Device';
    
    // Register current session
    await database
        .ref('device_sessions/$userId/current_device')
        .set({
      'device_id': deviceId,
      'device_name': deviceModel,
      'session_start': ServerValue.timestamp,
      'last_active': ServerValue.timestamp,
      'force_logout': false,
    });

    // Add to history
    await database
        .ref('device_sessions/$userId/history')
        .push()
        .set({
      'device_id': deviceId,
      'device_name': deviceModel,
      'session_start': ServerValue.timestamp,
      'event': 'login',
    });
  }

  Future<void> updateSessionActivity(String userId) async {
    await database
        .ref('device_sessions/$userId/current_device')
        .update({
      'last_active': ServerValue.timestamp,
    });
  }

  Future<void> endSession(String userId) async {
    try {
      // Get current session
      final snapshot = await database
          .ref('device_sessions/$userId/current_device')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Add to history
        await database
            .ref('device_sessions/$userId/history')
            .push()
            .set({
          ...data,
          'session_end': ServerValue.timestamp,
          'event': 'logout',
        });
      }

      // Remove current session
      await database
          .ref('device_sessions/$userId/current_device')
          .remove();
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> logSessionEvent(String userId, String event) async {
    final deviceId = await getDeviceId();
    
    await database
        .ref('device_sessions/$userId/history')
        .push()
        .set({
      'device_id': deviceId,
      'event': event,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<bool> handleDeviceSwitch(String userId) async {
    try {
      final snapshot = await database
          .ref('device_sessions/$userId/current_device')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final lastSync = data['last_sync'] as int?;
        
        if (lastSync != null) {
          // Mark that sync is needed after device switch
          await prefs.setBool('device_switch_sync_needed', true);
          return true;
        }
      }
    } catch (e) {
      // Ignore errors
    }
    
    return false;
  }

  void dispose() {
    _forceLogoutSubscription?.cancel();
    _forceLogoutController.close();
  }
}