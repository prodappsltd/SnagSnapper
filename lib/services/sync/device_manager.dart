import 'dart:async';
import 'dart:io';
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
  final SharedPreferences prefs;
  
  final _forceLogoutController = StreamController<bool>.broadcast();
  Function? _forceLogoutCallback;
  StreamSubscription<DatabaseEvent>? _forceLogoutSubscription;

  DeviceManager({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfo,
    SharedPreferences? prefs,
  })  : database = database ?? FirebaseDatabase.instance,
        auth = auth ?? FirebaseAuth.instance,
        deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        prefs = prefs ?? SharedPreferences.getInstance() as SharedPreferences;

  Stream<bool> get forceLogoutStream => _forceLogoutController.stream;

  Future<bool> validateDevice(String userId) async {
    try {
      final deviceId = await getDeviceId();
      
      final snapshot = await database
          .ref('device_sessions/$userId/current_device')
          .get();

      if (!snapshot.exists) {
        // No device registered yet
        return true;
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        return true;
      }

      // Check if it's the same device
      if (data['device_id'] == deviceId) {
        // Check if session is not expired (30 days)
        final lastActive = data['last_active'] as int?;
        if (lastActive != null) {
          final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
          if (DateTime.now().difference(lastActiveTime).inDays > 30) {
            return false; // Session expired
          }
        }
        return true;
      }

      return false; // Different device
    } catch (e) {
      // Allow local operation when offline
      return true;
    }
  }

  Future<String> getDeviceId() async {
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generate new device ID
      deviceId = await _generateDeviceId();
      await prefs.setString('device_id', deviceId);
      await storeDeviceInfo();
    }
    
    return deviceId;
  }

  Future<String> _generateDeviceId() async {
    String baseId;
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      baseId = androidInfo.id ?? '';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      baseId = iosInfo.identifierForVendor ?? '';
    } else {
      baseId = '';
    }
    
    // Add UUID for uniqueness
    final uuid = const Uuid();
    return '${baseId}_${uuid.v4()}';
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