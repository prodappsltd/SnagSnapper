import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/profile_setup_screen.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';

// Mock classes for testing
class MockAppDatabase extends Mock implements AppDatabase {
  final MockProfileDao _mockProfileDao = MockProfileDao();
  
  @override
  ProfileDao get profileDao => _mockProfileDao;
}

class MockProfileDao extends Mock implements ProfileDao {
  AppUser? savedUser;
  
  @override
  Future<bool> insertProfile(AppUser user) async {
    print('MockProfileDao: Saving user ${user.id} with name ${user.name}');
    savedUser = user;
    return true; // Simulate successful save
  }
  
  @override
  Future<AppUser?> getProfile(String userId) async {
    print('MockProfileDao: Getting profile for $userId');
    return null; // No existing profile for new user
  }
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  User? _currentUser;
  
  void setCurrentUser(User? user) {
    _currentUser = user;
  }
  
  @override
  User? get currentUser => _currentUser;
}

class MockUser extends Mock implements User {
  final String _uid;
  final String? _email;
  
  MockUser({required String uid, String? email})
      : _uid = uid,
        _email = email;
  
  @override
  String get uid => _uid;
  
  @override
  String? get email => _email;
}

void main() {
  late MockAppDatabase mockDatabase;
  late MockProfileDao mockProfileDao;
  late MockFirebaseAuth mockAuth;
  
  setUp(() {
    mockDatabase = MockAppDatabase();
    mockProfileDao = mockDatabase._mockProfileDao;
    mockAuth = MockFirebaseAuth();
  });

  group('ProfileSetupScreen - Database Integration (TDD Green Phase)', () {
    testWidgets('INTEGRATION TEST 1: Should save profile to database with all PRD fields', 
      (WidgetTester tester) async {
      // Arrange - PRD 4.3.1: New user setup flow
      final mockUser = MockUser(
        uid: 'test-user-123',
        email: 'john.doe@example.com',
      );
      mockAuth.setCurrentUser(mockUser);
      
      // Build widget with mocked dependencies
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
          routes: {
            '/main': (context) => const Scaffold(
              body: Text('Main App'),
            ),
            '/login': (context) => const Scaffold(
              body: Text('Login Screen'),
            ),
          },
        ),
      );
      
      // Wait for initialization
      await tester.pumpAndSettle();
      
      // Act - Fill in all required fields per PRD 4.5.1
      // Find text fields and enter data
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4)); // Name, Job, Company, Phone
      
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.enterText(textFields.at(1), 'Site Manager');
      await tester.enterText(textFields.at(2), 'ABC Construction Ltd');
      await tester.enterText(textFields.at(3), '+447700900123');
      
      // Find and tap the submit button
      final submitButton = find.text('Complete Setup');
      expect(submitButton, findsOneWidget);
      
      // Scroll to make button visible if needed
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      // Wait for save operation
      await tester.pumpAndSettle();
      
      // Assert - Verify profile was saved with correct data
      final savedUser = mockProfileDao.savedUser;
      expect(savedUser, isNotNull, reason: 'Profile should be saved to database');
      
      // Verify all PRD required fields
      expect(savedUser!.id, equals('test-user-123'), reason: 'User ID should match Firebase UID');
      expect(savedUser.name, equals('John Doe'), reason: 'Name should be saved');
      expect(savedUser.email, equals('john.doe@example.com'), reason: 'Email from auth');
      expect(savedUser.jobTitle, equals('Site Manager'), reason: 'Job title should be saved');
      expect(savedUser.companyName, equals('ABC Construction Ltd'), reason: 'Company should be saved');
      expect(savedUser.phone, equals('+447700900123'), reason: 'Phone should be saved');
      
      // Verify sync flags per PRD 4.3.1c
      expect(savedUser.needsProfileSync, isTrue, reason: 'PRD: Must set needsProfileSync = true');
      expect(savedUser.needsImageSync, isFalse, reason: 'No image in setup');
      expect(savedUser.needsSignatureSync, isFalse, reason: 'No signature in setup');
      
      // Verify device ID was generated
      expect(savedUser.currentDeviceId, isNotNull, reason: 'Device ID must be generated');
      expect(savedUser.currentDeviceId!.isNotEmpty, isTrue, reason: 'Device ID must not be empty');
      
      // Verify timestamps
      expect(savedUser.createdAt, isNotNull, reason: 'Created timestamp required');
      expect(savedUser.updatedAt, isNotNull, reason: 'Updated timestamp required');
      
      // Verify default values
      expect(savedUser.dateFormat, equals('dd-MM-yyyy'), reason: 'Default date format per PRD');
      expect(savedUser.localVersion, equals(1), reason: 'Initial local version');
      expect(savedUser.firebaseVersion, equals(0), reason: 'Not synced to Firebase yet');
      
      // Should navigate to main app after successful save
      expect(find.text('Main App'), findsOneWidget, reason: 'Should navigate to main after save');
    });

    testWidgets('INTEGRATION TEST 2: Should validate required fields before saving', 
      (WidgetTester tester) async {
      // Arrange
      final mockUser = MockUser(uid: 'test-user-456', email: 'test@example.com');
      mockAuth.setCurrentUser(mockUser);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Act - Try to submit with empty fields
      final submitButton = find.text('Complete Setup');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      
      // Assert - Should not save with empty fields
      expect(mockProfileDao.savedUser, isNull, reason: 'Should not save with invalid data');
      expect(find.byType(ProfileSetupScreen), findsOneWidget, reason: 'Should stay on screen');
    });

    testWidgets('INTEGRATION TEST 3: Should show email from Firebase Auth', 
      (WidgetTester tester) async {
      // Arrange - User with email
      final mockUser = MockUser(
        uid: 'test-user-789',
        email: 'jane.smith@company.com',
      );
      mockAuth.setCurrentUser(mockUser);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Assert - Email should be displayed
      expect(find.text('jane.smith@company.com'), findsOneWidget, 
        reason: 'Should show authenticated user email');
    });

    testWidgets('INTEGRATION TEST 4: Should navigate to main if profile exists', 
      (WidgetTester tester) async {
      // Arrange - Existing user with profile
      final mockUser = MockUser(uid: 'existing-user', email: 'existing@example.com');
      mockAuth.setCurrentUser(mockUser);
      
      // Mock existing profile
      final existingProfile = AppUser(
        id: 'existing-user',
        name: 'Existing User',
        email: 'existing@example.com',
        phone: '07700900000',
        jobTitle: 'Manager',
        companyName: 'Existing Co',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Override getProfile to return existing profile
      when(mockProfileDao.getProfile('existing-user'))
          .thenAnswer((_) async => existingProfile);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
          routes: {
            '/main': (context) => const Scaffold(body: Text('Main App')),
          },
        ),
      );
      
      // Wait for initialization and navigation
      await tester.pumpAndSettle();
      
      // Assert - Should navigate directly to main app
      expect(find.text('Main App'), findsOneWidget, 
        reason: 'Should navigate to main app if profile exists');
      expect(find.byType(ProfileSetupScreen), findsNothing, 
        reason: 'Should not show setup screen');
    });

    testWidgets('INTEGRATION TEST 5: Should handle no authenticated user', 
      (WidgetTester tester) async {
      // Arrange - No authenticated user
      mockAuth.setCurrentUser(null);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
          routes: {
            '/login': (context) => const Scaffold(body: Text('Login Screen')),
          },
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Assert - Should redirect to login
      expect(find.text('Login Screen'), findsOneWidget, 
        reason: 'Should redirect to login if not authenticated');
    });

    testWidgets('INTEGRATION TEST 6: Should show loading state during save', 
      (WidgetTester tester) async {
      // Arrange
      final mockUser = MockUser(uid: 'test-loading', email: 'test@example.com');
      mockAuth.setCurrentUser(mockUser);
      
      // Override insertProfile to add delay
      mockProfileDao = MockProfileDao();
      when(mockDatabase.profileDao).thenReturn(mockProfileDao);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Fill fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Test User');
      await tester.enterText(textFields.at(1), 'Tester');
      await tester.enterText(textFields.at(2), 'Test Co');
      await tester.enterText(textFields.at(3), '07700900000');
      
      // Act - Tap submit
      final submitButton = find.text('Complete Setup');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      
      // Pump once to see loading state (don't settle)
      await tester.pump();
      
      // Assert - Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget, 
        reason: 'Should show loading during save');
      
      // Complete the save
      await tester.pumpAndSettle();
    });
  });

  group('ProfileSetupScreen - Field Validation Tests', () {
    testWidgets('VALIDATION TEST 1: Name must be 2-50 characters', 
      (WidgetTester tester) async {
      // Arrange
      final mockUser = MockUser(uid: 'test-validation', email: 'test@example.com');
      mockAuth.setCurrentUser(mockUser);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      final nameField = find.byType(TextFormField).first;
      
      // Test too short
      await tester.enterText(nameField, 'A');
      final submitButton = find.text('Complete Setup');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      
      // Should show validation error
      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      
      // Test valid length
      await tester.enterText(nameField, 'John Doe');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      
      // Error should be gone (but other fields still invalid)
      expect(find.text('Name must be at least 2 characters'), findsNothing);
    });

    testWidgets('VALIDATION TEST 2: Phone must be 7-15 digits', 
      (WidgetTester tester) async {
      // Arrange
      final mockUser = MockUser(uid: 'test-phone', email: 'test@example.com');
      mockAuth.setCurrentUser(mockUser);
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            database: mockDatabase,
            auth: mockAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Fill other fields with valid data
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Valid Name');
      await tester.enterText(textFields.at(1), 'Valid Job');
      await tester.enterText(textFields.at(2), 'Valid Company');
      
      // Test too short phone
      await tester.enterText(textFields.at(3), '123');
      
      final submitButton = find.text('Complete Setup');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      
      // Should show phone validation error
      expect(find.textContaining('at least 7'), findsOneWidget);
      
      // Should not save
      expect(mockProfileDao.savedUser, isNull);
    });
  });
}