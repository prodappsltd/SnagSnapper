import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';

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

/// Simple integration test to verify database functionality
void main() {
  late AppDatabase database;
  late String tempDbPath;
  late MockPathProviderPlatform mockPathProvider;

  setUpAll(() {
    // Set up mock path provider
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
  });

  setUp(() async {
    // Get database instance (will create in temp directory)
    database = AppDatabase.instance;
  });

  tearDown(() async {
    // Close database
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

  group('Database Integration Tests', () {
    test('should create and access database', () async {
      // Assert database is open
      expect(database.isOpen, isTrue);
    });

    test('should perform full CRUD cycle with Profile', () async {
      // Arrange
      final now = DateTime.now();
      final testUser = AppUser(
        id: 'integration_test_001',
        name: 'Integration Test User',
        email: 'integration@test.com',
        phone: '+1234567890',
        jobTitle: 'Test Manager',
        companyName: 'Test Company Ltd',
        postcodeOrArea: 'TEST 123',
        dateFormat: 'dd-MM-yyyy',
        imageLocalPath: 'SnagSnapper/test/Profile/profile.jpg',
        needsProfileSync: true,
        needsImageSync: false,
        currentDeviceId: 'test_device_001',
        createdAt: now,
        updatedAt: now,
      );

      // Act - INSERT
      final insertResult = await database.profileDao.insertProfile(testUser);
      
      // Assert insert successful
      expect(insertResult, isTrue);

      // Act - READ
      final retrievedUser = await database.profileDao.getProfile('integration_test_001');
      
      // Assert read successful
      expect(retrievedUser, isNotNull);
      expect(retrievedUser!.id, equals('integration_test_001'));
      expect(retrievedUser.name, equals('Integration Test User'));
      expect(retrievedUser.email, equals('integration@test.com'));
      expect(retrievedUser.needsProfileSync, isTrue);

      // Act - UPDATE
      final updatedUser = retrievedUser.copyWith(
        name: 'Updated Integration User',
        jobTitle: 'Updated Manager',
      );
      final updateResult = await database.profileDao.updateProfile(
        'integration_test_001', 
        updatedUser
      );
      
      // Assert update successful
      expect(updateResult, isTrue);

      // Verify update
      final afterUpdate = await database.profileDao.getProfile('integration_test_001');
      expect(afterUpdate, isNotNull);
      expect(afterUpdate!.name, equals('Updated Integration User'));
      expect(afterUpdate.jobTitle, equals('Updated Manager'));

      // Act - DELETE
      final deleteResult = await database.profileDao.deleteProfile('integration_test_001');
      
      // Assert delete successful
      expect(deleteResult, isTrue);

      // Verify deletion
      final afterDelete = await database.profileDao.getProfile('integration_test_001');
      expect(afterDelete, isNull);
    });

    test('should manage sync flags correctly', () async {
      // Arrange
      final now = DateTime.now();
      final testUser = AppUser(
        id: 'sync_test_001',
        name: 'Sync Test User',
        email: 'sync@test.com',
        phone: '+9876543210',
        jobTitle: 'Sync Tester',
        companyName: 'Sync Co',
        createdAt: now,
        updatedAt: now,
      );

      // Insert user
      await database.profileDao.insertProfile(testUser);

      // Act - Set sync flags
      await database.profileDao.setNeedsProfileSync('sync_test_001');
      await database.profileDao.setNeedsImageSync('sync_test_001');

      // Assert flags are set
      final userWithFlags = await database.profileDao.getProfile('sync_test_001');
      expect(userWithFlags!.needsProfileSync, isTrue);
      expect(userWithFlags.needsImageSync, isTrue);
      expect(userWithFlags.needsSignatureSync, isFalse);

      // Act - Clear sync flags
      await database.profileDao.clearSyncFlags('sync_test_001');

      // Assert flags are cleared
      final userAfterClear = await database.profileDao.getProfile('sync_test_001');
      expect(userAfterClear!.needsProfileSync, isFalse);
      expect(userAfterClear.needsImageSync, isFalse);
      expect(userAfterClear.needsSignatureSync, isFalse);
      expect(userAfterClear.lastSyncTime, isNotNull);

      // Cleanup
      await database.profileDao.deleteProfile('sync_test_001');
    });

    test('should get profiles needing sync', () async {
      // Arrange - Insert multiple profiles with different sync states
      final now = DateTime.now();
      
      final user1 = AppUser(
        id: 'needs_sync_001',
        name: 'User 1',
        email: 'user1@test.com',
        phone: '+1111111111',
        jobTitle: 'Job 1',
        companyName: 'Company 1',
        needsProfileSync: true,
        createdAt: now,
        updatedAt: now,
      );

      final user2 = AppUser(
        id: 'needs_sync_002',
        name: 'User 2',
        email: 'user2@test.com',
        phone: '+2222222222',
        jobTitle: 'Job 2',
        companyName: 'Company 2',
        needsImageSync: true,
        createdAt: now,
        updatedAt: now,
      );

      final user3 = AppUser(
        id: 'no_sync_needed',
        name: 'User 3',
        email: 'user3@test.com',
        phone: '+3333333333',
        jobTitle: 'Job 3',
        companyName: 'Company 3',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        createdAt: now,
        updatedAt: now,
      );

      await database.profileDao.insertProfile(user1);
      await database.profileDao.insertProfile(user2);
      await database.profileDao.insertProfile(user3);

      // Act - Get profiles needing sync
      final profilesNeedingSync = await database.profileDao.getProfilesNeedingSync();

      // Assert - Should return only profiles with sync flags
      expect(profilesNeedingSync.length, equals(2));
      expect(profilesNeedingSync.any((p) => p.id == 'needs_sync_001'), isTrue);
      expect(profilesNeedingSync.any((p) => p.id == 'needs_sync_002'), isTrue);
      expect(profilesNeedingSync.any((p) => p.id == 'no_sync_needed'), isFalse);

      // Cleanup
      await database.profileDao.deleteProfile('needs_sync_001');
      await database.profileDao.deleteProfile('needs_sync_002');
      await database.profileDao.deleteProfile('no_sync_needed');
    });

    test('should handle device management', () async {
      // Arrange
      final now = DateTime.now();
      final testUser = AppUser(
        id: 'device_test_001',
        name: 'Device Test User',
        email: 'device@test.com',
        phone: '+5555555555',
        jobTitle: 'Device Tester',
        companyName: 'Device Co',
        createdAt: now,
        updatedAt: now,
      );

      await database.profileDao.insertProfile(testUser);

      // Act - Update device info
      await database.profileDao.updateDeviceInfo('device_test_001', 'new_device_123');

      // Assert device info updated
      final userWithDevice = await database.profileDao.getProfile('device_test_001');
      expect(userWithDevice!.currentDeviceId, equals('new_device_123'));
      expect(userWithDevice.lastLoginTime, isNotNull);

      // Act - Check device match
      final matchesCorrect = await database.profileDao.checkDeviceMatch(
        'device_test_001', 
        'new_device_123'
      );
      final matchesWrong = await database.profileDao.checkDeviceMatch(
        'device_test_001', 
        'wrong_device'
      );

      // Assert device matching works
      expect(matchesCorrect, isTrue);
      expect(matchesWrong, isFalse);

      // Cleanup
      await database.profileDao.deleteProfile('device_test_001');
    });

    test('should execute transactions correctly', () async {
      // Arrange
      final now = DateTime.now();
      final testUser = AppUser(
        id: 'transaction_test_001',
        name: 'Transaction User',
        email: 'transaction@test.com',
        phone: '+7777777777',
        jobTitle: 'Transaction Tester',
        companyName: 'Transaction Co',
        createdAt: now,
        updatedAt: now,
      );

      // Act - Execute multiple operations in transaction
      final result = await database.profileDao.inTransaction(() async {
        // Insert profile
        await database.profileDao.insertProfile(testUser);
        
        // Set sync flags
        await database.profileDao.setNeedsProfileSync('transaction_test_001');
        await database.profileDao.setNeedsImageSync('transaction_test_001');
        
        return true;
      });

      // Assert transaction completed
      expect(result, isTrue);

      // Verify all operations were applied
      final profile = await database.profileDao.getProfile('transaction_test_001');
      expect(profile, isNotNull);
      expect(profile!.needsProfileSync, isTrue);
      expect(profile.needsImageSync, isTrue);

      // Cleanup
      await database.profileDao.deleteProfile('transaction_test_001');
    });

    group('Performance Tests', () {
      test('should complete operations within performance requirements', () async {
        // Arrange
        final now = DateTime.now();
        final perfUser = AppUser(
          id: 'perf_test_001',
          name: 'Performance Test User',
          email: 'perf@test.com',
          phone: '+8888888888',
          jobTitle: 'Performance Tester',
          companyName: 'Performance Co',
          createdAt: now,
          updatedAt: now,
        );

        // Test INSERT performance
        final insertStopwatch = Stopwatch()..start();
        await database.profileDao.insertProfile(perfUser);
        insertStopwatch.stop();
        
        // Assert insert < 100ms
        expect(insertStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Insert took ${insertStopwatch.elapsedMilliseconds}ms, expected < 100ms');

        // Test READ performance
        final readStopwatch = Stopwatch()..start();
        await database.profileDao.getProfile('perf_test_001');
        readStopwatch.stop();
        
        // Assert read < 100ms
        expect(readStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Read took ${readStopwatch.elapsedMilliseconds}ms, expected < 100ms');

        // Test UPDATE performance
        final updateStopwatch = Stopwatch()..start();
        final updatedPerfUser = perfUser.copyWith(name: 'Updated Performance User');
        await database.profileDao.updateProfile('perf_test_001', updatedPerfUser);
        updateStopwatch.stop();
        
        // Assert update < 100ms
        expect(updateStopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Update took ${updateStopwatch.elapsedMilliseconds}ms, expected < 100ms');

        // Cleanup
        await database.profileDao.deleteProfile('perf_test_001');
      });
    });
  });
}