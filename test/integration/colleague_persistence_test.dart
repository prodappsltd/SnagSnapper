import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Colleague Persistence Tests', () {
    late AppDatabase database;
    late ProfileDao profileDao;
    const testUserId = 'test_user_123';

    setUp(() async {
      // Create in-memory database for testing
      database = TestHelpers.createTestDatabase();
      profileDao = database.profileDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('should persist colleagues as an array without overwriting', () async {
      // Create initial user with one colleague
      final colleague1 = Colleague(
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        uniqueID: 'colleague_1',
      );

      final initialUser = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        listOfALLColleagues: [colleague1],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create the profile
      final created = await profileDao.insertProfile(initialUser);
      expect(created, isTrue);

      // Verify colleague was saved
      final savedUser = await profileDao.getProfile(testUserId);
      expect(savedUser, isNotNull);
      expect(savedUser!.listOfALLColleagues, isNotNull);
      expect(savedUser.listOfALLColleagues!.length, 1);
      expect(savedUser.listOfALLColleagues![0].name, 'John Doe');
      expect(savedUser.listOfALLColleagues![0].email, 'john@example.com');

      // Add a second colleague without overwriting the first
      final colleague2 = Colleague(
        name: 'Jane Smith',
        email: 'jane@example.com',
        phone: '+9876543210',
        uniqueID: 'colleague_2',
      );

      // Create a new list with both colleagues
      final updatedColleagues = [...savedUser.listOfALLColleagues!, colleague2];
      final updatedUser = AppUser(
        id: savedUser.id,
        name: savedUser.name,
        email: savedUser.email,
        phone: savedUser.phone,
        companyName: savedUser.companyName,
        listOfALLColleagues: updatedColleagues,
        jobTitle: savedUser.jobTitle,
        postcodeOrArea: savedUser.postcodeOrArea,
        dateFormat: savedUser.dateFormat,
        imageLocalPath: savedUser.imageLocalPath,
        imageFirebasePath: savedUser.imageFirebasePath,
        signatureLocalPath: savedUser.signatureLocalPath,
        signatureFirebasePath: savedUser.signatureFirebasePath,
        createdAt: savedUser.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update the profile
      final updated = await profileDao.updateProfile(testUserId, updatedUser);
      expect(updated, isTrue);

      // Verify both colleagues are present
      final finalUser = await profileDao.getProfile(testUserId);
      expect(finalUser, isNotNull);
      expect(finalUser!.listOfALLColleagues, isNotNull);
      expect(finalUser.listOfALLColleagues!.length, 2);
      
      // Check first colleague is still there
      expect(finalUser.listOfALLColleagues![0].name, 'John Doe');
      expect(finalUser.listOfALLColleagues![0].email, 'john@example.com');
      
      // Check second colleague was added
      expect(finalUser.listOfALLColleagues![1].name, 'Jane Smith');
      expect(finalUser.listOfALLColleagues![1].email, 'jane@example.com');
    });

    test('should handle colleague JSON serialization correctly', () async {
      // Create colleagues with lowercase field names
      final colleagues = [
        Colleague(
          name: 'Alice Brown',
          email: 'alice@example.com',
          phone: '+1111111111',
          uniqueID: 'colleague_a',
        ),
        Colleague(
          name: 'Bob Wilson',
          email: 'bob@example.com',
          phone: null, // Test optional field
          uniqueID: 'colleague_b',
        ),
      ];

      final user = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        listOfALLColleagues: colleagues,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create and save
      await profileDao.insertProfile(user);

      // Retrieve and verify
      final savedUser = await profileDao.getProfile(testUserId);
      expect(savedUser, isNotNull);
      expect(savedUser!.listOfALLColleagues, isNotNull);
      expect(savedUser.listOfALLColleagues!.length, 2);

      // Verify field names are correctly handled
      final colleague1 = savedUser.listOfALLColleagues![0];
      expect(colleague1.name, 'Alice Brown');
      expect(colleague1.email, 'alice@example.com');
      expect(colleague1.phone, '+1111111111');
      expect(colleague1.uniqueID, 'colleague_a');

      final colleague2 = savedUser.listOfALLColleagues![1];
      expect(colleague2.name, 'Bob Wilson');
      expect(colleague2.email, 'bob@example.com');
      expect(colleague2.phone, isNull); // Optional field should be null
      expect(colleague2.uniqueID, 'colleague_b');
    });

    test('should handle empty colleagues list', () async {
      final user = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        listOfALLColleagues: null, // No colleagues
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await profileDao.insertProfile(user);

      final savedUser = await profileDao.getProfile(testUserId);
      expect(savedUser, isNotNull);
      expect(savedUser!.listOfALLColleagues, isNull);
    });

    test('should remove colleagues correctly', () async {
      // Start with 3 colleagues
      final colleagues = [
        Colleague(
          name: 'Person One',
          email: 'one@example.com',
          uniqueID: 'id_1',
        ),
        Colleague(
          name: 'Person Two',
          email: 'two@example.com',
          uniqueID: 'id_2',
        ),
        Colleague(
          name: 'Person Three',
          email: 'three@example.com',
          uniqueID: 'id_3',
        ),
      ];

      final user = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        listOfALLColleagues: colleagues,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await profileDao.insertProfile(user);

      // Remove the middle colleague
      final savedUser = await profileDao.getProfile(testUserId);
      final updatedColleagues = [...savedUser!.listOfALLColleagues!];
      updatedColleagues.removeAt(1);

      final updatedUser = AppUser(
        id: savedUser.id,
        name: savedUser.name,
        email: savedUser.email,
        phone: savedUser.phone,
        companyName: savedUser.companyName,
        listOfALLColleagues: updatedColleagues,
        jobTitle: savedUser.jobTitle,
        postcodeOrArea: savedUser.postcodeOrArea,
        dateFormat: savedUser.dateFormat,
        imageLocalPath: savedUser.imageLocalPath,
        imageFirebasePath: savedUser.imageFirebasePath,
        signatureLocalPath: savedUser.signatureLocalPath,
        signatureFirebasePath: savedUser.signatureFirebasePath,
        createdAt: savedUser.createdAt,
        updatedAt: DateTime.now(),
      );

      await profileDao.updateProfile(testUserId, updatedUser);

      // Verify removal
      final finalUser = await profileDao.getProfile(testUserId);
      expect(finalUser!.listOfALLColleagues!.length, 2);
      expect(finalUser.listOfALLColleagues![0].name, 'Person One');
      expect(finalUser.listOfALLColleagues![1].name, 'Person Three');
    });

    test('should maintain colleague order', () async {
      final colleagues = List.generate(5, (i) => Colleague(
        name: 'Person $i',
        email: 'person$i@example.com',
        uniqueID: 'id_$i',
      ));

      final user = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        listOfALLColleagues: colleagues,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await profileDao.insertProfile(user);

      // Retrieve and verify order
      final savedUser = await profileDao.getProfile(testUserId);
      expect(savedUser!.listOfALLColleagues!.length, 5);
      
      for (int i = 0; i < 5; i++) {
        expect(savedUser.listOfALLColleagues![i].name, 'Person $i');
        expect(savedUser.listOfALLColleagues![i].email, 'person$i@example.com');
      }
    });
  });
}