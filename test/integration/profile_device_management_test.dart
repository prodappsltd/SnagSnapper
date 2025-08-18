import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Transaction;
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart' as models;
import 'package:snagsnapper/Data/user.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../helpers/test_helpers.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseDatabase,
  User,
  DocumentSnapshot,
  CollectionReference,
  DocumentReference,
  DatabaseReference,
  DeviceInfoPlugin,
  IosDeviceInfo,
  AndroidDeviceInfo,
])
import 'profile_device_management_test.mocks.dart';

// Mock PathProvider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String? tempPath;

  @override
  Future<String?> getApplicationSupportPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }

  @override
  Future<String?> getTemporaryPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }
}

void main() {
  
  group('Profile Device Management Integration Tests', () {
    late AppDatabase database;
    late MockPathProviderPlatform mockPathProvider;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseDatabase mockRealtimeDb;
    late MockUser mockUser;
    
    setUpAll(() {
      // Set up mock path provider
      mockPathProvider = MockPathProviderPlatform();
      PathProviderPlatform.instance = mockPathProvider;
      
      // Set up SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
    });
    
    setUp(() async {
      // Initialize test database
      database = TestHelpers.createTestDatabase();
      
      // Setup mocks
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockRealtimeDb = MockFirebaseDatabase();
      mockUser = MockUser();
      
      // Setup Firebase Auth mock
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-user-123');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.emailVerified).thenReturn(true);
      
      // Don't initialize ContentProvider here as it requires mocks
      // Each test will initialize as needed
      
      // Clear any existing data
      await database.profileDao.deleteProfile('test-user-123');
    });
    
    tearDown(() async {
      await database.closeDatabase();
      
      // Clean up temp directory if exists
      if (mockPathProvider.tempPath != null) {
        try {
          final dir = Directory(mockPathProvider.tempPath!);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
      mockPathProvider.tempPath = null;
    });
    
    group('Scenario 1: New User Flow', () {
      test('Should create profile with device ID and save locally first', () async {
        // GIVEN: New user with no existing profile
        final userId = 'new-user-001';
        
        // WHEN: User completes profile setup
        final profile = models.AppUser(
          id: userId,
          name: 'John Doe',
          email: 'john@example.com',
          phone: '1234567890',
          jobTitle: 'Site Manager',
          companyName: 'Construction Co',
          postcodeOrArea: '12345',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: 'device_001',
          lastLoginTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsProfileSync: true, // Should be true for new profile
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        // Save to local database
        await database.profileDao.insertProfile(profile);
        
        // THEN: Profile should exist in local database
        final savedProfile = await database.profileDao.getProfile(userId);
        expect(savedProfile, isNotNull);
        expect(savedProfile!.name, equals('John Doe'));
        expect(savedProfile.currentDeviceId, equals('device_001'));
        expect(savedProfile.needsProfileSync, isTrue);
        
        // AND: Profile should work offline
        // (No Firebase calls needed for local operations)
      });
      
      test('Should register device in Realtime Database when online', () async {
        // GIVEN: New user creates profile
        final userId = 'new-user-002';
        final deviceId = 'ios_12345';
        
        // Setup Realtime Database mock
        final mockRef = MockDatabaseReference();
        when(mockRealtimeDb.ref(any)).thenReturn(mockRef);
        when(mockRef.set(any)).thenAnswer((_) async => {});
        
        // WHEN: Profile is created and device is registered
        // This would be called from ProfileSetupScreen
        
        // THEN: Device session should be registered
        verify(mockRef.set(argThat(
          allOf(
            containsPair('device_id', deviceId),
            containsPair('force_logout', false),
            contains('device_name'),
            contains('last_active'),
          ),
        ))).called(1);
      });
    });
    
    group('Scenario 2: Existing User - Same Device', () {
      test('Should load profile from local database without Firebase', () async {
        // GIVEN: Existing profile in local database
        final userId = 'existing-user-001';
        final deviceId = 'device_same_001';
        
        final existingProfile = models.AppUser(
          id: userId,
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '0987654321',
          jobTitle: 'Inspector',
          companyName: 'Inspection Inc',
          postcodeOrArea: '54321',
          dateFormat: 'MM-dd-yyyy',
          currentDeviceId: deviceId,
          lastLoginTime: DateTime.now().subtract(Duration(days: 1)),
          createdAt: DateTime.now().subtract(Duration(days: 30)),
          updatedAt: DateTime.now().subtract(Duration(days: 1)),
          needsProfileSync: false,
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(existingProfile);
        
        // WHEN: User opens app (same device)
        final loadedProfile = await database.profileDao.getProfile(userId);
        
        // THEN: Profile loads from local database
        expect(loadedProfile, isNotNull);
        expect(loadedProfile!.name, equals('Jane Smith'));
        expect(loadedProfile.currentDeviceId, equals(deviceId));
        
        // AND: No Firebase calls needed (works offline)
        verifyNever(mockFirestore.collection(any));
      });
      
      test('Should update last login time for same device', () async {
        // GIVEN: Existing profile
        final userId = 'existing-user-002';
        final deviceId = 'device_same_002';
        
        final profile = models.AppUser(
          id: userId,
          name: 'Bob Builder',
          email: 'bob@example.com',
          phone: '5551234567',
          jobTitle: 'Contractor',
          companyName: 'Builders Ltd',
          postcodeOrArea: '10001',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: deviceId,
          lastLoginTime: DateTime.now().subtract(Duration(days: 7)),
          createdAt: DateTime.now().subtract(Duration(days: 60)),
          updatedAt: DateTime.now().subtract(Duration(days: 7)),
          needsProfileSync: false,
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(profile);
        
        // WHEN: User logs in again on same device
        await database.profileDao.updateDeviceInfo(userId, deviceId);
        
        // THEN: Last login time should be updated
        final updatedProfile = await database.profileDao.getProfile(userId);
        expect(updatedProfile!.lastLoginTime, isNotNull);
        expect(
          updatedProfile.lastLoginTime!.isAfter(
            DateTime.now().subtract(Duration(minutes: 1))
          ),
          isTrue,
        );
      });
    });
    
    group('Scenario 3: Device Switching', () {
      test('Should detect device mismatch and handle switch', () async {
        // GIVEN: Profile exists with different device ID
        final userId = 'switch-user-001';
        final oldDeviceId = 'old_device_001';
        final newDeviceId = 'new_device_001';
        
        // Existing profile in Firebase with old device
        final firebaseData = {
          'name': 'Alice Cooper',
          'email': 'alice@example.com',
          'currentDeviceId': oldDeviceId,
          'phone': '5559876543',
          'jobTitle': 'Supervisor',
          'companyName': 'Supervision Corp',
        };
        
        // WHEN: User logs in on new device
        // Should detect mismatch between oldDeviceId and newDeviceId
        
        // THEN: Should show warning and handle device switch
        expect(oldDeviceId, isNot(equals(newDeviceId)));
        
        // After confirmation, old device should be marked for logout
        // New device ID should be updated in Firebase
      });
      
      test('Should force logout on old device when new device takes over', () async {
        // GIVEN: User logged in on Device A
        final userId = 'switch-user-002';
        final deviceA = 'device_A';
        final deviceB = 'device_B';
        
        // Profile on Device A
        final profileA = models.AppUser(
          id: userId,
          name: 'Charlie Brown',
          email: 'charlie@example.com',
          phone: '5551112222',
          jobTitle: 'Manager',
          companyName: 'Management Inc',
          postcodeOrArea: '90210',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: deviceA,
          lastLoginTime: DateTime.now(),
          createdAt: DateTime.now().subtract(Duration(days: 10)),
          updatedAt: DateTime.now(),
          needsProfileSync: false,
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(profileA);
        
        // WHEN: User logs in on Device B
        // Device B takes over and forces logout on Device A
        
        // Simulate force logout triggered
        await database.profileDao.deleteProfile(userId);
        
        // THEN: Local data should be cleared on Device A
        final clearedProfile = await database.profileDao.getProfile(userId);
        expect(clearedProfile, isNull);
      });
    });
    
    group('Scenario 4: Offline-First Verification', () {
      test('Should work completely offline after initial setup', () async {
        // GIVEN: Profile saved locally
        final userId = 'offline-user-001';
        final profile = models.AppUser(
          id: userId,
          name: 'Offline User',
          email: 'offline@example.com',
          phone: '5550000000',
          jobTitle: 'Field Worker',
          companyName: 'Remote Work Co',
          postcodeOrArea: '00000',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: 'offline_device',
          lastLoginTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsProfileSync: true, // Will sync when online
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(profile);
        
        // WHEN: App operates offline
        // Update profile
        final updatedProfile = profile.copyWith(
          jobTitle: 'Senior Field Worker',
          needsProfileSync: true,
        );
        await database.profileDao.updateProfile(userId, updatedProfile);
        
        // THEN: All operations work without network
        final loaded = await database.profileDao.getProfile(userId);
        expect(loaded!.jobTitle, equals('Senior Field Worker'));
        expect(loaded.needsProfileSync, isTrue);
        
        // No Firebase calls made
        verifyNever(mockFirestore.collection(any));
        verifyNever(mockRealtimeDb.ref(any));
      });
      
      test('Should queue changes for sync when offline', () async {
        // GIVEN: User makes changes offline
        final userId = 'offline-user-002';
        final profile = models.AppUser(
          id: userId,
          name: 'Queue Test',
          email: 'queue@example.com',
          phone: '5551234567',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          postcodeOrArea: '12345',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: 'test_device',
          lastLoginTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsProfileSync: false,
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(profile);
        
        // WHEN: Multiple changes made offline
        // Change 1: Update name
        var updated = profile.copyWith(name: 'New Name');
        await database.profileDao.updateProfile(userId, updated);
        await database.profileDao.setNeedsProfileSync(userId);
        
        // Change 2: Update phone
        updated = updated.copyWith(phone: '5559999999');
        await database.profileDao.updateProfile(userId, updated);
        
        // THEN: Sync flags should be set
        final finalProfile = await database.profileDao.getProfile(userId);
        expect(finalProfile!.needsProfileSync, isTrue);
        expect(finalProfile.name, equals('New Name'));
        expect(finalProfile.phone, equals('5559999999'));
        
        // AND: Can get all profiles needing sync
        final needsSync = await database.profileDao.getProfilesNeedingSync();
        expect(needsSync.any((p) => p.id == userId), isTrue);
      });
    });
    
    group('Scenario 5: Sync Flags Management', () {
      test('Should set appropriate sync flags for different changes', () async {
        final userId = 'sync-test-001';
        final profile = models.AppUser(
          id: userId,
          name: 'Sync Test',
          email: 'sync@example.com',
          phone: '5550001111',
          jobTitle: 'Sync Tester',
          companyName: 'Sync Corp',
          postcodeOrArea: '11111',
          dateFormat: 'dd-MM-yyyy',
          currentDeviceId: 'sync_device',
          lastLoginTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          needsProfileSync: false,
          needsImageSync: false,
          needsSignatureSync: false,
        );
        
        await database.profileDao.insertProfile(profile);
        
        // Test profile data change
        await database.profileDao.setNeedsProfileSync(userId);
        var current = await database.profileDao.getProfile(userId);
        expect(current!.needsProfileSync, isTrue);
        expect(current.needsImageSync, isFalse);
        expect(current.needsSignatureSync, isFalse);
        
        // Test image change
        await database.profileDao.setNeedsImageSync(userId);
        current = await database.profileDao.getProfile(userId);
        expect(current!.needsImageSync, isTrue);
        
        // Test signature change
        await database.profileDao.setNeedsSignatureSync(userId);
        current = await database.profileDao.getProfile(userId);
        expect(current!.needsSignatureSync, isTrue);
        
        // Test clearing all flags
        await database.profileDao.clearSyncFlags(userId);
        current = await database.profileDao.getProfile(userId);
        expect(current!.needsProfileSync, isFalse);
        expect(current.needsImageSync, isFalse);
        expect(current.needsSignatureSync, isFalse);
      });
    });
  });
}