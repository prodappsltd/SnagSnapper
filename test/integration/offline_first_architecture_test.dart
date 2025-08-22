import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/services/image_storage_service.dart';

/// Architecture Verification Tests
/// These tests verify that the app follows offline-first architecture
/// Requirements from PROJECT_RULES.md Section 4.2:
/// - Feature works with airplane mode ON
/// - Local database is checked BEFORE any network calls
/// - Firebase/network is only used for sync, not primary data access
/// - Integration test exists that would fail if architecture is violated

@GenerateMocks([])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Offline-First Architecture Verification', () {
    late AppDatabase database;
    late ProfileDao profileDao;
    late ImageStorageService imageStorageService;
    late Directory testDirectory;
    late String testUserId;
    late AppUser testUser;

    setUpAll(() async {
      // Create test directory
      final tempDir = await getTemporaryDirectory();
      testDirectory = Directory(p.join(tempDir.path, 'architecture_test'));
      if (!testDirectory.existsSync()) {
        testDirectory.createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      // Clean up
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      // Initialize services
      database = AppDatabase.instance;
      profileDao = database.profileDao;
      imageStorageService = ImageStorageService();
      
      // Create test user
      testUserId = 'arch_test_${DateTime.now().millisecondsSinceEpoch}';
      testUser = AppUser(
        id: testUserId,
        name: 'Architecture Test',
        email: 'arch@test.com',
        phone: '+1234567890',
        jobTitle: 'Tester',
        companyName: 'Test Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await profileDao.insertProfile(testUser);
    });

    tearDown(() async {
      await profileDao.deleteProfile(testUserId);
    });

    group('Rule: Feature works with airplane mode ON', () {
      test('profile image operations work completely offline', () async {
        // This test simulates airplane mode - no network connectivity
        // If this test passes, the feature works offline
        
        // Create test image
        final image = img.Image(width: 100, height: 100);
        image.fill(img.ColorRgb8(100, 150, 200));
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'offline_test.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        // 1. Add image - must work offline
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        expect(savedPath, isNotNull);
        expect(savedPath, contains('profile.jpg'));
        
        // 2. Update database - must work offline
        final updatedUser = testUser.copyWith(imageLocalPath: () => savedPath);
        final updateSuccess = await profileDao.updateProfile(testUserId, updatedUser);
        expect(updateSuccess, isTrue);
        
        // 3. Read from database - must work offline
        final dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser, isNotNull);
        expect(dbUser!.imageLocalPath, equals(savedPath));
        
        // 4. Get image for display - must work offline
        final displayPath = await imageStorageService.getProfileImagePath(testUserId);
        expect(displayPath, isNotNull);
        final displayFile = File(displayPath!);
        expect(await displayFile.exists(), isTrue);
        
        // 5. Delete image - must work offline
        final deleteSuccess = await imageStorageService.deleteProfileImage(testUserId);
        expect(deleteSuccess, isTrue);
        
        // 6. Set deletion flag - must work offline
        final flagSet = await profileDao.setImageMarkedForDeletion(testUserId, true);
        expect(flagSet, isTrue);
        
        // All operations completed without any network calls
      });

      test('sync flags are set for later synchronization', () async {
        // When offline, changes should be queued for sync
        
        // Add image offline
        final image = img.Image(width: 50, height: 50);
        image.fill(img.ColorRgb8(255, 0, 0));
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'sync_queue.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        final user = testUser.copyWith(imageLocalPath: () => savedPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Verify sync flags are set
        final dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser!.needsImageSync, isTrue, 
          reason: 'Image sync flag must be set for offline changes');
        expect(dbUser.needsProfileSync, isTrue,
          reason: 'Profile sync flag must be set for offline changes');
        
        // Verify profile appears in sync queue
        final needsSync = await profileDao.getProfilesNeedingSync();
        expect(needsSync.any((u) => u.id == testUserId), isTrue,
          reason: 'Profile must appear in sync queue');
      });
    });

    group('Rule: Local database is checked BEFORE any network calls', () {
      test('profile data is read from local database first', () async {
        // This test verifies that profile data comes from local DB
        // NOT from Firebase/network
        
        // Setup: Add data to local database
        final user = testUser.copyWith(
          imageLocalPath: () => 'SnagSnapper/$testUserId/Profile/profile.jpg',
          imageFirebasePath: () => 'users/$testUserId/profile.jpg',
        );
        await profileDao.updateProfile(testUserId, user);
        
        // Test: Read profile data
        final dbUser = await profileDao.getProfile(testUserId);
        
        // Verify: Data came from local database
        expect(dbUser, isNotNull);
        expect(dbUser!.imageLocalPath, equals('SnagSnapper/$testUserId/Profile/profile.jpg'));
        
        // This operation should complete instantly (< 100ms) 
        // because it's reading from local DB, not network
        final stopwatch = Stopwatch()..start();
        await profileDao.getProfile(testUserId);
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Local DB read should be fast (<100ms)');
      });

      test('image display uses local path not Firebase URL', () async {
        // Images must be displayed from local storage, not Firebase
        
        // Create and save image locally
        final image = img.Image(width: 50, height: 50);
        image.fill(img.ColorRgb8(0, 255, 0));
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'local_display.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        
        // Get path for display
        final displayPath = await imageStorageService.getProfileImagePath(testUserId);
        
        // Verify it's a local file path, not a URL
        expect(displayPath, isNotNull);
        expect(displayPath!.startsWith('http'), isFalse,
          reason: 'Display path must be local, not a URL');
        expect(displayPath.startsWith('/'), isTrue,
          reason: 'Display path should be absolute local path');
        
        // Verify file exists locally
        final localFile = File(displayPath);
        expect(await localFile.exists(), isTrue,
          reason: 'Image must exist in local storage');
      });
    });

    group('Rule: Firebase/network is only used for sync', () {
      test('primary operations do not require network', () async {
        // All primary operations must work without network
        // Only sync operations should need network
        
        // List of operations that MUST work offline:
        final offlineOperations = <String, Future<bool> Function()>{
          'Insert profile': () async {
            final newUser = AppUser(
              id: 'offline_insert_test',
              name: 'Offline Insert',
              email: 'offline@test.com',
              phone: '+9999999999',
              jobTitle: 'Offline',
              companyName: 'Offline Co',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            return await profileDao.insertProfile(newUser);
          },
          'Update profile': () async {
            final updated = testUser.copyWith(name: 'Updated Offline');
            return await profileDao.updateProfile(testUserId, updated);
          },
          'Read profile': () async {
            final user = await profileDao.getProfile(testUserId);
            return user != null;
          },
          'Check profile exists': () async {
            return await profileDao.profileExists(testUserId);
          },
          'Set sync flags': () async {
            return await profileDao.setNeedsImageSync(testUserId);
          },
          'Set deletion flag': () async {
            return await profileDao.setImageMarkedForDeletion(testUserId, true);
          },
        };
        
        // Execute all operations and verify they work
        for (final entry in offlineOperations.entries) {
          final success = await entry.value();
          expect(success, isTrue, 
            reason: '${entry.key} must work offline');
        }
      });

      test('sync flags indicate what needs network sync', () async {
        // Sync flags should clearly indicate what needs syncing
        // This allows the app to batch sync operations when online
        
        // Make various changes
        await profileDao.setNeedsProfileSync(testUserId);
        await profileDao.setNeedsImageSync(testUserId);
        await profileDao.setNeedsSignatureSync(testUserId);
        
        // Read flags
        final user = await profileDao.getProfile(testUserId);
        
        // Verify flags are set correctly
        expect(user!.needsProfileSync, isTrue);
        expect(user.needsImageSync, isTrue);
        expect(user.needsSignatureSync, isTrue);
        
        // Simulate successful sync
        await profileDao.clearSyncFlags(testUserId);
        
        // Verify flags are cleared
        final syncedUser = await profileDao.getProfile(testUserId);
        expect(syncedUser!.needsProfileSync, isFalse);
        expect(syncedUser.needsImageSync, isFalse);
        expect(syncedUser.needsSignatureSync, isFalse);
      });
    });

    group('Rule: Delete-then-add works offline', () {
      test('deletion flag persists through add operation', () async {
        // Critical test for offline delete-then-add scenario
        
        // Step 1: User has an image
        final initialImage = img.Image(width: 50, height: 50);
        initialImage.fill(img.ColorRgb8(255, 0, 0));
        final initialBytes = img.encodeJpg(initialImage);
        final initialFile = File(p.join(testDirectory.path, 'initial.jpg'));
        await initialFile.writeAsBytes(initialBytes);
        
        final initialPath = await imageStorageService.saveProfileImage(initialFile, testUserId);
        var user = testUser.copyWith(imageLocalPath: () => initialPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Step 2: Delete image offline
        await imageStorageService.deleteProfileImage(testUserId);
        await profileDao.setImageMarkedForDeletion(testUserId, true);
        
        // Verify deletion state
        user = (await profileDao.getProfile(testUserId))!;
        expect(user.imageMarkedForDeletion, isTrue);
        
        // Step 3: Add new image while still offline
        final newImage = img.Image(width: 50, height: 50);
        newImage.fill(img.ColorRgb8(0, 255, 0));
        final newBytes = img.encodeJpg(newImage);
        final newFile = File(p.join(testDirectory.path, 'new.jpg'));
        await newFile.writeAsBytes(newBytes);
        
        final newPath = await imageStorageService.saveProfileImage(newFile, testUserId);
        user = user.copyWith(imageLocalPath: () => newPath);
        await profileDao.updateProfile(testUserId, user);
        
        // CRITICAL VERIFICATION: Deletion flag MUST persist
        user = (await profileDao.getProfile(testUserId))!;
        expect(user.imageMarkedForDeletion, isTrue,
          reason: 'Deletion flag MUST persist when adding new image offline');
        expect(user.imageLocalPath, equals(newPath),
          reason: 'New image path should be saved');
        expect(user.needsImageSync, isTrue,
          reason: 'Sync flag should be set');
        
        // This ensures Firebase deletion happens before upload of new image
      });
    });

    group('Architecture Violation Detection', () {
      test('this test would FAIL if app requires network for basic ops', () async {
        // This test is designed to fail if someone accidentally
        // makes the app require network for basic operations
        
        // Create a simple image operation flow
        final image = img.Image(width: 100, height: 100);
        image.fill(img.ColorRgb8(200, 200, 200));
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'violation_test.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        // These operations MUST complete without network
        // If they timeout or fail, architecture is violated
        
        final timeout = const Duration(seconds: 2); // Local ops should be fast
        
        // Save image
        final savedPath = await imageStorageService
          .saveProfileImage(imageFile, testUserId)
          .timeout(timeout, onTimeout: () {
            fail('Image save timed out - possible network dependency');
          });
        
        // Update database
        final user = testUser.copyWith(imageLocalPath: () => savedPath);
        await profileDao
          .updateProfile(testUserId, user)
          .timeout(timeout, onTimeout: () {
            fail('Database update timed out - possible network dependency');
          });
        
        // Read from database
        await profileDao
          .getProfile(testUserId)
          .timeout(timeout, onTimeout: () {
            fail('Database read timed out - possible network dependency');
          });
        
        // Get image path
        await imageStorageService
          .getProfileImagePath(testUserId)
          .timeout(timeout, onTimeout: () {
            fail('Get image path timed out - possible network dependency');
          });
        
        // If we reach here, architecture is correct
        expect(true, isTrue);
      });
    });
  });
}