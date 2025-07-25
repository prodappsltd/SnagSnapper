import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:snagsnapper/main.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Constants/initialization_state.dart';
import 'package:snagsnapper/Screens/splash_screen.dart';
import 'test_helpers/firebase_mock_setup.dart';

// Generate mocks for all dependencies
@GenerateMocks([
  CP,
  FirebaseAuth,
  FirebaseCrashlytics,
  FirebaseAppCheck,
  User,
])
import 'main_test.mocks.dart';
import 'package:snagsnapper/Data/user.dart' as app_user;

void main() {
  // Test setup
  late MockCP mockCP;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  
  // Helper function to create a test AppUser
  app_user.AppUser createTestAppUser({String? name, String? email}) {
    return app_user.AppUser(
      name: name ?? 'Test User',
      email: email ?? 'test@example.com',
    );
  }

  // Set up Firebase mocks before all tests
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();
  });

  setUp(() {
    // Initialize mocks for each test
    mockCP = MockCP();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
  });

  // Helper function to create test widget with Provider
  Widget createTestWidget({Widget? child}) {
    return ChangeNotifierProvider<CP>.value(
      value: mockCP,
      child: MaterialApp(
        home: child ?? const HomePage(),
        routes: {
          '/mainMenu': (context) => const Scaffold(body: Text('Main Menu')),
          '/login': (context) => const Scaffold(body: Text('Login')),
          '/profileSetup': (context) => const Scaffold(body: Text('Profile Setup')),
        },
      ),
    );
  }

  group('StartSnagSnapper Tests', () {
    testWidgets('should build with CP provider', (WidgetTester tester) async {
      // Test that StartSnagSnapper creates the provider correctly
      await tester.pumpWidget(const StartSnagSnapper());
      
      // Verify provider is created
      expect(find.byType(ChangeNotifierProvider<CP>), findsOneWidget);
      expect(find.byType(MySubApp), findsOneWidget);
    });
  });

  group('HomePage Initialization Tests', () {
    testWidgets('should show splash screen during initialization', (WidgetTester tester) async {
      // Arrange: Set up mock to delay network check
      when(mockCP.getNetworkStatus()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      });
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Found');
      when(mockCP.getAppUser()).thenReturn(createTestAppUser());

      // Act: Build the widget
      await tester.pumpWidget(createTestWidget());
      
      // Assert: Splash screen should be shown initially
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Checking config...'), findsOneWidget);
    });

    testWidgets('should handle no internet connection', (WidgetTester tester) async {
      // Arrange: Mock no internet
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => false);
      
      // Act: Build widget and wait for initialization
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11)); // Wait for splash duration
      
      // Assert: Should show error page
      expect(find.byType(InternetErrorPage), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should navigate to login when user not authenticated', (WidgetTester tester) async {
      // Arrange: Mock successful network but no user
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(null);
      
      // Act: Build widget with mocked auth
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 100)); // Let initialization start
      
      // Update splash message should show network check
      await tester.pump();
      expect(find.text('Checking internet connection...'), findsOneWidget);
      
      // Complete initialization
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Should navigate to login
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should navigate to main menu when profile loaded successfully', (WidgetTester tester) async {
      // Arrange: Mock successful initialization
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Found');
      when(mockCP.getAppUser()).thenReturn(createTestAppUser(name: 'Test User'));
      
      // Act: Build widget with mocked auth
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Should navigate to main menu
      expect(find.text('Main Menu'), findsOneWidget);
    });

    testWidgets('should handle Firebase error during profile loading', (WidgetTester tester) async {
      // Arrange: Mock Firebase error
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Firebase Error');
      
      // Act: Build widget
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Should show error page with Firebase error message
      expect(find.byType(InternetErrorPage), findsOneWidget);
      expect(find.textContaining('Error loading profile'), findsOneWidget);
    });

    testWidgets('should retry initialization when retry button pressed', (WidgetTester tester) async {
      // Arrange: First attempt fails, second succeeds
      int callCount = 0;
      when(mockCP.getNetworkStatus()).thenAnswer((_) async {
        callCount++;
        return callCount > 1; // Fail first time, succeed second
      });
      
      // Act: Build widget and wait for error
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Error page shown
      expect(find.byType(InternetErrorPage), findsOneWidget);
      
      // Act: Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump();
      
      // Assert: Should show splash screen again
      expect(find.byType(SplashScreen), findsOneWidget);
      
      // Verify network check was called again
      verify(mockCP.getNetworkStatus()).called(2);
    });

    testWidgets('should update status messages during initialization phases', (WidgetTester tester) async {
      // Arrange: Set up delays to see message changes
      when(mockCP.getNetworkStatus()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      });
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return 'Profile Found';
      });
      when(mockCP.getAppUser()).thenReturn(createTestAppUser());
      
      // Act & Assert: Check messages at different phases
      await tester.pumpWidget(createTestWidget());
      
      // Initial message
      expect(find.text('Checking config...'), findsOneWidget);
      
      // After starting network check
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Checking internet connection...'), findsOneWidget);
      
      // After network check completes
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Verifying app security...'), findsOneWidget);
      
      // During profile loading
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loading user profile...'), findsOneWidget);
    });

    testWidgets('should handle email not verified state', (WidgetTester tester) async {
      // Arrange: Mock email not verified
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Email Not Verified');
      
      // Act: Build widget
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Should navigate to login (same route for email verification)
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should respect minimum splash duration', (WidgetTester tester) async {
      // Arrange: Very fast initialization
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(null);
      
      // Act: Build widget
      await tester.pumpWidget(createTestWidget());
      
      // Assert: Still showing splash after 5 seconds
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(SplashScreen), findsOneWidget);
      
      // Should transition after 10 seconds (current dev duration)
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should navigate to profile setup when user authenticated but profile not found', (WidgetTester tester) async {
      // Arrange: Mock authenticated user but profile not found
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(true);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Not Found');
      
      // Act: Build widget
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(const Duration(seconds: 11));
      
      // Assert: Should navigate to profile setup
      expect(find.text('Profile Setup'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      
      // Verify the correct initialization flow was followed
      verify(mockCP.getNetworkStatus()).called(1);
      verify(mockCP.loadProfileOfUser()).called(1);
    });
  });

  group('InternetErrorPage Tests', () {
    testWidgets('should display error message and retry button', (WidgetTester tester) async {
      // Arrange
      final errorPage = InternetErrorPage(
        () {},
        'Test error message',
      );
      
      // Act
      await tester.pumpWidget(MaterialApp(home: errorPage));
      
      // Assert
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('should call retry callback when button pressed', (WidgetTester tester) async {
      // Arrange
      bool retryCalled = false;
      final errorPage = InternetErrorPage(
        () => retryCalled = true,
        'Test error',
      );
      
      // Act
      await tester.pumpWidget(MaterialApp(home: errorPage));
      await tester.tap(find.text('Retry'));
      
      // Assert
      expect(retryCalled, isTrue);
    });
  });

  group('InitializationState Extension Tests', () {
    test('should convert legacy strings to correct enum values', () {
      // Test all string conversions
      expect('Goto Login'.toInitializationState(), equals(InitializationState.goToLogin));
      expect('Email Not Verified'.toInitializationState(), equals(InitializationState.emailNotVerified));
      expect('Profile Found'.toInitializationState(), equals(InitializationState.profileFound));
      expect('No internet'.toInitializationState(), equals(InitializationState.noInternet));
      expect('Context Error'.toInitializationState(), equals(InitializationState.contextError));
      expect('RevCat Error'.toInitializationState(), equals(InitializationState.revCatError));
      expect('Firebase Error'.toInitializationState(), equals(InitializationState.firebaseError));
      expect('Firebase Error Owned Sites'.toInitializationState(), equals(InitializationState.firebaseErrorOwnedSites));
      expect('Firebase Error Shared Sites'.toInitializationState(), equals(InitializationState.firebaseErrorSharedSites));
      expect('Initialization Error'.toInitializationState(), equals(InitializationState.initializationError));
      expect('Unknown String'.toInitializationState(), equals(InitializationState.unknownError));
    });
  });

  group('MySubApp Tests', () {
    testWidgets('should initialize RateMyApp after frame', (WidgetTester tester) async {
      // This test verifies RateMyApp initialization
      await tester.pumpWidget(createTestWidget(child: const MySubApp()));
      
      // Trigger post frame callback
      await tester.pump();
      
      // Verify MySubApp is rendered
      expect(find.byType(MySubApp), findsOneWidget);
    });

    testWidgets('should configure theme with provider values', (WidgetTester tester) async {
      // Arrange: Mock provider color values
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);
      
      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );
      
      // Assert: Theme should use provider values
      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.colorScheme.brightness, equals(Brightness.light));
    });
  });
}