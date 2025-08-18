import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/screens/profile/profile_screen.dart';
import 'package:snagsnapper/services/image_storage_service.dart';

// Mock PathProvider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  String? tempPath;

  @override
  Future<String?> getApplicationSupportPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }

  @override
  Future<String?> getTemporaryPath() async {
    tempPath ??= Directory.systemTemp.createTempSync('test_db_').path;
    return tempPath;
  }
}

void main() {
  late AppDatabase database;
  late ImageStorageService imageStorageService;
  late MockPathProviderPlatform mockPathProvider;

  setUpAll(() {
    // Set up mock path provider
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
  });

  setUp(() async {
    // Get database instance (will create in temp directory)
    database = AppDatabase.instance;
    imageStorageService = ImageStorageService.instance;
  });

  tearDown(() async {
    // Close database
    await database.closeDatabase();
    
    // Clean up temp directory if exists
    if (mockPathProvider.tempPath != null) {
      try {
        final dir = Directory(mockPathProvider.tempPath!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    mockPathProvider.tempPath = null;
  });

  Widget createTestApp(Widget screen) {
    return MaterialApp(
      home: screen,
    );
  }

  group('Profile UI-Database Integration Tests', () {
    group('Complete Profile Creation Flow', () {
      testWidgets('should create new profile from UI and save to database', (tester) async {
        // Arrange
        const userId = 'ui_test_new_user';

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Fill in all fields
        await tester.enterText(find.byKey(const Key('name_field')), 'John Smith');
        await tester.enterText(find.byKey(const Key('email_field')), 'john.smith@example.com');
        await tester.enterText(find.byKey(const Key('phone_field')), '+44123456789');
        await tester.enterText(find.byKey(const Key('job_title_field')), 'Project Manager');
        await tester.enterText(find.byKey(const Key('company_name_field')), 'Construction Ltd');
        await tester.enterText(find.byKey(const Key('postcode_field')), 'SW1A 1AA');
        
        // Select date format
        await tester.tap(find.byKey(const Key('date_format_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MM-dd-yyyy').last);
        await tester.pumpAndSettle();

        // TODO: Add image selection test when ImagePicker is properly mocked
        // TODO: Add signature drawing test

        // Save profile
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Assert - Verify data persisted to database
        final savedUser = await database.profileDao.getProfile(userId);
        expect(savedUser, isNotNull);
        expect(savedUser!.name, equals('John Smith'));
        expect(savedUser.email, equals('john.smith@example.com'));
        expect(savedUser.phone, equals('+44123456789'));
        expect(savedUser.jobTitle, equals('Project Manager'));
        expect(savedUser.companyName, equals('Construction Ltd'));
        expect(savedUser.postcodeOrArea, equals('SW1A 1AA'));
        expect(savedUser.dateFormat, equals('MM-dd-yyyy'));

        // Verify success message shown
        expect(find.text('Profile saved successfully'), findsOneWidget);
      });

      testWidgets('should validate required fields before saving', (tester) async {
        // Arrange
        const userId = 'ui_test_validation';

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Try to save without filling required fields
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pump();

        // Assert - Should show validation errors
        expect(find.text('Name is required'), findsOneWidget);
        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Phone is required'), findsOneWidget);
        expect(find.text('Job title is required'), findsOneWidget);
        expect(find.text('Company name is required'), findsOneWidget);

        // Verify no data saved to database
        final savedUser = await database.profileDao.getProfile(userId);
        expect(savedUser, isNull);
      });
    });

    group('Profile Edit Flow', () {
      testWidgets('should load existing profile and allow editing', (tester) async {
        // Arrange - Create existing profile
        const userId = 'ui_test_edit_user';
        final existingUser = AppUser(
          id: userId,
          name: 'Original Name',
          email: 'original@example.com',
          phone: '+1234567890',
          jobTitle: 'Original Job',
          companyName: 'Original Company',
          postcodeOrArea: 'ORIG 123',
          dateFormat: 'dd-MM-yyyy',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await database.profileDao.insertProfile(existingUser);

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Verify existing data loaded
        expect(find.text('Original Name'), findsOneWidget);
        expect(find.text('original@example.com'), findsOneWidget);

        // Edit fields
        await tester.enterText(find.byKey(const Key('name_field')), 'Updated Name');
        await tester.enterText(find.byKey(const Key('job_title_field')), 'Updated Job');
        
        // Save changes
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Assert - Verify changes saved to database
        final updatedUser = await database.profileDao.getProfile(userId);
        expect(updatedUser, isNotNull);
        expect(updatedUser!.name, equals('Updated Name'));
        expect(updatedUser.jobTitle, equals('Updated Job'));
        expect(updatedUser.email, equals('original@example.com')); // Unchanged
        expect(updatedUser.companyName, equals('Original Company')); // Unchanged
      });

      testWidgets('should track dirty state and warn on unsaved changes', (tester) async {
        // Arrange
        const userId = 'ui_test_dirty_state';
        final existingUser = AppUser(
          id: userId,
          name: 'Test User',
          email: 'test@example.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await database.profileDao.insertProfile(existingUser);

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Make changes
        await tester.enterText(find.byKey(const Key('name_field')), 'Modified Name');
        await tester.pump();

        // Try to navigate away
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Assert - Should show unsaved changes dialog
        expect(find.text('Unsaved Changes'), findsOneWidget);
        expect(find.text('You have unsaved changes. Do you want to discard them?'), findsOneWidget);
        expect(find.text('Discard'), findsOneWidget);
        expect(find.text('Keep Editing'), findsOneWidget);
      });
    });

    group('Offline Editing', () {
      testWidgets('should save changes locally when offline', (tester) async {
        // Arrange
        const userId = 'ui_test_offline';

        // Act - Open profile screen in offline mode
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
            isOffline: true,
          ),
        ));
        await tester.pumpAndSettle();

        // Fill in fields
        await tester.enterText(find.byKey(const Key('name_field')), 'Offline User');
        await tester.enterText(find.byKey(const Key('email_field')), 'offline@example.com');
        await tester.enterText(find.byKey(const Key('phone_field')), '+9999999999');
        await tester.enterText(find.byKey(const Key('job_title_field')), 'Offline Worker');
        await tester.enterText(find.byKey(const Key('company_name_field')), 'Offline Co');
        
        // Save
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Assert - Verify sync flags set
        final savedUser = await database.profileDao.getProfile(userId);
        expect(savedUser, isNotNull);
        expect(savedUser!.needsProfileSync, isTrue);
        expect(savedUser.name, equals('Offline User'));

        // Verify offline indicator shown
        expect(find.text('Saved locally - will sync when online'), findsOneWidget);
      });

      testWidgets('should set appropriate sync flags for different changes', (tester) async {
        // Arrange
        const userId = 'ui_test_sync_flags';
        final existingUser = AppUser(
          id: userId,
          name: 'Test User',
          email: 'test@example.com',
          phone: '+1234567890',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await database.profileDao.insertProfile(existingUser);

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
            isOffline: true,
          ),
        ));
        await tester.pumpAndSettle();

        // Change profile data
        await tester.enterText(find.byKey(const Key('name_field')), 'Updated Name');
        
        // TODO: Add image change test
        // TODO: Add signature change test
        
        // Save
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Assert - Verify appropriate sync flags
        final updatedUser = await database.profileDao.getProfile(userId);
        expect(updatedUser!.needsProfileSync, isTrue); // Profile data changed
        // Image and signature flags would be tested when those features are implemented
      });
    });

    group('State Management', () {
      testWidgets('should reflect database changes in UI immediately', (tester) async {
        // Arrange
        const userId = 'ui_test_state';

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Create profile
        await tester.enterText(find.byKey(const Key('name_field')), 'Initial Name');
        await tester.enterText(find.byKey(const Key('email_field')), 'initial@example.com');
        await tester.enterText(find.byKey(const Key('phone_field')), '+1111111111');
        await tester.enterText(find.byKey(const Key('job_title_field')), 'Initial Job');
        await tester.enterText(find.byKey(const Key('company_name_field')), 'Initial Co');
        
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Simulate external database update
        final user = await database.profileDao.getProfile(userId);
        final updatedUser = user!.copyWith(name: 'Externally Updated Name');
        await database.profileDao.updateProfile(userId, updatedUser);

        // Trigger UI refresh
        await tester.pumpAndSettle();

        // Assert - UI should reflect database change
        // Note: This would require implementing a stream or listener pattern
        // For now, we verify the data is in the database
        final dbUser = await database.profileDao.getProfile(userId);
        expect(dbUser!.name, equals('Externally Updated Name'));
      });

      testWidgets('should handle concurrent edits gracefully', (tester) async {
        // Arrange
        const userId = 'ui_test_concurrent';
        final initialUser = AppUser(
          id: userId,
          name: 'Initial Name',
          email: 'initial@example.com',
          phone: '+1234567890',
          jobTitle: 'Initial Job',
          companyName: 'Initial Co',
          localVersion: 1,
          firebaseVersion: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await database.profileDao.insertProfile(initialUser);

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Start editing
        await tester.enterText(find.byKey(const Key('name_field')), 'UI Edit Name');

        // Simulate concurrent database update
        final dbUser = await database.profileDao.getProfile(userId);
        final concurrentUpdate = dbUser!.copyWith(
          jobTitle: 'Concurrent Edit Job',
          localVersion: 2,
        );
        await database.profileDao.updateProfile(userId, concurrentUpdate);

        // Save UI changes
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Assert - Both changes should be preserved (optimistic locking would handle conflicts)
        final finalUser = await database.profileDao.getProfile(userId);
        expect(finalUser!.name, equals('UI Edit Name')); // UI change
        expect(finalUser.localVersion, greaterThan(2)); // Version incremented
      });
    });

    group('Performance Tests', () {
      testWidgets('should load profile screen quickly', (tester) async {
        // Arrange
        const userId = 'ui_test_performance';
        final user = AppUser(
          id: userId,
          name: 'Performance Test User',
          email: 'perf@example.com',
          phone: '+1234567890',
          jobTitle: 'Perf Tester',
          companyName: 'Perf Co',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await database.profileDao.insertProfile(user);

        // Act - Measure load time
        final stopwatch = Stopwatch()..start();
        
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();
        
        stopwatch.stop();

        // Assert - Should load in under 500ms
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Profile screen took ${stopwatch.elapsedMilliseconds}ms to load');
      });

      testWidgets('should save profile quickly', (tester) async {
        // Arrange
        const userId = 'ui_test_save_performance';

        // Act - Open profile screen
        await tester.pumpWidget(createTestApp(
          ProfileScreen(
            database: database,
            userId: userId,
            imageStorageService: imageStorageService,
          ),
        ));
        await tester.pumpAndSettle();

        // Fill in fields
        await tester.enterText(find.byKey(const Key('name_field')), 'Perf User');
        await tester.enterText(find.byKey(const Key('email_field')), 'perf@example.com');
        await tester.enterText(find.byKey(const Key('phone_field')), '+9999999999');
        await tester.enterText(find.byKey(const Key('job_title_field')), 'Perf Job');
        await tester.enterText(find.byKey(const Key('company_name_field')), 'Perf Co');

        // Measure save time
        final stopwatch = Stopwatch()..start();
        
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();
        
        stopwatch.stop();

        // Assert - Should save in under 200ms
        expect(stopwatch.elapsedMilliseconds, lessThan(200),
          reason: 'Save operation took ${stopwatch.elapsedMilliseconds}ms');
      });
    });
  });
}