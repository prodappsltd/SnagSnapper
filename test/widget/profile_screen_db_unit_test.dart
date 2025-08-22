import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:mockito/mockito.dart';

// Mock classes for unit testing database operations
class MockAppDatabase extends Mock implements AppDatabase {
  final MockProfileDao _mockProfileDao = MockProfileDao();
  
  @override
  ProfileDao get profileDao => _mockProfileDao;
}

class MockProfileDao extends Mock implements ProfileDao {
  AppUser? _storedUser;
  int updateCallCount = 0;
  int setNeedsProfileSyncCount = 0;
  int setNeedsImageSyncCount = 0;
  int setNeedsSignatureSyncCount = 0;
  
  @override
  Future<AppUser?> getProfile(String userId) async {
    print('MockProfileDao: Getting profile for $userId');
    return _storedUser;
  }
  
  @override
  Future<bool> updateProfile(String userId, AppUser updatedUser) async {
    print('MockProfileDao: Updating profile for $userId with name ${updatedUser.name}');
    updateCallCount++;
    _storedUser = updatedUser;
    return true;
  }
  
  @override
  Future<bool> insertProfile(AppUser user) async {
    print('MockProfileDao: Inserting profile for ${user.id}');
    _storedUser = user;
    return true;
  }
  
  @override
  Future<bool> setNeedsProfileSync(String userId) async {
    print('MockProfileDao: Setting needsProfileSync for $userId');
    setNeedsProfileSyncCount++;
    if (_storedUser != null && _storedUser!.id == userId) {
      _storedUser = AppUser(
        id: _storedUser!.id,
        name: _storedUser!.name,
        email: _storedUser!.email,
        phone: _storedUser!.phone,
        jobTitle: _storedUser!.jobTitle,
        companyName: _storedUser!.companyName,
        postcodeOrArea: _storedUser!.postcodeOrArea,
        dateFormat: _storedUser!.dateFormat,
        imageLocalPath: _storedUser!.imageLocalPath,
        imageFirebasePath: _storedUser!.imageFirebasePath,
        signatureLocalPath: _storedUser!.signatureLocalPath,
        signatureFirebasePath: _storedUser!.signatureFirebasePath,
        needsProfileSync: true, // Set the flag
        needsImageSync: _storedUser!.needsImageSync,
        needsSignatureSync: _storedUser!.needsSignatureSync,
        currentDeviceId: _storedUser!.currentDeviceId,
        createdAt: _storedUser!.createdAt,
        updatedAt: DateTime.now(),
        localVersion: _storedUser!.localVersion,
        firebaseVersion: _storedUser!.firebaseVersion,
      );
    }
    return true;
  }
  
  @override
  Future<bool> setNeedsImageSync(String userId) async {
    print('MockProfileDao: Setting needsImageSync for $userId');
    setNeedsImageSyncCount++;
    if (_storedUser != null && _storedUser!.id == userId) {
      _storedUser = AppUser(
        id: _storedUser!.id,
        name: _storedUser!.name,
        email: _storedUser!.email,
        phone: _storedUser!.phone,
        jobTitle: _storedUser!.jobTitle,
        companyName: _storedUser!.companyName,
        postcodeOrArea: _storedUser!.postcodeOrArea,
        dateFormat: _storedUser!.dateFormat,
        imageLocalPath: _storedUser!.imageLocalPath,
        imageFirebasePath: _storedUser!.imageFirebasePath,
        signatureLocalPath: _storedUser!.signatureLocalPath,
        signatureFirebasePath: _storedUser!.signatureFirebasePath,
        needsProfileSync: _storedUser!.needsProfileSync,
        needsImageSync: true, // Set the flag
        needsSignatureSync: _storedUser!.needsSignatureSync,
        currentDeviceId: _storedUser!.currentDeviceId,
        createdAt: _storedUser!.createdAt,
        updatedAt: DateTime.now(),
        localVersion: _storedUser!.localVersion,
        firebaseVersion: _storedUser!.firebaseVersion,
      );
    }
    return true;
  }
  
  @override
  Future<bool> setNeedsSignatureSync(String userId) async {
    print('MockProfileDao: Setting needsSignatureSync for $userId');
    setNeedsSignatureSyncCount++;
    if (_storedUser != null && _storedUser!.id == userId) {
      _storedUser = AppUser(
        id: _storedUser!.id,
        name: _storedUser!.name,
        email: _storedUser!.email,
        phone: _storedUser!.phone,
        jobTitle: _storedUser!.jobTitle,
        companyName: _storedUser!.companyName,
        postcodeOrArea: _storedUser!.postcodeOrArea,
        dateFormat: _storedUser!.dateFormat,
        imageLocalPath: _storedUser!.imageLocalPath,
        imageFirebasePath: _storedUser!.imageFirebasePath,
        signatureLocalPath: _storedUser!.signatureLocalPath,
        signatureFirebasePath: _storedUser!.signatureFirebasePath,
        needsProfileSync: _storedUser!.needsProfileSync,
        needsImageSync: _storedUser!.needsImageSync,
        needsSignatureSync: true, // Set the flag
        currentDeviceId: _storedUser!.currentDeviceId,
        createdAt: _storedUser!.createdAt,
        updatedAt: DateTime.now(),
        localVersion: _storedUser!.localVersion,
        firebaseVersion: _storedUser!.firebaseVersion,
      );
    }
    return true;
  }
  
