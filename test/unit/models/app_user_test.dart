import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Data/models/app_user.dart';

/// Unit tests for AppUser model
/// Tests model creation, validation, and serialization
void main() {
  group('AppUser Model Tests', () {
    group('Model Creation', () {
      test('should create AppUser with all required fields', () {
        // Arrange
        final now = DateTime.now();
        const userId = 'test_user_123';
        
        // Act
        final user = AppUser(
          id: userId,
          name: 'John Doe',
          email: 'john@example.com',
          phone: '+1234567890',
          jobTitle: 'Site Manager',
          companyName: 'Construction Co',
          postcodeOrArea: 'SW1A 1AA',
          dateFormat: 'dd-MM-yyyy',
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert
        expect(user.id, equals(userId));
        expect(user.name, equals('John Doe'));
        expect(user.email, equals('john@example.com'));
        expect(user.phone, equals('+1234567890'));
        expect(user.jobTitle, equals('Site Manager'));
        expect(user.companyName, equals('Construction Co'));
        expect(user.postcodeOrArea, equals('SW1A 1AA'));
        expect(user.dateFormat, equals('dd-MM-yyyy'));
        expect(user.needsProfileSync, isFalse);
        expect(user.needsImageSync, isFalse);
        expect(user.needsSignatureSync, isFalse);
      });

      test('should create AppUser with minimal required fields', () {
        // Arrange
        final now = DateTime.now();
        
        // Act
        final user = AppUser(
          id: 'user_456',
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+9876543210',
          jobTitle: 'Inspector',
          companyName: 'Inspection Ltd',
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert - optional fields should have defaults or null
        expect(user.postcodeOrArea, isNull);
        expect(user.dateFormat, equals('dd-MM-yyyy')); // default value
        expect(user.imageLocalPath, isNull);
        expect(user.signatureLocalPath, isNull);
        expect(user.currentDeviceId, isNull);
        expect(user.needsProfileSync, isFalse);
        expect(user.needsImageSync, isFalse);
        expect(user.needsSignatureSync, isFalse);
      });

      test('should create AppUser from database map', () {
        // Arrange
        final dbMap = {
          'id': 'user_789',
          'name': 'Bob Builder',
          'email': 'bob@construction.com',
          'phone': '+4412345678',
          'job_title': 'Contractor',
          'company_name': 'Bob Builds',
          'postcode_area': 'E1 6AN',
          'date_format': 'MM-dd-yyyy',
          'image_local_path': 'SnagSnapper/user_789/Profile/profile.jpg',
          'image_firebase_path': 'users/user_789/profile.jpg',
          'signature_local_path': 'SnagSnapper/user_789/Profile/signature.jpg',
          'signature_firebase_path': null,
          'image_marked_for_deletion': 0,
          'signature_marked_for_deletion': 0,
          'needs_profile_sync': 1, // SQLite bool as int
          'needs_image_sync': 0,
          'needs_signature_sync': 1,
          'last_sync_time': 1704067200000, // 2024-01-01 timestamp
          'current_device_id': 'device_abc123',
          'last_login_time': 1704153600000,
          'created_at': 1704067200000,
          'updated_at': 1704153600000,
          'local_version': 2,
          'firebase_version': 1,
        };
        
        // Act
        final user = AppUser.fromDatabase(dbMap);
        
        // Assert
        expect(user.id, equals('user_789'));
        expect(user.name, equals('Bob Builder'));
        expect(user.email, equals('bob@construction.com'));
        expect(user.phone, equals('+4412345678'));
        expect(user.jobTitle, equals('Contractor'));
        expect(user.companyName, equals('Bob Builds'));
        expect(user.postcodeOrArea, equals('E1 6AN'));
        expect(user.dateFormat, equals('MM-dd-yyyy'));
        expect(user.needsProfileSync, isTrue);
        expect(user.needsImageSync, isFalse);
        expect(user.needsSignatureSync, isTrue);
        expect(user.imageLocalPath, equals('SnagSnapper/user_789/Profile/profile.jpg'));
        expect(user.currentDeviceId, equals('device_abc123'));
        expect(user.localVersion, equals(2));
        expect(user.firebaseVersion, equals(1));
      });

      test('should handle null optional fields from database', () {
        // Arrange
        final dbMap = {
          'id': 'user_minimal',
          'name': 'Min User',
          'email': 'min@example.com',
          'phone': '+1234567',
          'job_title': 'Worker',
          'company_name': 'Min Co',
          'postcode_area': null,
          'date_format': 'dd-MM-yyyy',
          'image_local_path': null,
          'image_firebase_path': null,
          'signature_local_path': null,
          'signature_firebase_path': null,
          'image_marked_for_deletion': 0,
          'signature_marked_for_deletion': 0,
          'needs_profile_sync': 0,
          'needs_image_sync': 0,
          'needs_signature_sync': 0,
          'last_sync_time': null,
          'current_device_id': null,
          'last_login_time': null,
          'created_at': 1704067200000,
          'updated_at': 1704067200000,
          'local_version': 1,
          'firebase_version': 0,
        };
        
        // Act
        final user = AppUser.fromDatabase(dbMap);
        
        // Assert
        expect(user.postcodeOrArea, isNull);
        expect(user.imageLocalPath, isNull);
        expect(user.signatureLocalPath, isNull);
        expect(user.lastSyncTime, isNull);
        expect(user.currentDeviceId, isNull);
        expect(user.lastLoginTime, isNull);
      });
    });

    group('Model Serialization', () {
      test('should convert AppUser to database map', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'user_serialize',
          name: 'Serialize Test',
          email: 'serialize@test.com',
          phone: '+9999999999',
          jobTitle: 'Tester',
          companyName: 'Test Corp',
          postcodeOrArea: 'TEST 123',
          dateFormat: 'yyyy-MM-dd',
          imageLocalPath: 'SnagSnapper/user_serialize/Profile/profile.jpg',
          needsProfileSync: true,
          needsImageSync: false,
          currentDeviceId: 'test_device',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final dbMap = user.toDatabase();
        
        // Assert
        expect(dbMap['id'], equals('user_serialize'));
        expect(dbMap['name'], equals('Serialize Test'));
        expect(dbMap['email'], equals('serialize@test.com'));
        expect(dbMap['phone'], equals('+9999999999'));
        expect(dbMap['job_title'], equals('Tester'));
        expect(dbMap['company_name'], equals('Test Corp'));
        expect(dbMap['postcode_area'], equals('TEST 123'));
        expect(dbMap['date_format'], equals('yyyy-MM-dd'));
        expect(dbMap['needs_profile_sync'], equals(1)); // bool to int
        expect(dbMap['needs_image_sync'], equals(0));
        expect(dbMap['image_local_path'], equals('SnagSnapper/user_serialize/Profile/profile.jpg'));
        expect(dbMap['current_device_id'], equals('test_device'));
        expect(dbMap['created_at'], equals(now.millisecondsSinceEpoch));
        expect(dbMap['updated_at'], equals(now.millisecondsSinceEpoch));
      });

      test('should preserve timestamps in serialization', () {
        // Arrange
        final createdAt = DateTime(2024, 1, 1, 12, 0, 0);
        final updatedAt = DateTime(2024, 1, 2, 15, 30, 0);
        final user = AppUser(
          id: 'timestamp_test',
          name: 'Time User',
          email: 'time@test.com',
          phone: '+1111111111',
          jobTitle: 'Timer',
          companyName: 'Time Co',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        
        // Act
        final dbMap = user.toDatabase();
        
        // Assert
        expect(dbMap['created_at'], equals(createdAt.millisecondsSinceEpoch));
        expect(dbMap['updated_at'], equals(updatedAt.millisecondsSinceEpoch));
      });
    });

    group('Field Validation', () {
      test('should validate required fields are not empty', () {
        // Test that model validation catches empty required fields
        
        // Act & Assert
        expect(() => AppUser.validate(name: ''), throwsArgumentError);
        expect(() => AppUser.validate(email: ''), throwsArgumentError);
        expect(() => AppUser.validate(phone: ''), throwsArgumentError);
        expect(() => AppUser.validate(companyName: ''), throwsArgumentError);
      });

      test('should validate name length constraints', () {
        // Name should be 2-50 characters
        
        // Act & Assert
        expect(() => AppUser.validate(name: 'A'), throwsArgumentError); // Too short
        expect(() => AppUser.validate(name: 'A' * 51), throwsArgumentError); // Too long
        AppUser.validate(name: 'Jo'); // Valid min - should not throw
        AppUser.validate(name: 'A' * 50); // Valid max - should not throw
      });

      test('should validate email format', () {
        // Act & Assert
        expect(() => AppUser.validate(email: 'invalid'), throwsArgumentError);
        expect(() => AppUser.validate(email: 'no@domain'), throwsArgumentError);
        expect(() => AppUser.validate(email: '@example.com'), throwsArgumentError);
        AppUser.validate(email: 'valid@example.com'); // Should not throw
      });

      test('should validate phone number format', () {
        // Phone should be 7-15 digits, optional +
        
        // Act & Assert
        expect(() => AppUser.validate(phone: '12345'), throwsArgumentError); // Too short
        expect(() => AppUser.validate(phone: '1234567890123456'), throwsArgumentError); // Too long
        expect(() => AppUser.validate(phone: 'abc123'), throwsArgumentError); // Invalid chars
        AppUser.validate(phone: '1234567'); // Valid min - should not throw
        AppUser.validate(phone: '+123456789012345'); // Valid with + - should not throw
      });

      test('should validate image paths are relative not absolute', () {
        // Paths must be relative for cross-platform compatibility
        
        // Act & Assert
        expect(() => AppUser.validate(
          imageLocalPath: '/Users/john/SnagSnapper/profile.jpg'
        ), throwsArgumentError); // Absolute path
        
        expect(() => AppUser.validate(
          imageLocalPath: 'C:\\Users\\john\\SnagSnapper\\profile.jpg'
        ), throwsArgumentError); // Windows absolute
        
        AppUser.validate(
          imageLocalPath: 'SnagSnapper/user123/Profile/profile.jpg'
        ); // Relative path - should not throw
      });

      test('should validate date format options', () {
        // Only specific date formats allowed
        
        // Act & Assert
        expect(() => AppUser.validate(dateFormat: 'invalid'), throwsArgumentError);
        AppUser.validate(dateFormat: 'dd-MM-yyyy'); // Should not throw
        AppUser.validate(dateFormat: 'MM-dd-yyyy'); // Should not throw
        AppUser.validate(dateFormat: 'yyyy-MM-dd'); // Should not throw
      });
    });

    group('Sync Flag Management', () {
      test('should set needsProfileSync when profile data changes', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'sync_test',
          name: 'Original Name',
          email: 'original@test.com',
          phone: '+1234567890',
          jobTitle: 'Original Job',
          companyName: 'Original Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final updatedUser = user.copyWith(name: 'New Name');
        
        // Assert
        expect(updatedUser.needsProfileSync, isTrue);
        expect(updatedUser.name, equals('New Name'));
      });

      test('should set needsImageSync when image path changes', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'image_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final updatedUser = user.copyWith(
          imageLocalPath: () => 'SnagSnapper/user/Profile/new_profile.jpg'
        );
        
        // Assert
        expect(updatedUser.needsImageSync, isTrue);
        expect(updatedUser.imageLocalPath, contains('new_profile.jpg'));
      });

      test('should set needsSignatureSync when signature path changes', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'sig_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final updatedUser = user.copyWith(
          signatureLocalPath: () => 'SnagSnapper/user/Profile/signature.jpg'
        );
        
        // Assert
        expect(updatedUser.needsSignatureSync, isTrue);
      });

      test('should preserve sync flags through serialization', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'preserve_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          needsProfileSync: true,
          needsImageSync: false,
          needsSignatureSync: true,
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final dbMap = user.toDatabase();
        final restoredUser = AppUser.fromDatabase(dbMap);
        
        // Assert
        expect(restoredUser.needsProfileSync, isTrue);
        expect(restoredUser.needsImageSync, isFalse);
        expect(restoredUser.needsSignatureSync, isTrue);
      });

      test('should clear sync flags after successful sync', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'clear_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          needsProfileSync: true,
          needsImageSync: true,
          needsSignatureSync: true,
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final syncedUser = user.clearSyncFlags();
        
        // Assert
        expect(syncedUser.needsProfileSync, isFalse);
        expect(syncedUser.needsImageSync, isFalse);
        expect(syncedUser.needsSignatureSync, isFalse);
        expect(syncedUser.lastSyncTime, isNotNull);
      });
    });

    group('CopyWith Functionality', () {
      test('should create copy with updated fields', () {
        // Arrange
        final now = DateTime.now();
        final original = AppUser(
          id: 'copy_test',
          name: 'Original Name',
          email: 'original@test.com',
          phone: '+1234567890',
          jobTitle: 'Original Job',
          companyName: 'Original Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final copy = original.copyWith(
          name: 'Updated Name',
          jobTitle: 'Updated Job',
        );
        
        // Assert
        expect(copy.id, equals(original.id)); // Unchanged
        expect(copy.email, equals(original.email)); // Unchanged
        expect(copy.name, equals('Updated Name')); // Changed
        expect(copy.jobTitle, equals('Updated Job')); // Changed
        expect(copy.updatedAt.isAfter(original.updatedAt), isTrue);
        expect(copy.needsProfileSync, isTrue); // Auto-set because data changed
      });

      test('should preserve null values in copyWith', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'preserve_null',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          postcodeOrArea: null, // Null optional field
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final copy = user.copyWith(name: 'New Name');
        
        // Assert
        // If original had null postcodeOrArea, copy should too
        expect(copy.postcodeOrArea, equals(user.postcodeOrArea));
      });
    });

    group('Device Management', () {
      test('should store and retrieve device ID', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'device_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          currentDeviceId: 'device_xyz789',
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert
        expect(user.currentDeviceId, equals('device_xyz789'));
      });

      test('should update last login time', () {
        // Arrange
        final now = DateTime.now();
        final loginTime = DateTime.now().add(const Duration(hours: 1));
        final user = AppUser(
          id: 'login_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final loggedInUser = user.copyWith(
          lastLoginTime: () => loginTime,
        );
        
        // Assert
        expect(loggedInUser.lastLoginTime, equals(loginTime));
      });

      test('should check device ID match', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'match_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          currentDeviceId: 'device_abc',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act & Assert
        expect(user.isCurrentDevice('device_abc'), isTrue);
        expect(user.isCurrentDevice('device_xyz'), isFalse);
        expect(user.isCurrentDevice(null), isFalse);
      });
    });

    group('Image Deletion Flags (NEW)', () {
      test('should create AppUser with imageMarkedForDeletion field', () {
        // Arrange
        final now = DateTime.now();
        
        // Act
        final user = AppUser(
          id: 'deletion_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageMarkedForDeletion: true,
          signatureMarkedForDeletion: false,
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert
        expect(user.imageMarkedForDeletion, isTrue);
        expect(user.signatureMarkedForDeletion, isFalse);
      });

      test('should have default false values for deletion flags', () {
        // Arrange
        final now = DateTime.now();
        
        // Act
        final user = AppUser(
          id: 'default_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert - should default to false
        expect(user.imageMarkedForDeletion, isFalse);
        expect(user.signatureMarkedForDeletion, isFalse);
      });

      test('should preserve imageMarkedForDeletion when adding image path', () {
        // This tests the critical delete-then-add offline scenario
        
        // Arrange - user with image marked for deletion
        final now = DateTime.now();
        final user = AppUser(
          id: 'preserve_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageMarkedForDeletion: true, // Already marked for deletion
          needsImageSync: true,
          createdAt: now,
          updatedAt: now,
        );
        
        // Act - Add new image path (simulating offline add after delete)
        final updatedUser = user.copyWith(
          imageLocalPath: () => 'SnagSnapper/test/Profile/profile.jpg',
          // imageMarkedForDeletion should PERSIST (not be cleared)
        );
        
        // Assert - deletion flag must persist until sync
        expect(updatedUser.imageMarkedForDeletion, isTrue); // CRITICAL!
        expect(updatedUser.imageLocalPath, 'SnagSnapper/test/Profile/profile.jpg');
        expect(updatedUser.needsImageSync, isTrue);
      });

      test('should serialize deletion flags to database', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'serialize_deletion',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageMarkedForDeletion: true,
          signatureMarkedForDeletion: false,
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final dbMap = user.toDatabase();
        
        // Assert
        expect(dbMap['image_marked_for_deletion'], equals(1)); // true = 1
        expect(dbMap['signature_marked_for_deletion'], equals(0)); // false = 0
      });

      test('should deserialize deletion flags from database', () {
        // Arrange
        final dbMap = {
          'id': 'deserialize_deletion',
          'name': 'Test User',
          'email': 'test@test.com',
          'phone': '+1234567890',
          'job_title': 'Tester',
          'company_name': 'Test Co',
          'created_at': 1704067200000,
          'updated_at': 1704067200000,
          'image_marked_for_deletion': 1,
          'signature_marked_for_deletion': 0,
          'needs_profile_sync': 0,
          'needs_image_sync': 0,
          'needs_signature_sync': 0,
        };
        
        // Act
        final user = AppUser.fromDatabase(dbMap);
        
        // Assert
        expect(user.imageMarkedForDeletion, isTrue);
        expect(user.signatureMarkedForDeletion, isFalse);
      });
    });

    group('Firebase Path Fields (NEW)', () {
      test('should use imageFirebasePath instead of imageFirebaseUrl', () {
        // Arrange
        final now = DateTime.now();
        
        // Act
        final user = AppUser(
          id: 'path_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageFirebasePath: 'users/path_test/profile.jpg',
          signatureFirebasePath: 'users/path_test/signature.jpg',
          createdAt: now,
          updatedAt: now,
        );
        
        // Assert - using paths not URLs
        expect(user.imageFirebasePath, 'users/path_test/profile.jpg');
        expect(user.signatureFirebasePath, 'users/path_test/signature.jpg');
      });

      test('should serialize Firebase paths to database', () {
        // Arrange
        final now = DateTime.now();
        final user = AppUser(
          id: 'path_serialize',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageFirebasePath: 'users/test/profile.jpg',
          signatureFirebasePath: 'users/test/signature.jpg',
          createdAt: now,
          updatedAt: now,
        );
        
        // Act
        final dbMap = user.toDatabase();
        
        // Assert
        expect(dbMap['image_firebase_path'], 'users/test/profile.jpg');
        expect(dbMap['signature_firebase_path'], 'users/test/signature.jpg');
        // Should not have old URL fields
        expect(dbMap.containsKey('image_firebase_url'), isFalse);
        expect(dbMap.containsKey('signature_firebase_url'), isFalse);
      });
    });

    group('Delete-Then-Add Offline Scenario (CRITICAL)', () {
      test('should handle complete delete-then-add flow correctly', () {
        // This tests the complete offline delete-then-add scenario
        
        final now = DateTime.now();
        
        // Step 1: Start with synced image
        final user1 = AppUser(
          id: 'offline_test',
          name: 'Test User',
          email: 'test@test.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          imageLocalPath: 'SnagSnapper/offline_test/Profile/profile.jpg',
          imageFirebasePath: 'users/offline_test/profile.jpg',
          needsImageSync: false,
          createdAt: now,
          updatedAt: now,
        );
        
        // Step 2: Delete image offline
        final user2 = user1.copyWith(
          imageLocalPath: () => null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        );
        
        expect(user2.imageLocalPath, isNull);
        expect(user2.imageMarkedForDeletion, isTrue);
        expect(user2.imageFirebasePath, 'users/offline_test/profile.jpg'); // Kept for reference
        expect(user2.needsImageSync, isTrue);
        
        // Step 3: Add new image while still offline
        final user3 = user2.copyWith(
          imageLocalPath: () => 'SnagSnapper/offline_test/Profile/profile.jpg',
          // imageMarkedForDeletion should PERSIST (not be cleared)
        );
        
        expect(user3.imageLocalPath, 'SnagSnapper/offline_test/Profile/profile.jpg');
        expect(user3.imageMarkedForDeletion, isTrue); // MUST remain true
        expect(user3.needsImageSync, isTrue);
        
        // Step 4: After successful sync
        final user4 = user3.copyWith(
          imageMarkedForDeletion: false,
          needsImageSync: false,
        );
        
        expect(user4.imageMarkedForDeletion, isFalse);
        expect(user4.needsImageSync, isFalse);
      });
    });
  });
}