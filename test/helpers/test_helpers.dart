import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:snagsnapper/Data/database/app_database.dart';

/// Test helper utilities for database and model testing
class TestHelpers {
  /// Creates a temporary database for testing
  static Future<String> createTempDatabase() async {
    final tempDir = await Directory.systemTemp.createTemp('test_db_');
    return path.join(tempDir.path, 'test.db');
  }
  
  /// Creates a test database instance
  static AppDatabase createTestDatabase() {
    // Use the singleton instance for testing
    return AppDatabase.instance;
  }

  /// Deletes a test database file
  static Future<void> deleteTempDatabase(String dbPath) async {
    try {
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Also try to delete the directory if empty
      final dir = Directory(path.dirname(dbPath));
      if (await dir.exists()) {
        final contents = await dir.list().toList();
        if (contents.isEmpty) {
          await dir.delete();
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Creates a test AppUser with default values
  static Map<String, dynamic> createTestUser({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? companyName,
    String? postcodeArea,
    String? dateFormat,
    String? imageLocalPath,
    String? imageFirebasePath,
    String? signatureLocalPath,
    String? signatureFirebasePath,
    bool needsProfileSync = false,
    bool needsImageSync = false,
    bool needsSignatureSync = false,
    DateTime? lastSyncTime,
    String? currentDeviceId,
    DateTime? lastLoginTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    int localVersion = 1,
    int firebaseVersion = 0,
  }) {
    final now = DateTime.now();
    return {
      'id': id ?? 'test_user_${now.millisecondsSinceEpoch}',
      'name': name ?? 'Test User',
      'email': email ?? 'test@example.com',
      'phone': phone ?? '+1234567890',
      'job_title': jobTitle ?? 'Tester',
      'company_name': companyName ?? 'Test Company',
      'postcode_area': postcodeArea,
      'date_format': dateFormat ?? 'dd-MM-yyyy',
      'image_local_path': imageLocalPath,
      'image_firebase_path': imageFirebasePath,
      'signature_local_path': signatureLocalPath,
      'signature_firebase_path': signatureFirebasePath,
      'needs_profile_sync': needsProfileSync,
      'needs_image_sync': needsImageSync,
      'needs_signature_sync': needsSignatureSync,
      'last_sync_time': lastSyncTime,
      'current_device_id': currentDeviceId,
      'last_login_time': lastLoginTime,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
      'local_version': localVersion,
      'firebase_version': firebaseVersion,
    };
  }

  /// Creates multiple test users
  static List<Map<String, dynamic>> createTestUsers(int count) {
    return List.generate(count, (i) => createTestUser(
      id: 'test_user_$i',
      name: 'Test User $i',
      email: 'test$i@example.com',
      phone: '+123456789$i',
      jobTitle: 'Tester $i',
      companyName: 'Test Company $i',
    ));
  }

  /// Validates that a profile has all required fields
  static void validateProfile(Map<String, dynamic> profile) {
    expect(profile['id'], isNotNull);
    expect(profile['id'], isNotEmpty);
    
    expect(profile['name'], isNotNull);
    expect(profile['name'], isNotEmpty);
    
    expect(profile['email'], isNotNull);
    expect(profile['email'], isNotEmpty);
    expect(profile['email'], contains('@'));
    
    expect(profile['phone'], isNotNull);
    expect(profile['phone'], isNotEmpty);
    expect(profile['phone'].length, greaterThanOrEqualTo(7));
    
    expect(profile['job_title'], isNotNull);
    expect(profile['job_title'], isNotEmpty);
    
    expect(profile['company_name'], isNotNull);
    expect(profile['company_name'], isNotEmpty);
    
    expect(profile['created_at'], isNotNull);
    expect(profile['updated_at'], isNotNull);
  }

  /// Compares two profiles for equality (ignoring timestamps)
  static void assertProfilesEqual(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected, {
    bool ignoreTimestamps = true,
  }) {
    final keysToCompare = expected.keys.where((key) {
      if (ignoreTimestamps) {
        return !['created_at', 'updated_at', 'last_sync_time', 'last_login_time'].contains(key);
      }
      return true;
    });

    for (final key in keysToCompare) {
      expect(
        actual[key],
        equals(expected[key]),
        reason: 'Field $key does not match',
      );
    }
  }

  /// Creates a profile with sync flags set
  static Map<String, dynamic> createProfileNeedingSync({
    bool needsProfileSync = true,
    bool needsImageSync = false,
    bool needsSignatureSync = false,
  }) {
    return createTestUser(
      id: 'sync_test_${DateTime.now().millisecondsSinceEpoch}',
      needsProfileSync: needsProfileSync,
      needsImageSync: needsImageSync,
      needsSignatureSync: needsSignatureSync,
    );
  }

  /// Simulates a profile update
  static Map<String, dynamic> simulateProfileUpdate(
    Map<String, dynamic> original,
    Map<String, dynamic> updates,
  ) {
    final updated = Map<String, dynamic>.from(original);
    updated.addAll(updates);
    updated['updated_at'] = DateTime.now();
    
    // Set sync flags based on what was updated
    if (updates.containsKey('name') ||
        updates.containsKey('email') ||
        updates.containsKey('phone') ||
        updates.containsKey('job_title') ||
        updates.containsKey('company_name') ||
        updates.containsKey('postcode_area')) {
      updated['needs_profile_sync'] = true;
    }
    
    if (updates.containsKey('image_local_path')) {
      updated['needs_image_sync'] = true;
    }
    
    if (updates.containsKey('signature_local_path')) {
      updated['needs_signature_sync'] = true;
    }
    
    return updated;
  }

  /// Validates image path format
  static void validateImagePath(String? path) {
    if (path == null) return;
    
    // Should be relative path
    expect(path.startsWith('/'), isFalse, reason: 'Path should be relative, not absolute');
    expect(path.startsWith('C:\\'), isFalse, reason: 'Path should be relative, not Windows absolute');
    
    // Should follow expected format
    expect(path, contains('SnagSnapper'));
    expect(path, contains('Profile'));
    expect(path.endsWith('.jpg'), isTrue, reason: 'Image should be JPEG format');
  }

  /// Creates a device ID for testing
  static String createTestDeviceId() {
    return 'test_device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Measures operation performance
  static Future<Duration> measurePerformance(Future Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsed;
  }

  /// Asserts operation completes within time limit
  static Future<void> assertPerformance(
    Future Function() operation,
    Duration maxDuration, {
    String? description,
  }) async {
    final duration = await measurePerformance(operation);
    expect(
      duration,
      lessThanOrEqualTo(maxDuration),
      reason: description ?? 'Operation took ${duration.inMilliseconds}ms, expected < ${maxDuration.inMilliseconds}ms',
    );
  }

  /// Creates test data for batch operations
  static List<Map<String, dynamic>> createBatchTestData(int count) {
    return List.generate(count, (i) => createTestUser(
      id: 'batch_$i',
      name: 'Batch User $i',
      email: 'batch$i@example.com',
      phone: '+100000000$i',
    ));
  }

  /// Validates sync flags are set correctly
  static void validateSyncFlags(
    Map<String, dynamic> profile, {
    required bool expectProfileSync,
    required bool expectImageSync,
    required bool expectSignatureSync,
  }) {
    expect(profile['needs_profile_sync'], equals(expectProfileSync),
        reason: 'needs_profile_sync flag mismatch');
    expect(profile['needs_image_sync'], equals(expectImageSync),
        reason: 'needs_image_sync flag mismatch');
    expect(profile['needs_signature_sync'], equals(expectSignatureSync),
        reason: 'needs_signature_sync flag mismatch');
  }

  /// Simulates clearing sync flags after successful sync
  static Map<String, dynamic> simulateSyncComplete(Map<String, dynamic> profile) {
    final synced = Map<String, dynamic>.from(profile);
    synced['needs_profile_sync'] = false;
    synced['needs_image_sync'] = false;
    synced['needs_signature_sync'] = false;
    synced['last_sync_time'] = DateTime.now();
    synced['updated_at'] = DateTime.now();
    return synced;
  }
}

/// Test data fixtures
class TestFixtures {
  static const validDateFormats = ['dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd'];
  
  static const invalidEmails = [
    'notanemail',
    '@example.com',
    'user@',
    'user.example.com',
    'user@.com',
  ];
  
  static const validPhones = [
    '+1234567',  // Minimum length
    '+12345678901234',  // Near maximum
    '1234567890',  // Without +
    '+447700900123',  // UK format
  ];
  
  static const invalidPhones = [
    '123456',  // Too short
    '+1234567890123456',  // Too long
    'abc123',  // Contains letters
    '++1234567890',  // Multiple +
  ];
  
  static final validNames = [
    'Jo',  // Minimum length
    'John Doe',
    "O'Brien",  // With apostrophe
    'Mary-Jane',  // With hyphen
    'José García',  // Unicode characters
    'A' * 50,  // Maximum length
  ];
  
  static final invalidNames = [
    'A',  // Too short
    'A' * 51,  // Too long
    '',  // Empty
    '   ',  // Only spaces
  ];
  
  static final validCompanyNames = [
    'Co',  // Minimum length
    'Construction Company Ltd.',
    'Smith & Sons',
    'ABC+DEF Corp',
    'Company/Division',
    'A' * 100,  // Maximum length
  ];
  
  static final invalidCompanyNames = [
    'C',  // Too short
    'A' * 101,  // Too long
    '',  // Empty
  ];
}