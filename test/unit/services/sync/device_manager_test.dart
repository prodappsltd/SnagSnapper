import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:snagsnapper/services/sync/device_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

@GenerateMocks([
  FirebaseDatabase,
  DatabaseReference,
  DataSnapshot,
  DatabaseEvent,
  FirebaseAuth,
  User,
  DeviceInfoPlugin,
  AndroidDeviceInfo,
  IosDeviceInfo,
  SharedPreferences,
])
import 'device_manager_test.mocks.dart';

void main() {
  group('DeviceManager', () {
    late DeviceManager deviceManager;
    late MockFirebaseDatabase mockDatabase;
    late MockFirebaseAuth mockAuth;
    late MockDeviceInfoPlugin mockDeviceInfo;
    late MockSharedPreferences mockPrefs;
    late MockUser mockUser;

    setUp(() {
      mockDatabase = MockFirebaseDatabase();
      mockAuth = MockFirebaseAuth();
      mockDeviceInfo = MockDeviceInfoPlugin();
      mockPrefs = MockSharedPreferences();
      mockUser = MockUser();

      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_user_id');

      deviceManager = DeviceManager(
        database: mockDatabase,
        auth: mockAuth,
        deviceInfo: mockDeviceInfo,
        prefs: mockPrefs,
      );
    });

    group('Single Device Enforcement', () {
      group('Device Validation', () {
        test('should allow sync when same device', () async {
          // Setup stored device ID
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          // Setup Firebase device session
          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          final mockEvent = MockDatabaseEvent();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn({
            'device_id': 'test_device_123', // Same device
            'last_active': DateTime.now().millisecondsSinceEpoch,
            'force_logout': false,
          });

          final isValid = await deviceManager.validateDevice('test_user_id');

          expect(isValid, isTrue);
          verify(mockRef.get()).called(1);
        });

        test('should block sync when different device', () async {
          // Setup stored device ID
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          // Setup Firebase device session with different device
          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn({
            'device_id': 'different_device_456', // Different device
            'last_active': DateTime.now().millisecondsSinceEpoch,
            'force_logout': false,
          });

          final isValid = await deviceManager.validateDevice('test_user_id');

          expect(isValid, isFalse);
        });

        test('should generate device ID if not exists', () async {
          when(mockPrefs.getString('device_id')).thenReturn(null);
          when(mockPrefs.setString('device_id', any))
              .thenAnswer((_) async => true);

          // Mock device info based on platform
          if (Platform.isAndroid) {
            final mockAndroidInfo = MockAndroidDeviceInfo();
            when(mockDeviceInfo.androidInfo)
                .thenAnswer((_) async => mockAndroidInfo);
            when(mockAndroidInfo.id).thenReturn('android_id_123');
            when(mockAndroidInfo.model).thenReturn('Pixel 5');
          } else if (Platform.isIOS) {
            final mockIosInfo = MockIosDeviceInfo();
            when(mockDeviceInfo.iosInfo)
                .thenAnswer((_) async => mockIosInfo);
            when(mockIosInfo.identifierForVendor).thenReturn('ios_id_123');
            when(mockIosInfo.model).thenReturn('iPhone 12');
          }

          final deviceId = await deviceManager.getDeviceId();

          expect(deviceId, isNotEmpty);
          verify(mockPrefs.setString('device_id', any)).called(1);
        });

        test('should store device info correctly', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');
          when(mockPrefs.setString(argThat(isA<String>()), argThat(isA<String>()))).thenAnswer((_) async => true);

          // Mock device info
          if (Platform.isAndroid) {
            final mockAndroidInfo = MockAndroidDeviceInfo();
            when(mockDeviceInfo.androidInfo)
                .thenAnswer((_) async => mockAndroidInfo);
            when(mockAndroidInfo.model).thenReturn('Pixel 5');
            when(mockAndroidInfo.brand).thenReturn('Google');
            when(mockAndroidInfo.version.release).thenReturn('11');
          }

          await deviceManager.storeDeviceInfo();

          verify(mockPrefs.setString('device_model', any)).called(1);
          verify(mockPrefs.setString('device_os', any)).called(1);
        });
      });

      group('Device Switching', () {
        test('should detect different device login', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn({
            'device_id': 'different_device_456',
            'device_name': 'iPhone 13',
            'last_active': DateTime.now().millisecondsSinceEpoch,
          });

          final result = await deviceManager.checkForDeviceConflict('test_user_id');

          expect(result.hasConflict, isTrue);
          expect(result.otherDeviceName, equals('iPhone 13'));
        });

        test('should show device conflict dialog info', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          
          final lastActive = DateTime.now().subtract(Duration(hours: 2));
          when(mockSnapshot.value).thenReturn({
            'device_id': 'different_device_456',
            'device_name': 'iPad Pro',
            'last_active': lastActive.millisecondsSinceEpoch,
          });

          final result = await deviceManager.checkForDeviceConflict('test_user_id');

          expect(result.hasConflict, isTrue);
          expect(result.otherDeviceName, equals('iPad Pro'));
          expect(result.lastActiveTime, isNotNull);
          expect(result.canForceLogout, isTrue);
        });

        test('should force logout other device', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          final mockCurrentRef = MockDatabaseReference();
          final mockForceRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockCurrentRef);
          when(mockDatabase.ref('device_sessions/test_user_id/force_logout'))
              .thenReturn(mockForceRef);
          
          when(mockCurrentRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});
          when(mockForceRef.set(true)).thenAnswer((_) async => {});

          final success = await deviceManager.forceLogoutOtherDevice('test_user_id');

          expect(success, isTrue);
          verify(mockForceRef.set(true)).called(1);
          verify(mockCurrentRef.set(argThat(
            predicate<Map>((data) =>
              data['device_id'] == 'test_device_123' &&
              data['force_logout'] == false
            )
          ))).called(1);
        });

        test('should update device records after switch', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('new_device_789');
          when(mockPrefs.getString('device_model'))
              .thenReturn('Galaxy S21');

          final mockRef = MockDatabaseReference();
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});

          await deviceManager.registerDevice('test_user_id');

          verify(mockRef.set(argThat(
            predicate<Map>((data) =>
              data['device_id'] == 'new_device_789' &&
              data['device_name'] == 'Galaxy S21' &&
              data['last_active'] != null &&
              data['force_logout'] == false
            )
          ))).called(1);
        });
      });

      group('Realtime Database Integration', () {
        test('should listen for force_logout', () async {
          final mockRef = MockDatabaseReference();
          final streamController = StreamController<DatabaseEvent>();
          
          when(mockDatabase.ref('device_sessions/test_user_id/force_logout'))
              .thenReturn(mockRef);
          when(mockRef.onValue).thenAnswer((_) => streamController.stream);

          final forceLogoutStream = deviceManager.setupForceLogoutListener('test_user_id');
          final logoutEvents = <bool>[];
          forceLogoutStream.listen(logoutEvents.add);

          // Simulate force logout event
          final mockEvent = MockDatabaseEvent();
          final mockSnapshot = MockDataSnapshot();
          when(mockEvent.snapshot).thenReturn(mockSnapshot);
          when(mockSnapshot.value).thenReturn(true);
          
          streamController.add(mockEvent);
          await Future.delayed(Duration(milliseconds: 100));

          expect(logoutEvents, contains(true));
          
          streamController.close();
        });

        test('should update last_active timestamp', () async {
          final mockRef = MockDatabaseReference();
          final mockChild = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.child('last_active')).thenReturn(mockChild);
          when(mockChild.set(argThat(anyOf(isA<bool>(), isA<Map>())))).thenAnswer((_) async => {});

          await deviceManager.updateDeviceActivity('test_user_id');

          verify(mockChild.set(argThat(
            predicate<int>((timestamp) =>
              timestamp > 0 &&
              timestamp <= DateTime.now().millisecondsSinceEpoch
            )
          ))).called(1);
        });

        test('should handle connection loss gracefully', () async {
          final mockRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenThrow(Exception('Network error'));

          final isValid = await deviceManager.validateDevice('test_user_id');

          // Should allow local operation when offline
          expect(isValid, isTrue);
        });

        test('should clean up on logout', () async {
          final mockRef = MockDatabaseReference();
          final mockForceRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockDatabase.ref('device_sessions/test_user_id/force_logout'))
              .thenReturn(mockForceRef);
          
          when(mockRef.remove()).thenAnswer((_) async => {});
          when(mockForceRef.remove()).thenAnswer((_) async => {});
          when(mockPrefs.remove('device_id')).thenAnswer((_) async => true);

          await deviceManager.cleanupDeviceSession('test_user_id');

          verify(mockRef.remove()).called(1);
          verify(mockForceRef.remove()).called(1);
          verify(mockPrefs.remove('device_id')).called(1);
        });
      });

      group('Session Management', () {
        test('should create session on login', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');
          when(mockPrefs.getString('device_model'))
              .thenReturn('iPhone 12');

          final mockRef = MockDatabaseReference();
          final mockHistoryRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockDatabase.ref('device_sessions/test_user_id/history'))
              .thenReturn(mockHistoryRef);
          
          when(mockRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});
          when(mockHistoryRef.push()).thenReturn(mockHistoryRef);
          when(mockHistoryRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});

          await deviceManager.createSession('test_user_id');

          verify(mockRef.set(argThat(
            predicate<Map>((data) =>
              data['device_id'] == 'test_device_123' &&
              data['device_name'] == 'iPhone 12' &&
              data['session_start'] != null
            )
          ))).called(1);
        });

        test('should update session activity', () async {
          final mockRef = MockDatabaseReference();
          final mockChild = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.child('last_active')).thenReturn(mockChild);
          when(mockRef.child('activity_count')).thenReturn(mockChild);
          
          when(mockChild.set(argThat(anyOf(isA<bool>(), isA<Map>())))).thenAnswer((_) async => {});

          await deviceManager.updateSessionActivity('test_user_id');

          verify(mockRef.child('last_active').set(any)).called(1);
        });

        test('should clean session on logout', () async {
          final mockRef = MockDatabaseReference();
          final mockHistoryRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockDatabase.ref('device_sessions/test_user_id/history'))
              .thenReturn(mockHistoryRef);
          
          final mockSnapshot = MockDataSnapshot();
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn({
            'device_id': 'test_device_123',
            'session_start': DateTime.now().subtract(Duration(hours: 2)).millisecondsSinceEpoch,
          });
          
          when(mockRef.remove()).thenAnswer((_) async => {});
          when(mockHistoryRef.push()).thenReturn(mockHistoryRef);
          when(mockHistoryRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});

          await deviceManager.endSession('test_user_id');

          verify(mockRef.remove()).called(1);
          verify(mockHistoryRef.push().set(argThat(
            predicate<Map>((data) =>
              data['session_end'] != null
            )
          ))).called(1);
        });

        test('should handle expired sessions', () async {
          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          
          // Session expired (last active > 30 days ago)
          final expiredTime = DateTime.now().subtract(Duration(days: 31));
          when(mockSnapshot.value).thenReturn({
            'device_id': 'test_device_123',
            'last_active': expiredTime.millisecondsSinceEpoch,
          });

          final isValid = await deviceManager.validateDevice('test_user_id');

          expect(isValid, isFalse);
          verify(mockRef.get()).called(1);
        });
      });

      group('Multi-Device Scenarios', () {
        test('should prevent concurrent logins', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('device_1');

          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          
          // First check - no device
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn(null);
          
          // Try to register
          when(mockRef.set(argThat(isA<Map>()))).thenAnswer((_) async {
            // Simulate another device registered in between
            throw Exception('Device already registered');
          });

          final success = await deviceManager.registerDevice('test_user_id');

          expect(success, isFalse);
        });

        test('should handle force logout mechanism', () async {
          final mockRef = MockDatabaseReference();
          final streamController = StreamController<DatabaseEvent>();
          
          when(mockDatabase.ref('device_sessions/test_user_id/force_logout'))
              .thenReturn(mockRef);
          when(mockRef.onValue).thenAnswer((_) => streamController.stream);

          bool wasLoggedOut = false;
          deviceManager.onForceLogout(() {
            wasLoggedOut = true;
          });

          deviceManager.setupForceLogoutListener('test_user_id');

          // Simulate force logout
          final mockEvent = MockDatabaseEvent();
          final mockSnapshot = MockDataSnapshot();
          when(mockEvent.snapshot).thenReturn(mockSnapshot);
          when(mockSnapshot.value).thenReturn(true);
          
          streamController.add(mockEvent);
          await Future.delayed(Duration(milliseconds: 100));

          expect(wasLoggedOut, isTrue);
          
          streamController.close();
        });

        test('should sync data on device switch', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('new_device');
          when(mockPrefs.getBool('device_switch_sync_needed'))
              .thenReturn(null);
          when(mockPrefs.setBool('device_switch_sync_needed', true))
              .thenAnswer((_) async => true);

          final mockRef = MockDatabaseReference();
          final mockSnapshot = MockDataSnapshot();
          
          when(mockDatabase.ref('device_sessions/test_user_id/current_device'))
              .thenReturn(mockRef);
          when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
          when(mockSnapshot.value).thenReturn({
            'device_id': 'old_device',
            'last_sync': DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch,
          });

          final needsSync = await deviceManager.handleDeviceSwitch('test_user_id');

          expect(needsSync, isTrue);
          verify(mockPrefs.setBool('device_switch_sync_needed', true)).called(1);
        });

        test('should track session history', () async {
          when(mockPrefs.getString('device_id'))
              .thenReturn('test_device_123');

          final mockHistoryRef = MockDatabaseReference();
          final mockPushRef = MockDatabaseReference();
          
          when(mockDatabase.ref('device_sessions/test_user_id/history'))
              .thenReturn(mockHistoryRef);
          when(mockHistoryRef.push()).thenReturn(mockPushRef);
          when(mockPushRef.set(argThat(isA<Map>()))).thenAnswer((_) async => {});

          await deviceManager.logSessionEvent('test_user_id', 'login');

          verify(mockPushRef.set(argThat(
            predicate<Map>((data) =>
              data['device_id'] == 'test_device_123' &&
              data['event'] == 'login' &&
              data['timestamp'] != null
            )
          ))).called(1);
        });
      });
    });
  });
}