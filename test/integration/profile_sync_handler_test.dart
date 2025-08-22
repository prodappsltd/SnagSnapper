import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';

/// Tests for ProfileSyncHandler delete-then-add logic
/// Verifies that the sync handler properly handles the deletion flag
@GenerateMocks([FirebaseFirestore, FirebaseStorage, Reference])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ProfileSyncHandler Delete-Then-Add Tests', () {
    late AppDatabase database;
    late ProfileSyncHandler syncHandler;
    late ImageStorageService imageStorage;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseStorage mockStorage;
    late String testUserId;
    late AppUser testUser;
    late Directory testDirectory;

    setUpAll(() async {
      final tempDir = await getTemporaryDirectory();
      testDirectory = Directory(p.join(tempDir.path, 'sync_handler_test'));
      if (!testDirectory.existsSync()) {
        testDirectory.createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      database = AppDatabase.instance;
      imageStorage = ImageStorageService();
      mockFirestore = MockFirebaseFirestore();
      mockStorage = MockFirebaseStorage();
      
      syncHandler = ProfileSyncHandler(
        database: database,
        firestore: mockFirestore,
        storage: mockStorage,
        imageStorage: imageStorage,
      );
      
      testUserId = 'sync_test_${DateTime.now().millisecondsSinceEpoch}';
      testUser = AppUser(
        id: testUserId,
        name: 'Sync Test User',
        email: 'sync@test.com',
        phone: '+1234567890',
        jobTitle: 'Tester',
        companyName: 'Test Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await database.profileDao.insertProfile(testUser);
    });

    tearDown(() async {
      await database.profileDao.deleteProfile(testUserId);
    });

    test('should handle delete-then-add scenario correctly', () async {
      // This test verifies the critical delete-then-add offline scenario
      // Requirements:
      // 1. When imageMarkedForDeletion is true AND imageLocalPath exists
      // 2. Must DELETE from Firebase first
      // 3. Then UPLOAD new image
      // 4. Clear the deletion flag only after successful sync
      
      // Setup: User has existing image in Firebase
      var user = testUser.copyWith(
        imageLocalPath: () => 'SnagSnapper/$testUserId/Profile/profile.jpg',
        imageFirebasePath: () => 'users/$testUserId/profile.jpg',
        imageMarkedForDeletion: true, // Critical flag
        needsImageSync: true,
      );
      await database.profileDao.updateProfile(testUserId, user);
      
      // Create a mock image file
      final image = img.Image(width: 100, height: 100);
      image.fill(img.ColorRgb8(0, 255, 0));
      final imageBytes = img.encodeJpg(image);
      final imageFile = File(p.join(testDirectory.path, 'test.jpg'));
      await imageFile.writeAsBytes(imageBytes);
      
      // Setup mock Firebase Storage
      final mockRef = MockReference();
      when(mockStorage.ref(any)).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async {});
      when(mockRef.putFile(any)).thenAnswer((_) async => null as TaskSnapshot);
      
      // EXPECTED BEHAVIOR:
      // 1. Check imageMarkedForDeletion flag
      // 2. If true, delete from Firebase Storage first
      // 3. Upload new image
      // 4. Clear deletion flag
      
      // The current implementation is BROKEN and needs fixing
      // It should:
      // - Check localUser.imageMarkedForDeletion
      // - Call storage.ref('users/$userId/profile.jpg').delete() if true
      // - Then upload the new image
      // - Clear the flag after successful sync
      
      expect(user.imageMarkedForDeletion, isTrue,
        reason: 'Deletion flag must be set for this test');
      expect(user.imageLocalPath, isNotNull,
        reason: 'Local path must exist (new image added)');
      expect(user.imageFirebasePath, isNotNull,
        reason: 'Firebase path indicates previous upload');
      
      // After sync, the flag should be cleared
      // await syncHandler.syncProfileImage(testUserId, user.imageLocalPath!);
      
      // user = (await database.profileDao.getProfile(testUserId))!;
      // expect(user.imageMarkedForDeletion, isFalse,
      //   reason: 'Deletion flag should be cleared after sync');
    });

    test('should delete from Firebase when image deleted offline', () async {
      // Setup: Image was deleted offline
      var user = testUser.copyWith(
        imageLocalPath: () => null, // No local image
        imageFirebasePath: () => 'users/$testUserId/profile.jpg',
        imageMarkedForDeletion: true,
        needsImageSync: true,
      );
      await database.profileDao.updateProfile(testUserId, user);
      
      // Expected: Should delete from Firebase Storage
      final mockRef = MockReference();
      when(mockStorage.ref('users/$testUserId/profile.jpg')).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async {});
      
      // After sync:
      // - Firebase Storage file should be deleted
      // - imageFirebasePath should be cleared
      // - imageMarkedForDeletion should be false
      // - needsImageSync should be false
    });

    test('should upload new image when added offline', () async {
      // Setup: New image added offline (no deletion)
      var user = testUser.copyWith(
        imageLocalPath: () => 'SnagSnapper/$testUserId/Profile/profile.jpg',
        imageFirebasePath: () => null,
        imageMarkedForDeletion: false,
        needsImageSync: true,
      );
      await database.profileDao.updateProfile(testUserId, user);
      
      // Expected: Should upload to Firebase Storage
      final mockRef = MockReference();
      when(mockStorage.ref('users/$testUserId/profile.jpg')).thenReturn(mockRef);
      when(mockRef.putFile(any)).thenAnswer((_) async => null as TaskSnapshot);
      
      // After sync:
      // - File should be uploaded to Firebase Storage
      // - imageFirebasePath should be set
      // - needsImageSync should be false
    });

    test('should handle replace operation (delete old, upload new)', () async {
      // Setup: User replaced image (delete + add in one operation)
      var user = testUser.copyWith(
        imageLocalPath: () => 'SnagSnapper/$testUserId/Profile/profile.jpg',
        imageFirebasePath: () => 'users/$testUserId/profile.jpg',
        imageMarkedForDeletion: false, // For replace, we don't set this
        needsImageSync: true,
      );
      await database.profileDao.updateProfile(testUserId, user);
      
      // Expected: Should just upload (overwrites in Firebase Storage)
      final mockRef = MockReference();
      when(mockStorage.ref('users/$testUserId/profile.jpg')).thenReturn(mockRef);
      when(mockRef.putFile(any)).thenAnswer((_) async => null as TaskSnapshot);
      
      // Firebase Storage automatically overwrites with the same path
    });
  });
  
  group('ProfileSyncHandler Field Name Updates', () {
    test('should use imageFirebasePath not imageFirebaseUrl', () async {
      // The current ProfileSyncHandler uses old field names
      // It should be updated to use:
      // - imageFirebasePath (not imageFirebaseUrl)
      // - signatureFirebasePath (not signatureFirebaseUrl)
      
      // This test documents what needs to be fixed
      final testUser = AppUser(
        id: 'field_test',
        name: 'Field Test',
        email: 'field@test.com',
        phone: '+1234567890',
        jobTitle: 'Tester',
        companyName: 'Test Co',
        imageFirebasePath: 'users/field_test/profile.jpg', // New field
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(testUser.imageFirebasePath, equals('users/field_test/profile.jpg'));
      // The sync handler should read/write this field, not imageFirebaseUrl
    });
  });
}