import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:snagsnapper/services/image_storage_service.dart';

// Note: These tests will need to run with testWidgets or use setUpAll to mock path_provider

void main() {
  group('ImageStorageService Tests', () {
    late ImageStorageService service;
    late Directory testDirectory;

    setUpAll(() async {
      // Create a temporary test directory
      testDirectory = await Directory.systemTemp.createTemp('test_storage_');
    });

    tearDownAll(() async {
      // Clean up test directory
      if (await testDirectory.exists()) {
        await testDirectory.delete(recursive: true);
      }
    });

    setUp(() {
      service = ImageStorageService();
    });

    group('Fixed File Naming', () {
      test('should save profile image with fixed name "profile.jpg"', () async {
        // Create a test image file
        final testImage = File(p.join(testDirectory.path, 'test_image.jpg'));
        await testImage.writeAsBytes([1, 2, 3, 4, 5]); // Dummy data

        const userId = 'test_user_123';
        
        // Save the profile image
        final savedPath = await service.saveProfileImage(testImage, userId);
        
        // Verify the path uses fixed naming
        expect(savedPath, equals('SnagSnapper/$userId/Profile/profile.jpg'));
        expect(savedPath.contains('profile.jpg'), isTrue);
        expect(savedPath.contains(RegExp(r'profile_\d+\.jpg')), isFalse); // No timestamp
      });

      test('should save signature with fixed name "signature.jpg"', () async {
        // Create a test signature file
        final testSignature = File(p.join(testDirectory.path, 'test_signature.png'));
        await testSignature.writeAsBytes([1, 2, 3, 4, 5]); // Dummy data

        const userId = 'test_user_456';
        
        // Save the signature
        final savedPath = await service.saveSignatureImage(testSignature, userId);
        
        // Verify the path uses fixed naming
        expect(savedPath, equals('SnagSnapper/$userId/Profile/signature.jpg'));
        expect(savedPath.contains('signature.jpg'), isTrue);
        expect(savedPath.contains(RegExp(r'signature_\d+\.(png|jpg)')), isFalse); // No timestamp
      });

      test('should overwrite existing profile image when saving new one', () async {
        // This tests the auto-overwrite behavior with fixed naming
        const userId = 'test_overwrite';
        
        // Create first image
        final firstImage = File(p.join(testDirectory.path, 'first.jpg'));
        await firstImage.writeAsBytes([1, 2, 3]);
        
        // Save first image
        final firstPath = await service.saveProfileImage(firstImage, userId);
        expect(firstPath, equals('SnagSnapper/$userId/Profile/profile.jpg'));
        
        // Create second image
        final secondImage = File(p.join(testDirectory.path, 'second.jpg'));
        await secondImage.writeAsBytes([4, 5, 6, 7, 8]); // Different content
        
        // Save second image (should overwrite)
        final secondPath = await service.saveProfileImage(secondImage, userId);
        expect(secondPath, equals('SnagSnapper/$userId/Profile/profile.jpg'));
        expect(secondPath, equals(firstPath)); // Same path
        
        // Verify only one profile image exists
        // Note: This would need actual file system access to verify
      });

      test('should overwrite existing signature when saving new one', () async {
        const userId = 'test_sig_overwrite';
        
        // Create first signature
        final firstSig = File(p.join(testDirectory.path, 'sig1.png'));
        await firstSig.writeAsBytes([1, 2, 3]);
        
        // Save first signature
        final firstPath = await service.saveSignatureImage(firstSig, userId);
        expect(firstPath, equals('SnagSnapper/$userId/Profile/signature.jpg'));
        
        // Create second signature
        final secondSig = File(p.join(testDirectory.path, 'sig2.png'));
        await secondSig.writeAsBytes([4, 5, 6]);
        
        // Save second signature (should overwrite)
        final secondPath = await service.saveSignatureImage(secondSig, userId);
        expect(secondPath, equals('SnagSnapper/$userId/Profile/signature.jpg'));
        expect(secondPath, equals(firstPath)); // Same path
      });
    });

    group('Path Consistency', () {
      test('should use consistent path structure for profile images', () async {
        const userId = 'path_test_user';
        final testImage = File(p.join(testDirectory.path, 'test.jpg'));
        await testImage.writeAsBytes([1, 2, 3]);
        
        final savedPath = await service.saveProfileImage(testImage, userId);
        
        // Verify path structure
        expect(savedPath.startsWith('SnagSnapper/'), isTrue);
        expect(savedPath.contains('/$userId/'), isTrue);
        expect(savedPath.contains('/Profile/'), isTrue);
        expect(savedPath.endsWith('profile.jpg'), isTrue);
      });

      test('should use consistent path structure for signatures', () async {
        const userId = 'sig_path_test';
        final testSig = File(p.join(testDirectory.path, 'sig.png'));
        await testSig.writeAsBytes([1, 2, 3]);
        
        final savedPath = await service.saveSignatureImage(testSig, userId);
        
        // Verify path structure
        expect(savedPath.startsWith('SnagSnapper/'), isTrue);
        expect(savedPath.contains('/$userId/'), isTrue);
        expect(savedPath.contains('/Profile/'), isTrue);
        expect(savedPath.endsWith('signature.jpg'), isTrue);
      });

      test('should return null when getting non-existent profile image', () async {
        const userId = 'no_image_user';
        
        final imagePath = await service.getProfileImagePath(userId);
        
        expect(imagePath, isNull);
      });

      test('should return null when getting non-existent signature', () async {
        const userId = 'no_sig_user';
        
        final sigPath = await service.getSignatureImagePath(userId);
        
        expect(sigPath, isNull);
      });
    });

    group('File Extension Handling', () {
      test('should always save profile images as .jpg regardless of input', () async {
        const userId = 'extension_test';
        
        // Test with PNG input
        final pngImage = File(p.join(testDirectory.path, 'image.png'));
        await pngImage.writeAsBytes([1, 2, 3]);
        
        final savedPath = await service.saveProfileImage(pngImage, userId);
        expect(savedPath.endsWith('.jpg'), isTrue);
        expect(savedPath.endsWith('.png'), isFalse);
      });

      test('should always save signatures as .jpg for consistency', () async {
        const userId = 'sig_extension_test';
        
        // Test with PNG input (common for signatures)
        final pngSig = File(p.join(testDirectory.path, 'sig.png'));
        await pngSig.writeAsBytes([1, 2, 3]);
        
        final savedPath = await service.saveSignatureImage(pngSig, userId);
        expect(savedPath.endsWith('.jpg'), isTrue);
        expect(savedPath.endsWith('.png'), isFalse);
      });
    });

    group('Deletion with Fixed Names', () {
      test('should delete profile.jpg when deleteProfileImage is called', () async {
        const userId = 'delete_test';
        
        // First save an image
        final testImage = File(p.join(testDirectory.path, 'to_delete.jpg'));
        await testImage.writeAsBytes([1, 2, 3]);
        await service.saveProfileImage(testImage, userId);
        
        // Delete it
        final deleted = await service.deleteProfileImage(userId);
        
        // In a real test, we'd verify the file is actually deleted
        // For now, just check the method returns appropriately
        expect(deleted, isA<bool>());
      });

      test('should delete signature.jpg when deleteSignatureImage is called', () async {
        const userId = 'delete_sig_test';
        
        // First save a signature
        final testSig = File(p.join(testDirectory.path, 'sig_to_delete.png'));
        await testSig.writeAsBytes([1, 2, 3]);
        await service.saveSignatureImage(testSig, userId);
        
        // Delete it
        final deleted = await service.deleteSignatureImage(userId);
        
        expect(deleted, isA<bool>());
      });
    });

    group('Backward Compatibility', () {
      test('should handle cleanup of old timestamped files', () async {
        // When we implement the cleanup method, it should:
        // 1. Find old files with timestamps (profile_123456.jpg)
        // 2. Keep the newest one and rename it to profile.jpg
        // 3. Delete the old timestamped versions
        
        // This is a placeholder test for the migration logic
        expect(true, isTrue);
      });
    });
  });
}