import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/unified_auth_screen.dart';

@GenerateMocks([CP])
import 'navigation_smoke_test.mocks.dart';

void main() {
  group('Navigation Smoke Tests', () {
    late MockCP mockCP;

    setUp(() {
      mockCP = MockCP();
      when(mockCP.brightness).thenReturn(Brightness.light);
      when(mockCP.themeType).thenReturn('orange');
      when(mockCP.changeBrightness(any)).thenReturn(null);
    });

    testWidgets('UnifiedAuthScreen navigation links work correctly', (WidgetTester tester) async {
      // This test verifies all navigation links on UnifiedAuthScreen are functional
      
      await tester.pumpWidget(MaterialApp(
        routes: {
          '/forgotPassword': (context) => const Scaffold(
            body: Center(child: Text('Forgot Password Screen')),
          ),
          '/themeSelector': (context) => const Scaffold(
            body: Center(child: Text('Theme Selector Screen')),
          ),
          '/checkEmail': (context) => const Scaffold(
            body: Center(child: Text('Check Email Screen')),
          ),
          '/profileSetup': (context) => const Scaffold(
            body: Center(child: Text('Profile Setup Screen')),
          ),
          '/mainMenu': (context) => const Scaffold(
            body: Center(child: Text('Main Menu Screen')),
          ),
        },
        home: ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const UnifiedAuthScreen(),
        ),
      ));
      
      // Test 1: Forgot Password navigation
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot Password Screen'), findsOneWidget);
      
      // Navigate back using Navigator.pop
      Navigator.of(tester.element(find.text('Forgot Password Screen'))).pop();
      await tester.pumpAndSettle();
      
      // Test 2: Theme Settings navigation
      final themeButton = find.text('Theme Settings');
      await tester.ensureVisible(themeButton);
      await tester.pumpAndSettle();
      await tester.tap(themeButton);
      await tester.pumpAndSettle();
      expect(find.text('Theme Selector Screen'), findsOneWidget);
      
      // Navigate back using Navigator.pop
      Navigator.of(tester.element(find.text('Theme Selector Screen'))).pop();
      await tester.pumpAndSettle();
      
      // Test 3: Verify we're back on UnifiedAuthScreen
      expect(find.byType(UnifiedAuthScreen), findsOneWidget);
      expect(find.text('Your ultimate LIVE SNAG SHARING app'), findsOneWidget);
    });
    
    testWidgets('Form validation shows appropriate error messages', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const UnifiedAuthScreen(),
        ),
      ));
      
      // Test empty email
      await tester.tap(find.widgetWithText(MaterialButton, 'Sign In'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
      
      // Test invalid email
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
      await tester.tap(find.widgetWithText(MaterialButton, 'Sign In'));
      await tester.pump();
      expect(find.text('Please enter a valid email'), findsOneWidget);
      
      // Test empty password
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), '');
      await tester.tap(find.widgetWithText(MaterialButton, 'Sign In'));
      await tester.pump();
      expect(find.text('Please enter your password'), findsOneWidget);
    });
    
    testWidgets('Auth mode toggle works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<CP>.value(
          value: mockCP,
          child: const UnifiedAuthScreen(),
        ),
      ));
      
      // Initially in login mode
      expect(find.widgetWithText(MaterialButton, 'Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsNothing);
      
      // Switch to signup mode
      final signUpToggle = find.widgetWithText(TextButton, 'Sign Up');
      await tester.ensureVisible(signUpToggle);
      await tester.pumpAndSettle();
      await tester.tap(signUpToggle);
      await tester.pumpAndSettle();
      
      // Should now be in signup mode
      expect(find.widgetWithText(MaterialButton, 'Sign Up'), findsOneWidget);
      expect(find.text("Already have an account?"), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsOneWidget);
      
      // Switch back to login mode
      final signInToggle = find.widgetWithText(TextButton, 'Sign In');
      await tester.ensureVisible(signInToggle);
      await tester.pumpAndSettle();
      await tester.tap(signInToggle);
      await tester.pumpAndSettle();
      
      // Should be back in login mode
      expect(find.widgetWithText(MaterialButton, 'Sign In'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm Password'), findsNothing);
    });
  });
}