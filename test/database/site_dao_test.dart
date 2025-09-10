import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  
  setUp(() async {
    // Create in-memory database for testing
    database = AppDatabase.instance;
  });

  tearDown(() async {
    // Clean up
    await database.close();
  });

  group('SiteDao Tests', () {
    test('Create and retrieve site', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'Test Site',
        companyName: 'Test Company',
        address: '123 Test Street',
        contactPerson: 'John Doe',
        contactPhone: '+1234567890',
      );

      // Act
      await database.siteDao.insertSite(site);
      final retrievedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(retrievedSite, isNotNull);
      expect(retrievedSite!.id, equals(siteId));
      expect(retrievedSite.name, equals('Test Site'));
      expect(retrievedSite.companyName, equals('Test Company'));
      expect(retrievedSite.address, equals('123 Test Street'));
      expect(retrievedSite.contactPerson, equals('John Doe'));
      expect(retrievedSite.contactPhone, equals('+1234567890'));
    });

    test('Update site information', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'Original Name',
      );
      await database.siteDao.insertSite(site);

      // Act
      final updatedSite = site.copyWith(
        name: 'Updated Name',
        companyName: 'New Company',
      );
      await database.siteDao.updateSite(updatedSite);
      final retrievedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(retrievedSite!.name, equals('Updated Name'));
      expect(retrievedSite.companyName, equals('New Company'));
      expect(retrievedSite.localVersion, greaterThan(site.localVersion));
    });

    test('Share site with user', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'owner-uid',
        ownerEmail: 'owner@example.com',
        name: 'Shared Site',
      );
      await database.siteDao.insertSite(site);

      // Act
      await database.siteDao.addUserToSite(
        siteId,
        'colleague@example.com',
        'CONTRIBUTOR',
      );
      final retrievedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(retrievedSite!.sharedWith.containsKey('colleague@example.com'), isTrue);
      expect(retrievedSite.sharedWith['colleague@example.com'], equals('CONTRIBUTOR'));
    });

    test('Get sites for different users', () async {
      // Arrange
      final ownedSiteId = const Uuid().v4();
      final sharedSiteId = const Uuid().v4();
      
      // Create owned site
      final ownedSite = Site.create(
        id: ownedSiteId,
        ownerUID: 'user1-uid',
        ownerEmail: 'user1@example.com',
        name: 'Owned Site',
      );
      
      // Create shared site
      final sharedSite = Site.create(
        id: sharedSiteId,
        ownerUID: 'user2-uid',
        ownerEmail: 'user2@example.com',
        name: 'Shared Site',
      );
      
      await database.siteDao.insertSite(ownedSite);
      await database.siteDao.insertSite(sharedSite);
      
      // Share the second site with user1
      await database.siteDao.addUserToSite(
        sharedSiteId,
        'user1@example.com',
        'VIEW',
      );

      // Act
      final ownedSites = await database.siteDao.getOwnedSites('user1@example.com');
      final sharedSites = await database.siteDao.getSharedSites('user1@example.com');
      final allSites = await database.siteDao.getAllSites('user1@example.com');

      // Assert
      expect(ownedSites.length, equals(1));
      expect(ownedSites.first.name, equals('Owned Site'));
      
      expect(sharedSites.length, equals(1));
      expect(sharedSites.first.name, equals('Shared Site'));
      
      expect(allSites.length, equals(2));
    });

    test('Handle empty categories correctly', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'Test Site',
      );

      // Act
      await database.siteDao.insertSite(site);
      final retrievedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(retrievedSite!.snagCategories, isEmpty);
      
      // Add a category
      await database.siteDao.addSiteCategory(siteId, 1, 'Electrical');
      final updatedSite = await database.siteDao.getSiteById(siteId);
      
      expect(updatedSite!.snagCategories.length, equals(1));
      expect(updatedSite.snagCategories[1], equals('Electrical'));
    });

    test('Soft delete and cleanup', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'To Delete',
      );
      await database.siteDao.insertSite(site);

      // Act - Mark for deletion
      await database.siteDao.markSiteForDeletion(siteId);
      final markedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(markedSite!.markedForDeletion, isTrue);
      expect(markedSite.deletionDate, isNotNull);
      expect(markedSite.scheduledDeletionDate, isNotNull);
      
      // Site should still exist
      expect(markedSite.name, equals('To Delete'));
    });

    test('Update site statistics', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'Test Site',
      );
      await database.siteDao.insertSite(site);

      // Act
      await database.siteDao.updateSiteStatistics(
        siteId,
        totalSnags: 10,
        openSnags: 7,
        closedSnags: 3,
      );
      final updatedSite = await database.siteDao.getSiteById(siteId);

      // Assert
      expect(updatedSite!.totalSnags, equals(10));
      expect(updatedSite.openSnags, equals(7));
      expect(updatedSite.closedSnags, equals(3));
    });

    test('Watch site changes', () async {
      // Arrange
      final siteId = const Uuid().v4();
      final site = Site.create(
        id: siteId,
        ownerUID: 'test-uid',
        ownerEmail: 'test@example.com',
        name: 'Original Name',
      );

      // Act & Assert
      final stream = database.siteDao.watchSite(siteId);
      
      // Insert site
      await database.siteDao.insertSite(site);
      
      // Update site
      final updatedSite = site.copyWith(name: 'Updated Name');
      await database.siteDao.updateSite(updatedSite);
      
      // Stream should emit both states
      await expectLater(
        stream,
        emitsInOrder([
          isNull, // Initial state
          isA<Site>().having((s) => s.name, 'name', 'Original Name'),
          isA<Site>().having((s) => s.name, 'name', 'Updated Name'),
        ]),
      );
    });
  });
}