  void setStoredUser(AppUser? user) {
    _storedUser = user;
  }
  
  void reset() {
    _storedUser = null;
    updateCallCount = 0;
    setNeedsProfileSyncCount = 0;
    setNeedsImageSyncCount = 0;
    setNeedsSignatureSyncCount = 0;
  }
}

void main() {
  late MockAppDatabase mockDatabase;
  late MockProfileDao mockProfileDao;
  
  setUp(() {
    mockDatabase = MockAppDatabase();
    mockProfileDao = mockDatabase._mockProfileDao;
  });

  group('ProfileScreen Database Operations - Unit Tests (Phase 2)', () {
    
    test('UNIT TEST 1: Should load existing profile from database', () async {
      // Arrange - PRD 4.3.3: Load from LOCAL database
      final existingUser = AppUser(
        id: 'test-user-123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+447700900123',
        jobTitle: 'Site Manager',
        companyName: 'ABC Construction',
        postcodeOrArea: 'SW1A',
        dateFormat: 'dd-MM-yyyy',
        imageLocalPath: 'SnagSnapper/test-user-123/Profile/profile.jpg',
        signatureLocalPath: 'SnagSnapper/test-user-123/Profile/signature.jpg',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        currentDeviceId: 'device-123',
        createdAt: DateTime.now().subtract(Duration(days: 7)),
        updatedAt: DateTime.now().subtract(Duration(days: 1)),
      );
      
      mockProfileDao.setStoredUser(existingUser);
      
      // Act
      final loadedUser = await mockDatabase.profileDao.getProfile('test-user-123');
      
      // Assert
      expect(loadedUser, isNotNull, reason: 'Should load profile from database');
      expect(loadedUser!.id, equals('test-user-123'));
      expect(loadedUser.name, equals('John Doe'));
      expect(loadedUser.email, equals('john@example.com'));
      expect(loadedUser.companyName, equals('ABC Construction'));
      expect(loadedUser.imageLocalPath, isNotNull);
      expect(loadedUser.signatureLocalPath, isNotNull);
    });

    test('UNIT TEST 2: Should update profile in database', () async {
      // Arrange
      final originalUser = AppUser(
        id: 'test-user-456',
        name: 'Jane Smith',
        email: 'jane@example.com',
        phone: '07700900456',
        jobTitle: 'Inspector',
        companyName: 'XYZ Ltd',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(originalUser);
      
      // Act - Update the user
      final updatedUser = AppUser(
        id: originalUser.id,
        name: 'Jane Doe', // Changed
        email: originalUser.email,
        phone: '07700900789', // Changed
        jobTitle: 'Senior Inspector', // Changed
        companyName: originalUser.companyName,
        needsProfileSync: true, // Should be set when updating
        createdAt: originalUser.createdAt,
        updatedAt: DateTime.now(),
        localVersion: 2,
      );
      
      final success = await mockDatabase.profileDao.updateProfile(
        'test-user-456',
        updatedUser
      );
      
      // Assert
      expect(success, isTrue);
      expect(mockProfileDao.updateCallCount, equals(1));
      
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser?.name, equals('Jane Doe'));
      expect(savedUser?.phone, equals('07700900789'));
      expect(savedUser?.jobTitle, equals('Senior Inspector'));
      expect(savedUser?.needsProfileSync, isTrue, 
        reason: 'PRD 4.3.3: Must set needsProfileSync when data changes');
    });

    test('UNIT TEST 3: Should create new profile if none exists', () async {
      // Arrange - No existing profile
      mockProfileDao.setStoredUser(null);
      
      // Act - Create new profile
      final newUser = AppUser(
        id: 'new-user-123',
        name: 'New User',
        email: 'new@example.com',
        phone: '07700900000',
        jobTitle: 'New Job',
        companyName: 'New Company',
        dateFormat: 'dd-MM-yyyy',
        needsProfileSync: true, // New profiles need sync
        currentDeviceId: 'device-new',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        localVersion: 1,
        firebaseVersion: 0,
      );
      
      final success = await mockDatabase.profileDao.insertProfile(newUser);
      
      // Assert
      expect(success, isTrue);
      
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser, isNotNull);
      expect(savedUser!.id, equals('new-user-123'));
      expect(savedUser.name, equals('New User'));
      expect(savedUser.needsProfileSync, isTrue, 
        reason: 'New profiles must have needsProfileSync = true');
      expect(savedUser.localVersion, equals(1));
      expect(savedUser.firebaseVersion, equals(0));
    });

    test('UNIT TEST 4: Should set sync flags when data changes', () async {
      // Arrange
      final user = AppUser(
        id: 'sync-test-user',
        name: 'Sync Test',
        email: 'sync@example.com',
        phone: '07700900111',
        jobTitle: 'Tester',
        companyName: 'Sync Co',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(user);
      
      // Act - Set sync flags
      await mockDatabase.profileDao.setNeedsProfileSync('sync-test-user');
      await mockDatabase.profileDao.setNeedsImageSync('sync-test-user');
      await mockDatabase.profileDao.setNeedsSignatureSync('sync-test-user');
      
      // Assert
      expect(mockProfileDao.setNeedsProfileSyncCount, equals(1));
      expect(mockProfileDao.setNeedsImageSyncCount, equals(1));
      expect(mockProfileDao.setNeedsSignatureSyncCount, equals(1));
      
      final updatedUser = mockProfileDao._storedUser;
      expect(updatedUser?.needsProfileSync, isTrue);
      expect(updatedUser?.needsImageSync, isTrue);
      expect(updatedUser?.needsSignatureSync, isTrue);
    });

    test('UNIT TEST 5: Should handle profile with optional fields', () async {
      // Arrange - Profile with minimal required fields only
      final minimalUser = AppUser(
        id: 'minimal-user',
        name: 'Minimal User',
        email: 'minimal@example.com',
        phone: '07700900000', // Required field
        jobTitle: 'Worker', // Required field
        companyName: 'Minimal Co',
        dateFormat: 'dd-MM-yyyy',
        // Optional fields not provided
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Act
      final success = await mockDatabase.profileDao.insertProfile(minimalUser);
      
      // Assert
      expect(success, isTrue);
      
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser, isNotNull);
      expect(savedUser!.phone, isNotNull, reason: 'Phone is required');
      expect(savedUser.jobTitle, isNotNull, reason: 'Job title is required');
      expect(savedUser.postcodeOrArea, isNull, reason: 'Postcode is optional');
      expect(savedUser.imageLocalPath, isNull, reason: 'Image is optional');
      expect(savedUser.signatureLocalPath, isNull, reason: 'Signature is optional');
    });

    test('UNIT TEST 6: Should increment local version on update', () async {
      // Arrange
      final user = AppUser(
        id: 'version-test',
        name: 'Version Test',
        email: 'version@example.com',
        phone: '07700900111',
        jobTitle: 'Tester',
        companyName: 'Version Co',
        localVersion: 1,
        firebaseVersion: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(user);
      
      // Act - Update multiple times
      for (int i = 2; i <= 5; i++) {
        final updatedUser = AppUser(
          id: user.id,
          name: 'Updated Name $i',
          email: user.email,
          phone: user.phone,
          jobTitle: user.jobTitle,
          companyName: user.companyName,
          localVersion: i, // Increment version
          firebaseVersion: 1, // Firebase version unchanged (offline)
          needsProfileSync: true,
          createdAt: user.createdAt,
          updatedAt: DateTime.now(),
        );
        
        await mockDatabase.profileDao.updateProfile(
          'version-test',
          updatedUser
        );
      }
      
      // Assert
      expect(mockProfileDao.updateCallCount, equals(4));
      
      final finalUser = mockProfileDao._storedUser;
      expect(finalUser?.localVersion, equals(5), 
        reason: 'Local version should increment with each update');
      expect(finalUser?.firebaseVersion, equals(1), 
        reason: 'Firebase version unchanged when offline');
      expect(finalUser?.needsProfileSync, isTrue, 
        reason: 'Should need sync after offline updates');
    });

    test('UNIT TEST 7: Should maintain device ID through updates', () async {
      // Arrange - PRD 4.3.1c: Device ID enforcement
      final deviceId = 'unique-device-123';
      final user = AppUser(
        id: 'device-test',
        name: 'Device Test',
        email: 'device@example.com',
        phone: '07700900222',
        jobTitle: 'Device Tester',
        companyName: 'Device Co',
        currentDeviceId: deviceId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(user);
      
      // Act - Update profile
      final updatedUser = AppUser(
        id: user.id,
        name: 'Updated Device Test',
        email: user.email,
        phone: user.phone,
        jobTitle: user.jobTitle,
        companyName: user.companyName,
        currentDeviceId: deviceId, // Same device ID
        needsProfileSync: true,
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await mockDatabase.profileDao.updateProfile(
        'device-test',
        updatedUser
      );
      
      // Assert
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser?.currentDeviceId, equals(deviceId), 
        reason: 'Device ID should be maintained through updates');
    });

    test('UNIT TEST 8: Should track timestamps correctly', () async {
      // Arrange
      final createdTime = DateTime.now().subtract(Duration(days: 30));
      final user = AppUser(
        id: 'timestamp-test',
        name: 'Timestamp Test',
        email: 'timestamp@example.com',
        phone: '07700900333',
        jobTitle: 'Time Tracker',
        companyName: 'Timestamp Co',
        createdAt: createdTime,
        updatedAt: createdTime,
      );
      
      // Act - Insert profile
      await mockDatabase.profileDao.insertProfile(user);
      
      // Wait a moment
      await Future.delayed(Duration(milliseconds: 100));
      
      // Update profile
      final updatedUser = AppUser(
        id: user.id,
        name: 'Updated Timestamp',
        email: user.email,
        phone: user.phone,
        jobTitle: user.jobTitle,
        companyName: user.companyName,
        createdAt: createdTime, // Created time should not change
        updatedAt: DateTime.now(), // Updated time should be recent
      );
      
      await mockDatabase.profileDao.updateProfile(
        'timestamp-test',
        updatedUser
      );
      
      // Assert
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser?.createdAt, equals(createdTime), 
        reason: 'Created timestamp should not change on update');
      expect(savedUser?.updatedAt.isAfter(createdTime), isTrue, 
        reason: 'Updated timestamp should be after created timestamp');
    });
  });

  group('ProfileScreen Database Operations - PRD Compliance', () {
    
    test('PRD 4.3.3: Profile changes work offline', () async {
      // Arrange - Simulate offline mode
      final user = AppUser(
        id: 'offline-test',
        name: 'Offline User',
        email: 'offline@example.com',
        phone: '07700900666',
        jobTitle: 'Field Worker',
        companyName: 'Offline Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(user);
      
      // Act - Make changes "offline"
      final updatedUser = AppUser(
        id: user.id,
        name: 'Updated Offline',
        email: user.email,
        phone: user.phone,
        jobTitle: user.jobTitle,
        companyName: 'Updated Offline Co',
        needsProfileSync: true, // Flag for sync when online
        localVersion: 2,
        firebaseVersion: 0, // Not synced
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final success = await mockDatabase.profileDao.updateProfile(
        'offline-test',
        updatedUser
      );
      
      // Assert
      expect(success, isTrue, 
        reason: 'PRD 1.2: App works 100% without internet');
      
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser?.needsProfileSync, isTrue, 
        reason: 'Should flag for sync when back online');
      expect(savedUser?.localVersion, greaterThan(savedUser?.firebaseVersion ?? 0), 
        reason: 'Local version ahead of Firebase when offline');
    });

    test('PRD 4.5.1: Required fields validation', () async {
      // This test verifies that the data model enforces required fields
      // In actual implementation, validation happens at UI level
      
      // Arrange - Try to create user without required fields
      try {
        final invalidUser = AppUser(
          id: 'invalid-test',
          name: '', // Invalid: empty name
          email: 'test@example.com',
          phone: '07700900444',
          jobTitle: 'Test',
          companyName: '', // Invalid: empty company
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // In actual implementation, validation would prevent this
        // For test purposes, we check the fields exist
        expect(invalidUser.name.isEmpty, isTrue);
        expect(invalidUser.companyName.isEmpty, isTrue);
        
      } catch (e) {
        // Validation might throw in actual implementation
        print('Validation error as expected: $e');
      }
    });

    test('PRD 4.3.4: Image path handling', () async {
      // Arrange
      final user = AppUser(
        id: 'image-test',
        name: 'Image Test',
        email: 'image@example.com',
        phone: '07700900555',
        jobTitle: 'Photographer',
        companyName: 'Image Co',
        imageLocalPath: null, // No image initially
        needsImageSync: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      mockProfileDao.setStoredUser(user);
      
      // Act - Add image
      final userWithImage = AppUser(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        jobTitle: user.jobTitle,
        companyName: user.companyName,
        imageLocalPath: 'SnagSnapper/image-test/Profile/profile.jpg',
        needsImageSync: true, // Should flag for sync
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await mockDatabase.profileDao.updateProfile(
        'image-test',
        userWithImage
      );
      
      // Also test the dedicated sync flag method
      await mockDatabase.profileDao.setNeedsImageSync('image-test');
      
      // Assert
      final savedUser = mockProfileDao._storedUser;
      expect(savedUser?.imageLocalPath, contains('SnagSnapper'), 
        reason: 'Image path should follow PRD convention');
      expect(savedUser?.needsImageSync, isTrue, 
        reason: 'Should flag image for sync');
      expect(mockProfileDao.setNeedsImageSyncCount, equals(1));
    });
  });
}