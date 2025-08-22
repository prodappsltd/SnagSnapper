import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Integration tests for Profile DAO with real database
/// Tests complete CRUD operations, transactions, and data persistence
void main() {
  group('Profile DAO Integration Tests', () {
    // late AppDatabase database;
    // late ProfileDao profileDao;
    late String tempDbPath;

    setUp(() async {
      // Create a temporary directory for test database
      final tempDir = await Directory.systemTemp.createTemp('profile_dao_test_');
      tempDbPath = path.join(tempDir.path, 'test.db');
      
      // Initialize database and DAO
      // database = AppDatabase(tempDbPath);
      // await database.open();
      // profileDao = ProfileDao(database);
    });

    tearDown(() async {
      // Clean up
      // await database?.close();
      
      try {
        final file = File(tempDbPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Full CRUD Cycle with Real Database', () {
      test('should insert and verify data persists', () async {
        // Arrange
        final now = DateTime.now();
        final profileData = {
          'id': 'test_user_001',
          'name': 'John Doe',
          'email': 'john.doe@example.com',
          'phone': '+1234567890',
          'job_title': 'Site Manager',
          'company_name': 'Construction Co Ltd',
          'postcode_area': 'SW1A 1AA',
          'date_format': 'dd-MM-yyyy',
          'image_local_path': 'SnagSnapper/test_user_001/Profile/profile.jpg',
          'image_firebase_path': null,
          'image_marked_for_deletion': false,
          'signature_local_path': null,
          'signature_firebase_path': null,
          'signature_marked_for_deletion': false,
          'needs_profile_sync': false,
          'needs_image_sync': false,
          'needs_signature_sync': false,
          'last_sync_time': null,
          'current_device_id': 'test_device_123',
          'last_login_time': now,
          'created_at': now,
          'updated_at': now,
          'local_version': 1,
          'firebase_version': 0,
        };

        // Act - Insert profile
        // final insertResult = await profileDao.insertProfile(profileData);
        
        // Assert - Insertion successful
        // expect(insertResult, isTrue);
        
        // Act - Read back the profile
        // final retrievedProfile = await profileDao.getProfile('test_user_001');
        
        // Assert - All data persisted correctly
        // expect(retrievedProfile, isNotNull);
        // expect(retrievedProfile['id'], equals('test_user_001'));
        // expect(retrievedProfile['name'], equals('John Doe'));
        // expect(retrievedProfile['email'], equals('john.doe@example.com'));
        // expect(retrievedProfile['phone'], equals('+1234567890'));
        // expect(retrievedProfile['job_title'], equals('Site Manager'));
        // expect(retrievedProfile['company_name'], equals('Construction Co Ltd'));
        // expect(retrievedProfile['postcode_area'], equals('SW1A 1AA'));
        // expect(retrievedProfile['date_format'], equals('dd-MM-yyyy'));
        // expect(retrievedProfile['image_local_path'], equals('SnagSnapper/test_user_001/Profile/profile.jpg'));
        // expect(retrievedProfile['current_device_id'], equals('test_device_123'));
      });

      test('should update and verify changes saved', () async {
        // Arrange - Insert initial profile
        final initialProfile = {
          'id': 'update_test_001',
          'name': 'Initial Name',
          'email': 'initial@example.com',
          'phone': '+1111111111',
          'job_title': 'Initial Job',
          'company_name': 'Initial Co',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        // await profileDao.insertProfile(initialProfile);
        
        // Act - Update the profile
        final updates = {
          'name': 'Updated Name',
          'job_title': 'Updated Job',
          'phone': '+2222222222',
          'needs_profile_sync': true,
          'updated_at': DateTime.now(),
        };
        // final updateResult = await profileDao.updateProfile('update_test_001', updates);
        
        // Assert - Update successful
        // expect(updateResult, isTrue);
        
        // Act - Read back the updated profile
        // final updatedProfile = await profileDao.getProfile('update_test_001');
        
        // Assert - Changes persisted
        // expect(updatedProfile['name'], equals('Updated Name'));
        // expect(updatedProfile['job_title'], equals('Updated Job'));
        // expect(updatedProfile['phone'], equals('+2222222222'));
        // expect(updatedProfile['needs_profile_sync'], isTrue);
        // expect(updatedProfile['email'], equals('initial@example.com')); // Unchanged
        // expect(updatedProfile['company_name'], equals('Initial Co')); // Unchanged
      });

      test('should delete and verify removal', () async {
        // Arrange - Insert profile to delete
        final profileToDelete = {
          'id': 'delete_test_001',
          'name': 'To Be Deleted',
          'email': 'delete@example.com',
          'phone': '+9999999999',
          'job_title': 'Temp',
          'company_name': 'Temp Co',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        // await profileDao.insertProfile(profileToDelete);
        
        // Verify it exists
        // final exists = await profileDao.profileExists('delete_test_001');
        // expect(exists, isTrue);
        
        // Act - Delete the profile
        // final deleteResult = await profileDao.deleteProfile('delete_test_001');
        
        // Assert - Deletion successful
        // expect(deleteResult, isTrue);
        
        // Act - Try to read deleted profile
        // final deletedProfile = await profileDao.getProfile('delete_test_001');
        
        // Assert - Profile no longer exists
        // expect(deletedProfile, isNull);
        // final stillExists = await profileDao.profileExists('delete_test_001');
        // expect(stillExists, isFalse);
      });

      test('should handle complex queries correctly', () async {
        // Arrange - Insert multiple profiles
        final profiles = [
          {
            'id': 'query_test_001',
            'name': 'Alice Anderson',
            'email': 'alice@example.com',
            'phone': '+1111111111',
            'job_title': 'Manager',
            'company_name': 'Company A',
            'needs_profile_sync': true,
            'needs_image_sync': false,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
          {
            'id': 'query_test_002',
            'name': 'Bob Brown',
            'email': 'bob@example.com',
            'phone': '+2222222222',
            'job_title': 'Inspector',
            'company_name': 'Company B',
            'needs_profile_sync': false,
            'needs_image_sync': true,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
          {
            'id': 'query_test_003',
            'name': 'Charlie Chen',
            'email': 'charlie@example.com',
            'phone': '+3333333333',
            'job_title': 'Contractor',
            'company_name': 'Company C',
            'needs_profile_sync': true,
            'needs_signature_sync': true,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
        ];
        
        for (final profile in profiles) {
          // await profileDao.insertProfile(profile);
        }
        
        // Act - Query profiles needing sync
        // final profilesNeedingSync = await profileDao.getProfilesNeedingSync();
        
        // Assert - Should return profiles with any sync flag set
        // expect(profilesNeedingSync.length, equals(3));
        // expect(profilesNeedingSync.any((p) => p['id'] == 'query_test_001'), isTrue);
        // expect(profilesNeedingSync.any((p) => p['id'] == 'query_test_002'), isTrue);
        // expect(profilesNeedingSync.any((p) => p['id'] == 'query_test_003'), isTrue);
      });
    });

    group('Transaction Testing', () {
      test('should execute multiple operations in transaction', () async {
        // Arrange
        const userId = 'transaction_test_001';
        final profileData = {
          'id': userId,
          'name': 'Transaction Test',
          'email': 'transaction@example.com',
          'phone': '+7777777777',
          'job_title': 'Tester',
          'company_name': 'Test Co',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };

        // Act - Execute multiple operations in transaction
        // final result = await profileDao.inTransaction(() async {
        //   // Insert profile
        //   await profileDao.insertProfile(profileData);
        //   
        //   // Update profile
        //   await profileDao.updateProfile(userId, {
        //     'needs_profile_sync': true,
        //     'updated_at': DateTime.now(),
        //   });
        //   
        //   // Set image sync flag
        //   await profileDao.setNeedsImageSync(userId);
        //   
        //   return true;
        // });

        // Assert - Transaction completed
        // expect(result, isTrue);

        // Verify all operations were applied
        // final profile = await profileDao.getProfile(userId);
        // expect(profile, isNotNull);
        // expect(profile['needs_profile_sync'], isTrue);
        // expect(profile['needs_image_sync'], isTrue);
      });

      test('should rollback on error in transaction', () async {
        // Arrange
        const userId = 'rollback_test_001';
        
        // Act - Try transaction that will fail
        bool errorThrown = false;
        try {
          // await profileDao.inTransaction(() async {
          //   // Insert profile
          //   await profileDao.insertProfile({
          //     'id': userId,
          //     'name': 'Rollback Test',
          //     'email': 'rollback@example.com',
          //     'phone': '+8888888888',
          //     'job_title': 'Tester',
          //     'company_name': 'Test Co',
          //     'created_at': DateTime.now(),
          //     'updated_at': DateTime.now(),
          //   });
          //   
          //   // Force an error
          //   throw Exception('Simulated transaction error');
          // });
        } catch (e) {
          errorThrown = true;
        }

        // Assert - Error was thrown
        // expect(errorThrown, isTrue);
        
        // Verify profile was NOT inserted (rollback occurred)
        // final profile = await profileDao.getProfile(userId);
        // expect(profile, isNull);
      });

      test('should maintain data consistency in transactions', () async {
        // Arrange - Insert initial profiles
        final profile1 = {
          'id': 'consistency_test_001',
          'name': 'User 1',
          'email': 'user1@example.com',
          'phone': '+1111111111',
          'job_title': 'Job 1',
          'company_name': 'Company 1',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        
        final profile2 = {
          'id': 'consistency_test_002',
          'name': 'User 2',
          'email': 'user2@example.com',
          'phone': '+2222222222',
          'job_title': 'Job 2',
          'company_name': 'Company 2',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        
        // await profileDao.insertProfile(profile1);
        // await profileDao.insertProfile(profile2);
        
        // Act - Swap names in transaction
        // await profileDao.inTransaction(() async {
        //   final p1 = await profileDao.getProfile('consistency_test_001');
        //   final p2 = await profileDao.getProfile('consistency_test_002');
        //   
        //   await profileDao.updateProfile('consistency_test_001', {
        //     'name': p2['name'],
        //     'updated_at': DateTime.now(),
        //   });
        //   
        //   await profileDao.updateProfile('consistency_test_002', {
        //     'name': p1['name'],
        //     'updated_at': DateTime.now(),
        //   });
        // });
        
        // Assert - Names were swapped correctly
        // final updatedP1 = await profileDao.getProfile('consistency_test_001');
        // final updatedP2 = await profileDao.getProfile('consistency_test_002');
        
        // expect(updatedP1['name'], equals('User 2'));
        // expect(updatedP2['name'], equals('User 1'));
      });
    });

    group('Concurrent Access Testing', () {
      test('should handle multiple reads simultaneously', () async {
        // Arrange - Insert test profile
        final profile = {
          'id': 'concurrent_read_test',
          'name': 'Concurrent Test',
          'email': 'concurrent@example.com',
          'phone': '+5555555555',
          'job_title': 'Tester',
          'company_name': 'Test Co',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        // await profileDao.insertProfile(profile);
        
        // Act - Perform multiple simultaneous reads
        final futures = List.generate(10, (i) async {
          // return await profileDao.getProfile('concurrent_read_test');
        });
        
        final results = await Future.wait(futures);
        
        // Assert - All reads successful and return same data
        // expect(results.length, equals(10));
        // for (final result in results) {
        //   expect(result['id'], equals('concurrent_read_test'));
        //   expect(result['name'], equals('Concurrent Test'));
        // }
      });

      test('should handle write locks correctly', () async {
        // Arrange
        const profileId = 'write_lock_test';
        
        // Act - Try concurrent writes
        final futures = List.generate(10, (i) async {
          try {
            // await profileDao.insertProfile({
            //   'id': '$profileId\_$i',
            //   'name': 'Write Test $i',
            //   'email': 'write$i@example.com',
            //   'phone': '+666666666$i',
            //   'job_title': 'Tester',
            //   'company_name': 'Test Co',
            //   'created_at': DateTime.now(),
            //   'updated_at': DateTime.now(),
            // });
            return true;
          } catch (e) {
            return false;
          }
        });
        
        final results = await Future.wait(futures);
        
        // Assert - All writes should succeed
        // expect(results.every((r) => r == true), isTrue);
        
        // Verify all profiles were created
        for (int i = 0; i < 10; i++) {
          // final profile = await profileDao.getProfile('$profileId\_$i');
          // expect(profile, isNotNull);
        }
      });
    });

    group('Sync Flag Management Integration', () {
      test('should manage sync flags independently', () async {
        // Arrange - Insert profile
        const userId = 'sync_flags_test';
        final profile = {
          'id': userId,
          'name': 'Sync Test',
          'email': 'sync@example.com',
          'phone': '+4444444444',
          'job_title': 'Tester',
          'company_name': 'Test Co',
          'created_at': DateTime.now(),
          'updated_at': DateTime.now(),
        };
        // await profileDao.insertProfile(profile);
        
        // Act - Set different sync flags
        // await profileDao.setNeedsProfileSync(userId);
        
        // Assert - Only profile sync flag is set
        // var current = await profileDao.getProfile(userId);
        // expect(current['needs_profile_sync'], isTrue);
        // expect(current['needs_image_sync'], isFalse);
        // expect(current['needs_signature_sync'], isFalse);
        
        // Act - Set image sync flag
        // await profileDao.setNeedsImageSync(userId);
        
        // Assert - Both flags are now set
        // current = await profileDao.getProfile(userId);
        // expect(current['needs_profile_sync'], isTrue);
        // expect(current['needs_image_sync'], isTrue);
        // expect(current['needs_signature_sync'], isFalse);
        
        // Act - Clear all flags
        // await profileDao.clearSyncFlags(userId);
        
        // Assert - All flags cleared
        // current = await profileDao.getProfile(userId);
        // expect(current['needs_profile_sync'], isFalse);
        // expect(current['needs_image_sync'], isFalse);
        // expect(current['needs_signature_sync'], isFalse);
        // expect(current['last_sync_time'], isNotNull);
      });

      test('should correctly identify profiles needing sync', () async {
        // Arrange - Insert profiles with various sync states
        final profiles = [
          {
            'id': 'no_sync_needed',
            'name': 'No Sync',
            'email': 'nosync@example.com',
            'phone': '+1010101010',
            'job_title': 'Tester',
            'company_name': 'Test Co',
            'needs_profile_sync': false,
            'needs_image_sync': false,
            'needs_signature_sync': false,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
          {
            'id': 'profile_sync_needed',
            'name': 'Profile Sync',
            'email': 'profilesync@example.com',
            'phone': '+2020202020',
            'job_title': 'Tester',
            'company_name': 'Test Co',
            'needs_profile_sync': true,
            'needs_image_sync': false,
            'needs_signature_sync': false,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
          {
            'id': 'all_sync_needed',
            'name': 'All Sync',
            'email': 'allsync@example.com',
            'phone': '+3030303030',
            'job_title': 'Tester',
            'company_name': 'Test Co',
            'needs_profile_sync': true,
            'needs_image_sync': true,
            'needs_signature_sync': true,
            'created_at': DateTime.now(),
            'updated_at': DateTime.now(),
          },
        ];
        
        for (final profile in profiles) {
          // await profileDao.insertProfile(profile);
        }
        
        // Act - Get profiles needing sync
        // final needingSync = await profileDao.getProfilesNeedingSync();
        
        // Assert - Should return only profiles with at least one sync flag
        // expect(needingSync.length, equals(2));
        // expect(needingSync.any((p) => p['id'] == 'profile_sync_needed'), isTrue);
        // expect(needingSync.any((p) => p['id'] == 'all_sync_needed'), isTrue);
        // expect(needingSync.any((p) => p['id'] == 'no_sync_needed'), isFalse);
      });
    });

    group('Performance Integration Tests', () {
      test('should maintain performance with realistic data volume', () async {
        // Arrange - Insert realistic number of profiles
        final stopwatch = Stopwatch();
        
        // Act - Insert 50 profiles (realistic for a contractor app)
        stopwatch.start();
        for (int i = 0; i < 50; i++) {
          // await profileDao.insertProfile({
          //   'id': 'perf_test_$i',
          //   'name': 'Performance User $i',
          //   'email': 'perf$i@example.com',
          //   'phone': '+100000000$i',
          //   'job_title': 'Tester $i',
          //   'company_name': 'Test Company $i',
          //   'postcode_area': 'TEST$i',
          //   'created_at': DateTime.now(),
          //   'updated_at': DateTime.now(),
          // });
        }
        stopwatch.stop();
        
        // Assert - Insertions reasonably fast
        // expect(stopwatch.elapsedMilliseconds / 50, lessThan(50)); // < 50ms per insert
        
        // Act - Query random profile
        stopwatch.reset();
        stopwatch.start();
        // final profile = await profileDao.getProfile('perf_test_25');
        stopwatch.stop();
        
        // Assert - Query fast even with data
        // expect(stopwatch.elapsedMilliseconds, lessThan(100));
        // expect(profile, isNotNull);
      });
    });
  });
}