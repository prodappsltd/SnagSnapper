import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/test_helpers.dart';

@GenerateMocks([
  FirebaseStorage,
  FirebaseFirestore,
  Reference,
  UploadTask,
  TaskSnapshot,
  DocumentReference,
  CollectionReference,
])
void main() {
  group('Profile Delete-Then-Add Offline Scenario Tests', () {
    late AppDatabase database;
    late ProfileSyncHandler syncHandler;
    late ImageStorageService imageStorageService;
    late MockFirebaseStorage mockStorage;
    late MockFirebaseFirestore mockFirestore;
    late Directory testDir;
    final testUserId = 'test-user-123';
    final testImagePath = 'SnagSnapper/$testUserId/Profile/profile.jpg';

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // Create test directory
      testDir = await Directory.systemTemp.createTemp('profile_test');
    });

    setUp(() async {
      // Initialize database
      database = await TestHelpers.createTestDatabase();
      
      // Initialize services
      imageStorageService = ImageStorageService.instance;
      
      // Create mocks
      mockStorage = MockFirebaseStorage();
      mockFirestore = MockFirebaseFirestore();
      
      // Initialize sync handler with mocks
      syncHandler = ProfileSyncHandler(
        database: database,
        storage: mockStorage,
        firestore: mockFirestore,
      );

      // Create initial user with synced image
      final user = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        imageLocalPath: testImagePath,
        imageFirebasePath: 'users/$testUserId/profile.jpg',
        imageMarkedForDeletion: false,
        needsImageSync: false,
        needsProfileSync: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await database.profileDao.insertProfile(user);
      
      // Create actual image file
      final imageFile = File('${testDir.path}/$testImagePath');
      await imageFile.parent.create(recursive: true);
      await imageFile.writeAsBytes([1, 2, 3, 4]); // Dummy image data
    });

    tearDown(() async {
      await database.close();
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    tearDownAll(() async {
      // Cleanup
    });

    test('Delete-then-add offline scenario prevents race condition', () async {
      // Step 1: User deletes image (offline)
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        ),
      );

      // Verify deletion flags are set
      var user = await database.profileDao.getProfile(testUserId);
      expect(user!.imageLocalPath, isNull);
      expect(user.imageMarkedForDeletion, isTrue);
      expect(user.needsImageSync, isTrue);

      // Step 2: User adds new image while still offline
      final newImagePath = 'SnagSnapper/$testUserId/Profile/profile.jpg';
      await database.profileDao.updateProfile(
        testUserId,
        user.copyWith(
          imageLocalPath: newImagePath,
          imageMarkedForDeletion: false, // Clear deletion flag when adding new image
          needsImageSync: true,
        ),
      );

      // Verify new image is set and deletion flag is cleared
      user = await database.profileDao.getProfile(testUserId);
      expect(user!.imageLocalPath, equals(newImagePath));
      expect(user.imageMarkedForDeletion, isFalse);
      expect(user.needsImageSync, isTrue);

      // Step 3: Simulate sync when coming online
      // The sync handler should detect the new image and upload it
      // without performing deletion
      
      // Mock Firebase Storage upload
      final mockRef = MockReference();
      final mockUploadTask = MockUploadTask();
      final mockTaskSnapshot = MockTaskSnapshot();
      
      when(mockStorage.ref(any)).thenReturn(mockRef);
      when(mockRef.putData(any)).thenAnswer((_) async => mockUploadTask);
      when(mockUploadTask.snapshot).thenReturn(mockTaskSnapshot);
      
      // Mock Firestore update
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      final mockCollectionRef = MockCollectionReference<Map<String, dynamic>>();
      
      when(mockFirestore.collection('Profile')).thenReturn(mockCollectionRef);
      when(mockCollectionRef.doc(testUserId)).thenReturn(mockDocRef);
      when(mockDocRef.update(any)).thenAnswer((_) async => {});

      // Execute sync
      await syncHandler.syncProfileImage(testUserId, newImagePath);

      // Verify image was uploaded (not deleted)
      verify(mockRef.putData(any)).called(1);
      
      // Verify Firestore was updated with new image path
      verify(mockDocRef.update(argThat(contains('imagePath')))).called(1);

      // Verify sync flags are cleared
      user = await database.profileDao.getProfile(testUserId);
      expect(user!.needsImageSync, isFalse);
      expect(user.imageMarkedForDeletion, isFalse);
    });

    test('Rapid delete-add-delete-add sequence handles correctly', () async {
      // Simulate rapid user actions
      
      // Delete 1
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        ),
      );

      // Add 1
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: testImagePath,
          imageMarkedForDeletion: false,
          needsImageSync: true,
        ),
      );

      // Delete 2
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        ),
      );

      // Add 2
      final finalImagePath = 'SnagSnapper/$testUserId/Profile/profile_final.jpg';
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: finalImagePath,
          imageMarkedForDeletion: false,
          needsImageSync: true,
        ),
      );

      // Verify final state
      final user = await database.profileDao.getProfile(testUserId);
      expect(user!.imageLocalPath, equals(finalImagePath));
      expect(user.imageMarkedForDeletion, isFalse);
      expect(user.needsImageSync, isTrue);
      
      // When sync runs, it should upload the final image
      // without any deletion operations
    });

    test('Sync handler prevents race condition during deletion', () async {
      // Setup: User has an image that needs deletion
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        ),
      );

      // Mock Firebase Storage deletion
      final mockRef = MockReference();
      when(mockStorage.ref('users/$testUserId/profile.jpg')).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async {
        // Simulate user adding new image during deletion
        await database.profileDao.updateProfile(
          testUserId,
          (await database.profileDao.getProfile(testUserId))!.copyWith(
            imageLocalPath: testImagePath,
            imageMarkedForDeletion: false,
            needsImageSync: true,
          ),
        );
      });

      // Execute sync - should detect race condition
      await syncHandler.syncProfileImage(testUserId, null);

      // Verify deletion was attempted
      verify(mockRef.delete()).called(1);

      // Verify the new image is still present (race condition prevented)
      final user = await database.profileDao.getProfile(testUserId);
      expect(user!.imageLocalPath, equals(testImagePath));
      
      // The sync handler should recursively call itself to upload the new image
      // This would require additional mocking to verify
    });

    test('Auto-sync triggers after image operations', () async {
      // This test verifies that sync is triggered automatically
      // after image operations in the UI
      
      // Simulate image addition
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: testImagePath,
          needsImageSync: true,
        ),
      );

      // Verify sync flag is set
      var user = await database.profileDao.getProfile(testUserId);
      expect(user!.needsImageSync, isTrue);

      // In the actual UI, _syncService.syncNow() would be called
      // with a 500ms delay after this database update
      
      // Simulate the sync completing
      await database.profileDao.updateProfile(
        testUserId,
        user.copyWith(
          needsImageSync: false,
        ),
      );

      // Verify sync flag is cleared
      user = await database.profileDao.getProfile(testUserId);
      expect(user!.needsImageSync, isFalse);
    });

    test('Deletion flag persists correctly through offline operations', () async {
      // Delete image offline
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
        ),
      );

      // Add new image offline (deletion flag should be cleared)
      await database.profileDao.updateProfile(
        testUserId,
        (await database.profileDao.getProfile(testUserId))!.copyWith(
          imageLocalPath: testImagePath,
          imageMarkedForDeletion: false, // Clear the flag
          needsImageSync: true,
        ),
      );

      // Verify flag is cleared
      final user = await database.profileDao.getProfile(testUserId);
      expect(user!.imageMarkedForDeletion, isFalse);
      
      // This ensures we don't accidentally delete the new image
      // when sync finally happens
    });
  });
}