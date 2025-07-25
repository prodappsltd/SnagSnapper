import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/main.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/splash_screen.dart';
import '../main_test.mocks.dart';
import '../test_helpers/firebase_mock_setup.dart';
import 'package:snagsnapper/Data/user.dart' as app_user;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockCP mockCP;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUpAll(() async {
    setupFirebaseAuthMocks();
  });

  setUp(() {
    mockCP = MockCP();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
  });
  
  // Helper function to create a test AppUser
  app_user.AppUser createTestAppUser({String? name, String? email}) {
    return app_user.AppUser(
      name: name ?? 'Test User',
      email: email ?? 'test@example.com',
    );
  }

  group('Complete Startup Flow Integration Tests', () {
    testWidgets('should complete full startup flow from splash to main menu', (WidgetTester tester) async {
      // Arrange: Set up successful initialization scenario
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Found');
      when(mockCP.getAppUser()).thenReturn(createTestAppUser(
        name: 'Test User',
        email: 'test@example.com',
      ));
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Launch the app
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Phase 1: Verify splash screen is shown
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Checking config...'), findsOneWidget);

      // Phase 2: Network check
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Checking internet connection...'), findsOneWidget);
      verify(mockCP.getNetworkStatus()).called(1);

      // Phase 3: App security verification
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Verifying app security...'), findsOneWidget);

      // Phase 4: Profile loading
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loading user profile...'), findsOneWidget);

      // Phase 5: Wait for minimum splash duration (10 seconds in dev)
      await tester.pump(const Duration(seconds: 10));

      // Phase 6: Navigation should occur
      await tester.pumpAndSettle();

      // Assert: Should be on main menu
      expect(find.text('Main Menu'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Verify all initialization steps were called
      verify(mockCP.getNetworkStatus()).called(1);
      verify(mockCP.loadProfileOfUser()).called(1);
      verify(mockCP.getAppUser()).called(1);
    });

    testWidgets('should handle error and retry flow correctly', (WidgetTester tester) async {
      // Arrange: First attempt fails, second succeeds
      int networkCallCount = 0;
      when(mockCP.getNetworkStatus()).thenAnswer((_) async {
        networkCallCount++;
        if (networkCallCount == 1) {
          return false; // First call fails
        }
        return true; // Second call succeeds
      });
      when(mockAuth.currentUser).thenReturn(null);
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Launch the app
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Wait for error state
      await tester.pumpAndSettle(const Duration(seconds: 11));

      // Assert: Error page is shown
      expect(find.byType(InternetErrorPage), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Act: Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Assert: Back to splash screen
      expect(find.byType(SplashScreen), findsOneWidget);

      // Wait for successful completion
      await tester.pumpAndSettle(const Duration(seconds: 11));

      // Assert: Should navigate to login (no authenticated user)
      expect(find.text('Login'), findsOneWidget);
      verify(mockCP.getNetworkStatus()).called(2);
    });

    testWidgets('should maintain state during configuration changes', (WidgetTester tester) async {
      // This test simulates what happens during device rotation or other config changes
      
      // Arrange
      when(mockCP.getNetworkStatus()).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 2));
        return true;
      });
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 2));
        return 'Profile Found';
      });
      when(mockCP.getAppUser()).thenReturn(createTestAppUser());
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Build initial widget
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Wait partway through initialization
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Simulate configuration change by rebuilding
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Verify initialization continues without restarting
      await tester.pumpAndSettle(const Duration(seconds: 12));
      
      // Should complete normally without duplicate network calls
      expect(find.text('Main Menu'), findsOneWidget);
      verify(mockCP.getNetworkStatus()).called(1); // Only called once
      verify(mockCP.loadProfileOfUser()).called(1); // Only called once
    });

    testWidgets('should handle rapid retry attempts correctly', (WidgetTester tester) async {
      // Arrange: All attempts fail
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => false);
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Launch app
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Wait for first error
      await tester.pumpAndSettle(const Duration(seconds: 11));
      expect(find.byType(InternetErrorPage), findsOneWidget);

      // Rapidly tap retry multiple times
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Retry'));

      // Wait for initialization to complete
      await tester.pumpAndSettle(const Duration(seconds: 11));

      // Should handle rapid retries gracefully
      expect(find.byType(InternetErrorPage), findsOneWidget);
      
      // Network check should be called once per successful retry initiation
      // Not necessarily 3 times due to state management preventing concurrent inits
      verify(mockCP.getNetworkStatus()).called(greaterThanOrEqualTo(2));
    });

    testWidgets('should handle profile not found flow correctly', (WidgetTester tester) async {
      // Arrange: User authenticated but no profile exists
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(true);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Not Found');
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Launch the app
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            routes: {
              '/mainMenu': (context) => const Scaffold(body: Text('Main Menu')),
              '/login': (context) => const Scaffold(body: Text('Login')),
              '/profileSetup': (context) => const Scaffold(body: Text('Profile Setup')),
            },
            home: const HomePage(),
          ),
        ),
      );

      // Phase 1: Splash screen initialization
      expect(find.byType(SplashScreen), findsOneWidget);

      // Phase 2: Complete initialization
      await tester.pumpAndSettle(const Duration(seconds: 11));

      // Assert: Should navigate to profile setup
      expect(find.text('Profile Setup'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Verify proper flow
      verify(mockCP.getNetworkStatus()).called(1);
      verify(mockCP.loadProfileOfUser()).called(1);
    });

    testWidgets('complete journey: signup → email verification → profile setup', (WidgetTester tester) async {
      // This test simulates the complete new user journey
      // Note: This is a simplified integration test without actual Firebase
      
      // Arrange initial state - no user
      when(mockCP.getNetworkStatus()).thenAnswer((_) async => true);
      when(mockAuth.currentUser).thenReturn(null);
      when(mockCP.seedColour).thenReturn(Colors.blue);
      when(mockCP.brightness).thenReturn(Brightness.light);

      // Act: Launch app
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const MySubApp(),
        ),
      );

      // Wait for navigation to login
      await tester.pumpAndSettle(const Duration(seconds: 11));
      expect(find.text('Login'), findsOneWidget);

      // Simulate user completing signup and email verification
      // Then returning with authenticated user but no profile
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.emailVerified).thenReturn(true);
      when(mockCP.loadProfileOfUser()).thenAnswer((_) async => 'Profile Not Found');

      // Rebuild to simulate app restart after email verification
      await tester.pumpWidget(
        ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: MaterialApp(
            routes: {
              '/mainMenu': (context) => const Scaffold(body: Text('Main Menu')),
              '/login': (context) => const Scaffold(body: Text('Login')),
              '/profileSetup': (context) => const Scaffold(body: Text('Profile Setup Screen')),
            },
            home: const HomePage(),
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle(const Duration(seconds: 11));

      // Assert: Should be on profile setup
      expect(find.text('Profile Setup Screen'), findsOneWidget);

      // Verify the complete flow
      verify(mockCP.getNetworkStatus()).called(greaterThanOrEqualTo(2));
      verify(mockCP.loadProfileOfUser()).called(1);
    });
  });
}