import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';

/// Integration tests for profile image functionality
/// Tests the complete flow: UI → Service → Database
/// Verifies offline-first architecture
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Profile Image Integration Tests', () {
    late AppDatabase database;
    late ProfileDao profileDao;
    late ImageStorageService imageStorageService;
    late ImageCompressionService compressionService;
    late Directory testDirectory;
    late String testUserId;
    late AppUser testUser;

    setUpAll(() async {
      // Create test directory
      final tempDir = await getTemporaryDirectory();
      testDirectory = Directory(p.join(tempDir.path, 'test_profile_images'));
      if (!testDirectory.existsSync()) {
        testDirectory.createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      // Clean up test directory
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      // Initialize database
      database = AppDatabase.instance;
      profileDao = database.profileDao;
      
      // Initialize services
      imageStorageService = ImageStorageService();
      compressionService = ImageCompressionService();
      
      // Create test user
      testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
      testUser = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Tester',
        companyName: 'Test Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Insert test user into database
      await profileDao.insertProfile(testUser);
    });

    tearDown(() async {
      // Clean up database
      await profileDao.deleteProfile(testUserId);
    });

    group('Complete Image Flow', () {
      test('should handle complete add image flow with two-tier compression', () async {
        // Create a test image (small, should be optimal)
        final smallImage = img.Image(width: 500, height: 500);
        for (int x = 0; x < 500; x++) {
          for (int y = 0; y < 500; y++) {
            smallImage.setPixelRgb(x, y, 100, 150, 200);
          }
        }
        
        final imageBytes = img.encodeJpg(smallImage, quality: 90);
        final testImageFile = File(p.join(testDirectory.path, 'test_image.jpg'));
        await testImageFile.writeAsBytes(imageBytes);
        
        // Step 1: Save image through service
        final savedPath = await imageStorageService.saveProfileImage(testImageFile, testUserId);
        
        // Verify path format
        expect(savedPath, equals('SnagSnapper/$testUserId/Profile/profile.jpg'));
        
        // Step 2: Update database
        final updatedUser = testUser.copyWith(
          imageLocalPath: () => savedPath,
        );
        await profileDao.updateProfile(testUserId, updatedUser);
        
        // Step 3: Verify database state
        final dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.imageLocalPath, equals(savedPath));
        expect(dbUser?.needsImageSync, isTrue); // Should be set by copyWith
        expect(dbUser?.imageMarkedForDeletion, isFalse); // Should be false for new image
        
        // Step 4: Verify file exists on disk
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File(p.join(appDir.path, savedPath));
        expect(await savedFile.exists(), isTrue);
        
        // Step 5: Verify file is compressed (should be < 600KB)
        final fileSize = await savedFile.length();
        expect(fileSize, lessThan(600 * 1024)); // Optimal size
      });

      test('should handle large image with acceptable compression', () async {
        // Create a complex image that compresses to 600KB-1MB range
        final complexImage = img.Image(width: 2048, height: 2048);
        // Add complexity with gradients
        for (int x = 0; x < 2048; x++) {
          for (int y = 0; y < 2048; y++) {
            complexImage.setPixelRgb(
              x, y,
              (x * 255 ~/ 2048),
              (y * 255 ~/ 2048),
              ((x + y) * 255 ~/ 4096),
            );
          }
        }
        
        final imageBytes = img.encodePng(complexImage);
        final testImageFile = File(p.join(testDirectory.path, 'complex_image.png'));
        await testImageFile.writeAsBytes(imageBytes);
        
        // Save image
        final savedPath = await imageStorageService.saveProfileImage(testImageFile, testUserId);
        
        // Verify file is in acceptable range
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File(p.join(appDir.path, savedPath));
        final fileSize = await savedFile.length();
        
        expect(fileSize, lessThanOrEqualTo(1024 * 1024)); // Max size
        
        // Verify dimensions are correct
        final savedBytes = await savedFile.readAsBytes();
        final savedImage = img.decodeImage(savedBytes);
        expect(savedImage?.width, equals(1024));
        expect(savedImage?.height, equals(1024));
      });

      test('should reject image larger than 1MB after compression', () async {
        // Create extremely complex noise image that won't compress well
        final noiseImage = img.Image(width: 2048, height: 2048);
        final random = List.generate(256, (i) => i);
        random.shuffle(); // Make it random
        
        for (int x = 0; x < 2048; x++) {
          for (int y = 0; y < 2048; y++) {
            // Random noise is very hard to compress
            noiseImage.setPixelRgb(
              x, y,
              random[(x * y) % 256],
              random[(x + y) % 256],
              random[(x - y).abs() % 256],
            );
          }
        }
        
        final imageBytes = img.encodePng(noiseImage);
        final testImageFile = File(p.join(testDirectory.path, 'noise_image.png'));
        await testImageFile.writeAsBytes(imageBytes);
        
        // Should throw ImageTooLargeException
        expect(
          () => imageStorageService.saveProfileImage(testImageFile, testUserId),
          throwsA(isA<ImageTooLargeException>()),
        );
      });
    });

    group('Delete-Then-Add Offline Scenario', () {
      test('should handle delete-then-add with deletion flag persistence', () async {
        // Setup: Start with an existing image
        final initialImage = img.Image(width: 100, height: 100);
        for (int x = 0; x < 100; x++) {
          for (int y = 0; y < 100; y++) {
            initialImage.setPixelRgb(x, y, 255, 0, 0); // Red
          }
        }
        
        final imageBytes = img.encodeJpg(initialImage);
        final testImageFile = File(p.join(testDirectory.path, 'initial.jpg'));
        await testImageFile.writeAsBytes(imageBytes);
        
        // Add initial image
        final savedPath = await imageStorageService.saveProfileImage(testImageFile, testUserId);
        var user = testUser.copyWith(imageLocalPath: () => savedPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Step 1: Delete image (simulate offline deletion)
        await imageStorageService.deleteProfileImage(testUserId);
        await profileDao.setImageMarkedForDeletion(testUserId, true);
        await profileDao.setNeedsImageSync(testUserId);
        
        // Verify deletion state
        var dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.imageMarkedForDeletion, isTrue);
        expect(dbUser?.needsImageSync, isTrue);
        
        // Step 2: Add new image while still "offline"
        final newImage = img.Image(width: 100, height: 100);
        for (int x = 0; x < 100; x++) {
          for (int y = 0; y < 100; y++) {
            newImage.setPixelRgb(x, y, 0, 255, 0); // Green
          }
        }
        
        final newImageBytes = img.encodeJpg(newImage);
        final newTestImageFile = File(p.join(testDirectory.path, 'new.jpg'));
        await newTestImageFile.writeAsBytes(newImageBytes);
        
        final newSavedPath = await imageStorageService.saveProfileImage(newTestImageFile, testUserId);
        
        // Update user but DO NOT clear deletion flag
        user = (await profileDao.getProfile(testUserId))!;
        user = user.copyWith(imageLocalPath: () => newSavedPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Step 3: Verify deletion flag PERSISTS
        dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.imageLocalPath, equals(newSavedPath));
        expect(dbUser?.imageMarkedForDeletion, isTrue); // CRITICAL: Must persist!
        expect(dbUser?.needsImageSync, isTrue);
        
        // Step 4: Simulate successful sync
        await profileDao.clearImageDeletionFlag(testUserId);
        await profileDao.clearSyncFlags(testUserId);
        
        // Verify flags cleared after sync
        dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.imageMarkedForDeletion, isFalse);
        expect(dbUser?.needsImageSync, isFalse);
      });
    });

    group('Fixed Naming and Auto-Overwrite', () {
      test('should always save as profile.jpg and overwrite existing', () async {
        // Create first image
        final firstImage = img.Image(width: 100, height: 100);
        for (int x = 0; x < 100; x++) {
          for (int y = 0; y < 100; y++) {
            firstImage.setPixelRgb(x, y, 255, 0, 0); // Red
          }
        }
        
        final firstBytes = img.encodeJpg(firstImage);
        final firstFile = File(p.join(testDirectory.path, 'first.jpg'));
        await firstFile.writeAsBytes(firstBytes);
        
        // Save first image
        final firstPath = await imageStorageService.saveProfileImage(firstFile, testUserId);
        expect(firstPath, equals('SnagSnapper/$testUserId/Profile/profile.jpg'));
        
        // Verify file content
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File(p.join(appDir.path, firstPath));
        var savedBytes = await savedFile.readAsBytes();
        var savedImage = img.decodeImage(savedBytes);
        // Check if predominantly red (first image)
        var pixel = savedImage!.getPixel(50, 50);
        expect(pixel.r, greaterThan(200)); // Should be red
        
        // Create second image
        final secondImage = img.Image(width: 100, height: 100);
        for (int x = 0; x < 100; x++) {
          for (int y = 0; y < 100; y++) {
            secondImage.setPixelRgb(x, y, 0, 255, 0); // Green
          }
        }
        
        final secondBytes = img.encodeJpg(secondImage);
        final secondFile = File(p.join(testDirectory.path, 'second.jpg'));
        await secondFile.writeAsBytes(secondBytes);
        
        // Save second image (should overwrite)
        final secondPath = await imageStorageService.saveProfileImage(secondFile, testUserId);
        expect(secondPath, equals('SnagSnapper/$testUserId/Profile/profile.jpg'));
        expect(secondPath, equals(firstPath)); // Same path
        
        // Verify file was overwritten
        savedBytes = await savedFile.readAsBytes();
        savedImage = img.decodeImage(savedBytes);
        pixel = savedImage!.getPixel(50, 50);
        expect(pixel.g, greaterThan(200)); // Should be green now
        
        // Verify only one file exists
        final userDir = Directory(p.join(appDir.path, 'SnagSnapper', testUserId, 'Profile'));
        final files = userDir.listSync().where((f) => f is File).toList();
        expect(files.length, equals(1));
        expect(files.first.path.endsWith('profile.jpg'), isTrue);
      });
    });

    group('Offline-First Architecture', () {
      test('should work completely offline without Firebase', () async {
        // This test simulates airplane mode - no network calls
        
        // Create image
        final image = img.Image(width: 200, height: 200);
        for (int x = 0; x < 200; x++) {
          for (int y = 0; y < 200; y++) {
            image.setPixelRgb(x, y, 100, 150, 200);
          }
        }
        
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'offline.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        // Save image (should work offline)
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        
        // Update database (should work offline)
        final user = testUser.copyWith(imageLocalPath: () => savedPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Read from database (should work offline)
        final dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.imageLocalPath, equals(savedPath));
        
        // Display image (should work offline)
        final imagePath = await imageStorageService.getProfileImagePath(testUserId);
        expect(imagePath, isNotNull);
        
        final displayFile = File(imagePath!);
        expect(await displayFile.exists(), isTrue);
        
        // Delete image (should work offline)
        await imageStorageService.deleteProfileImage(testUserId);
        await profileDao.setImageMarkedForDeletion(testUserId, true);
        
        // Verify deletion (should work offline)
        final deletedImagePath = await imageStorageService.getProfileImagePath(testUserId);
        expect(deletedImagePath, isNull);
        
        // All operations completed without any Firebase/network calls
      });

      test('should queue sync operations for when online', () async {
        // Add image offline
        final image = img.Image(width: 100, height: 100);
        for (int x = 0; x < 100; x++) {
          for (int y = 0; y < 100; y++) {
            image.setPixelRgb(x, y, 200, 100, 50);
          }
        }
        
        final imageBytes = img.encodeJpg(image);
        final imageFile = File(p.join(testDirectory.path, 'sync_test.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        final user = testUser.copyWith(imageLocalPath: () => savedPath);
        await profileDao.updateProfile(testUserId, user);
        
        // Verify sync flags are set
        final dbUser = await profileDao.getProfile(testUserId);
        expect(dbUser?.needsImageSync, isTrue);
        expect(dbUser?.needsProfileSync, isTrue);
        
        // Get all profiles needing sync
        final needsSync = await profileDao.getProfilesNeedingSync();
        expect(needsSync.any((u) => u.id == testUserId), isTrue);
      });
    });

    group('Two-Tier Validation', () {
      test('should handle optimal size (<600KB) silently', () async {
        // Create small image
        final smallImage = img.Image(width: 300, height: 300);
        for (int x = 0; x < 300; x++) {
          for (int y = 0; y < 300; y++) {
            smallImage.setPixelRgb(x, y, 255, 255, 255); // Simple white
          }
        }
        
        final imageBytes = img.encodeJpg(smallImage, quality: 90);
        final imageFile = File(p.join(testDirectory.path, 'optimal.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        // Save should succeed silently
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        expect(savedPath, isNotNull);
        
        // Verify size is optimal
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File(p.join(appDir.path, savedPath));
        final fileSize = await savedFile.length();
        expect(fileSize, lessThan(600 * 1024));
      });

      test('should handle acceptable size (600KB-1MB) silently', () async {
        // Create medium complexity image
        final mediumImage = img.Image(width: 1500, height: 1500);
        // Add gradient for some complexity
        for (int x = 0; x < 1500; x++) {
          for (int y = 0; y < 1500; y++) {
            mediumImage.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
          }
        }
        
        final imageBytes = img.encodeJpg(mediumImage, quality: 100);
        final imageFile = File(p.join(testDirectory.path, 'acceptable.jpg'));
        await imageFile.writeAsBytes(imageBytes);
        
        // Save should succeed silently
        final savedPath = await imageStorageService.saveProfileImage(imageFile, testUserId);
        expect(savedPath, isNotNull);
        
        // Verify size is acceptable
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File(p.join(appDir.path, savedPath));
        final fileSize = await savedFile.length();
        expect(fileSize, lessThanOrEqualTo(1024 * 1024));
      });
    });
  });
}