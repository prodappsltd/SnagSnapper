import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/services/sync/conflict_resolver.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;

    setUp(() {
      resolver = ConflictResolver();
    });

    group('Version Conflict Tests', () {
      final baseUser = AppUser(
        id: 'test_user_id',
        name: 'Local User',
        email: 'local@example.com',
        companyName: 'Local Corp',
        phone: '1234567890',
        jobTitle: 'Developer',
        postcodeOrArea: '12345',
        dateFormat: 'dd-MM-yyyy',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        createdAt: DateTime.now().subtract(Duration(days: 7)),
        updatedAt: DateTime.now().subtract(Duration(hours: 2)),
        localVersion: 2,
        firebaseVersion: 1,
      );

      test('should upload local when local version > firebase version', () async {
        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'version': 1, // Firebase version is older
          'updatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))),
        };

        final result = await resolver.resolveConflict(baseUser, remoteData);

        expect(result.strategy, equals(ConflictStrategy.localWins));
        expect(result.resolvedUser.name, equals('Local User'));
        expect(result.resolvedUser.email, equals('local@example.com'));
        expect(result.shouldUpload, isTrue);
      });

      test('should download firebase when firebase version > local version', () async {
        final localUser = baseUser.copyWith(
          localVersion: 1,
          firebaseVersion: 1,
        );

        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'phone': '9876543210',
          'version': 3, // Firebase version is newer
          'updatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1))),
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        expect(result.strategy, equals(ConflictStrategy.remoteWins));
        expect(result.resolvedUser.name, equals('Remote User'));
        expect(result.resolvedUser.email, equals('remote@example.com'));
        expect(result.resolvedUser.phone, equals('9876543210'));
        expect(result.shouldUpload, isFalse);
      });

      test('should check timestamps when versions are equal', () async {
        final localUser = baseUser.copyWith(
          localVersion: 2,
          firebaseVersion: 2,
          updatedAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'version': 2, // Same version
          'updatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        // Local is more recent (1 hour ago vs 2 hours ago)
        expect(result.strategy, equals(ConflictStrategy.localWins));
        expect(result.resolvedUser.name, equals('Local User'));
      });

      test('should handle missing firebase version (first sync)', () async {
        final remoteData = <String, dynamic>{
          // No version field - first time sync
          'name': 'Remote User',
          'email': 'remote@example.com',
        };

        final result = await resolver.resolveConflict(baseUser, remoteData);

        expect(result.strategy, equals(ConflictStrategy.localWins));
        expect(result.shouldUpload, isTrue);
      });

      test('should handle corrupted version data', () async {
        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'version': 'invalid', // Invalid version type
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(baseUser, remoteData);

        // Should default to safe strategy
        expect(result.strategy, equals(ConflictStrategy.merge));
        expect(result.hasError, isFalse);
      });
    });

    group('Merge Strategy Tests', () {
      final localUser = AppUser(
        id: 'test_user_id',
        name: 'Local User',
        email: 'local@example.com',
        companyName: 'Local Corp',
        phone: '1234567890',
        jobTitle: 'Developer',
        postcodeOrArea: '12345',
        dateFormat: 'dd-MM-yyyy',
        imageLocalPath: 'local_image.jpg',
        signatureLocalPath: 'local_sig.png',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        createdAt: DateTime.now().subtract(Duration(days: 7)),
        updatedAt: DateTime.now(),
        localVersion: 2,
        firebaseVersion: 2,
      );

      test('should merge fields based on timestamps', () async {
        final remoteData = {
          'name': 'Remote User', // Different
          'email': 'local@example.com', // Same
          'companyName': 'Remote Corp', // Different
          'phone': '1234567890', // Same
          'jobTitle': 'Senior Developer', // Different
          'version': 2,
          'updatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 30))),
          // Individual field timestamps for merge strategy
          'nameUpdatedAt': Timestamp.fromDate(DateTime.now().add(Duration(hours: 1))), // Newer
          'companyNameUpdatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(days: 1))), // Older
          'jobTitleUpdatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))), // Older
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        expect(result.strategy, equals(ConflictStrategy.merge));
        // Name should come from remote (newer timestamp)
        expect(result.resolvedUser.name, equals('Remote User'));
        // Company should come from local (remote is older)
        expect(result.resolvedUser.companyName, equals('Local Corp'));
        // Job title should come from local (remote is older)
        expect(result.resolvedUser.jobTitle, equals('Developer'));
      });

      test('should preserve user recent edits', () async {
        // User just edited locally 1 minute ago
        final recentLocalUser = localUser.copyWith(
          name: 'Just Edited',
          updatedAt: DateTime.now().subtract(Duration(minutes: 1)),
        );

        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'version': 2,
          'updatedAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 2))),
        };

        final result = await resolver.resolveConflict(recentLocalUser, remoteData);

        // Should preserve recent local edits
        expect(result.resolvedUser.name, equals('Just Edited'));
        expect(result.shouldUpload, isTrue); // Need to upload local changes
      });

      test('should handle null and empty fields', () async {
        final localUserWithNulls = localUser.copyWith(
          phone: null,
          jobTitle: '',
          postcodeOrArea: null,
        );

        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'phone': '9876543210', // Remote has value
          'jobTitle': null, // Remote is null
          'postcodeOrArea': 'Remote Area', // Remote has value
          'version': 2,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(localUserWithNulls, remoteData);

        // Should prefer non-null values
        expect(result.resolvedUser.phone, equals('9876543210'));
        expect(result.resolvedUser.jobTitle, isEmpty);
        expect(result.resolvedUser.postcodeOrArea, equals('Remote Area'));
      });

      test('should maintain data integrity during merge', () async {
        final remoteData = {
          'name': 'Remote User',
          'email': 'invalid-email', // Invalid email
          'companyName': '', // Empty required field
          'phone': '123', // Too short
          'version': 2,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        // Should keep valid local data when remote is invalid
        expect(result.resolvedUser.email, equals('local@example.com'));
        expect(result.resolvedUser.companyName, equals('Local Corp'));
        expect(result.resolvedUser.phone, equals('1234567890'));
        expect(result.hasValidationIssues, isTrue);
      });

      test('should merge image and signature paths correctly', () async {
        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'imageFirebaseUrl': 'https://storage.url/image.jpg',
          'signatureFirebaseUrl': 'https://storage.url/sig.png',
          'version': 2,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        // Should keep local paths and add Firebase URLs
        expect(result.resolvedUser.imageLocalPath, equals('local_image.jpg'));
        expect(result.resolvedUser.imageFirebaseUrl, equals('https://storage.url/image.jpg'));
        expect(result.resolvedUser.signatureLocalPath, equals('local_sig.png'));
        expect(result.resolvedUser.signatureFirebaseUrl, equals('https://storage.url/sig.png'));
      });
    });

    group('Data Validation Tests', () {
      final validUser = AppUser(
        id: 'test_user_id',
        name: 'Valid User',
        email: 'valid@example.com',
        companyName: 'Valid Corp',
        phone: '1234567890',
        jobTitle: 'Developer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      test('should validate required fields are present', () async {
        final remoteData = {
          // Missing required fields: name, email, companyName
          'phone': '1234567890',
          'jobTitle': 'Developer',
          'version': 1,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(validUser, remoteData);

        // Should keep local valid data
        expect(result.resolvedUser.name, equals('Valid User'));
        expect(result.resolvedUser.email, equals('valid@example.com'));
        expect(result.resolvedUser.companyName, equals('Valid Corp'));
        expect(result.hasValidationIssues, isTrue);
      });

      test('should validate field types are correct', () async {
        final remoteData = {
          'name': 123, // Wrong type
          'email': true, // Wrong type
          'companyName': 'Remote Corp',
          'version': '2', // Should be int
          'updatedAt': 'not-a-timestamp', // Wrong type
        };

        final result = await resolver.resolveConflict(validUser, remoteData);

        // Should handle type mismatches gracefully
        expect(result.resolvedUser.name, equals('Valid User'));
        expect(result.resolvedUser.email, equals('valid@example.com'));
        expect(result.hasError, isFalse);
        expect(result.hasValidationIssues, isTrue);
      });

      test('should validate field lengths are within limits', () async {
        final remoteData = {
          'name': 'A' * 100, // Too long (max 50)
          'email': 'valid@example.com',
          'companyName': 'B' * 150, // Too long (max 100)
          'phone': '123456789012345678901', // Too long (max 15)
          'postcodeOrArea': 'C' * 25, // Too long (max 20)
          'version': 2,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(validUser, remoteData);

        // Should reject invalid lengths and keep local
        expect(result.resolvedUser.name, equals('Valid User'));
        expect(result.resolvedUser.companyName, equals('Valid Corp'));
        expect(result.resolvedUser.phone, equals('1234567890'));
        expect(result.hasValidationIssues, isTrue);
      });

      test('should validate email format', () async {
        final invalidEmails = [
          'notanemail',
          '@example.com',
          'user@',
          'user@.com',
          'user..name@example.com',
        ];

        for (final invalidEmail in invalidEmails) {
          final remoteData = {
            'name': 'Remote User',
            'email': invalidEmail,
            'companyName': 'Remote Corp',
            'version': 2,
            'updatedAt': Timestamp.now(),
          };

          final result = await resolver.resolveConflict(validUser, remoteData);
          
          expect(result.resolvedUser.email, equals('valid@example.com'),
              reason: 'Should reject invalid email: $invalidEmail');
        }
      });
    });

    group('Corruption Handling Tests', () {
      final validUser = AppUser(
        id: 'test_user_id',
        name: 'Valid User',
        email: 'valid@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Valid Corp',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      test('should detect corrupted data', () async {
        final corruptedData = {
          'name': '\u0000\u0001\u0002', // Contains null bytes
          'email': 'valid@example.com',
          'companyName': 'Valid Corp',
          'version': -1, // Invalid version
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(validUser, corruptedData);

        expect(result.hasCorruption, isTrue);
        expect(result.resolvedUser.name, equals('Valid User')); // Keep valid local
      });

      test('should fallback to local data when remote is corrupted', () async {
        final corruptedData = {
          // Completely corrupted structure
          'corrupted': true,
          'random': 'data',
        };

        final result = await resolver.resolveConflict(validUser, corruptedData);

        expect(result.strategy, equals(ConflictStrategy.localWins));
        expect(result.resolvedUser.id, equals('test_user_id'));
        expect(result.resolvedUser.name, equals('Valid User'));
      });

      test('should notify user of corruption', () async {
        final corruptedData = {
          'name': 'Valid Name',
          'email': 'valid@example.com',
          'companyName': 'Valid Corp',
          'version': double.infinity, // Invalid number
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(validUser, corruptedData);

        expect(result.requiresUserIntervention, isTrue);
        expect(result.errorMessage, contains('corruption'));
      });

      test('should attempt recovery from partial corruption', () async {
        final partiallyCorrupted = {
          'name': 'Valid Remote Name', // Valid
          'email': '\x00\x01', // Corrupted
          'companyName': 'Valid Remote Corp', // Valid
          'phone': '9876543210', // Valid
          'version': 2,
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(validUser, partiallyCorrupted);

        // Should use valid fields from remote, keep local for corrupted
        expect(result.resolvedUser.name, equals('Valid Remote Name'));
        expect(result.resolvedUser.email, equals('valid@example.com')); // Keep local
        expect(result.resolvedUser.companyName, equals('Valid Remote Corp'));
        expect(result.resolvedUser.phone, equals('9876543210'));
      });
    });

    group('Strategy Determination', () {
      final localUser = AppUser(
        id: 'test_user_id',
        name: 'Local User',
        email: 'local@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Local Corp',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        localVersion: 2,
        firebaseVersion: 1,
      );

      test('should determine correct strategy based on versions', () {
        // Test various version scenarios
        expect(
          resolver.determineStrategy(
            localUser.copyWith(localVersion: 3, firebaseVersion: 1),
            {'version': 1}
          ),
          equals(ConflictStrategy.localWins),
        );

        expect(
          resolver.determineStrategy(
            localUser.copyWith(localVersion: 1, firebaseVersion: 1),
            {'version': 3}
          ),
          equals(ConflictStrategy.remoteWins),
        );

        expect(
          resolver.determineStrategy(
            localUser.copyWith(localVersion: 2, firebaseVersion: 2),
            {'version': 2}
          ),
          equals(ConflictStrategy.merge),
        );
      });

      test('should handle edge cases in strategy determination', () {
        // No remote version
        expect(
          resolver.determineStrategy(localUser, {}),
          equals(ConflictStrategy.localWins),
        );

        // Invalid remote version
        expect(
          resolver.determineStrategy(localUser, {'version': 'invalid'}),
          equals(ConflictStrategy.merge),
        );

        // Negative versions
        expect(
          resolver.determineStrategy(localUser, {'version': -1}),
          equals(ConflictStrategy.localWins),
        );
      });

      test('should support manual strategy override', () async {
        resolver.setManualStrategy(ConflictStrategy.manual);

        final remoteData = {
          'name': 'Remote User',
          'email': 'remote@example.com',
          'companyName': 'Remote Corp',
          'version': 3, // Remote is newer
          'updatedAt': Timestamp.now(),
        };

        final result = await resolver.resolveConflict(localUser, remoteData);

        expect(result.strategy, equals(ConflictStrategy.manual));
        expect(result.requiresUserIntervention, isTrue);
      });
    });
  });
}