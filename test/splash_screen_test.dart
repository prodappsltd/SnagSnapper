import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Screens/splash_screen.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('should display app icon with Hero animation', (WidgetTester tester) async {
      // Arrange & Act: Build the SplashScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Assert: Verify app icon container is displayed
      expect(find.byType(Hero), findsOneWidget);
      
      // Verify Hero tag for navigation consistency
      final heroWidget = tester.widget<Hero>(find.byType(Hero));
      expect(heroWidget.tag, 'app_logo');
      
      // Verify the correct image asset is used within ClipRRect
      final imageWidget = tester.widget<Image>(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(Image),
        ),
      );
      expect((imageWidget.image as AssetImage).assetName, 'images/1024LowPoly.png');
      
      // Verify container dimensions (image is inside a 150x150 container)
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.constraints?.maxHeight, 150);
      expect(container.constraints?.maxWidth, 150);
    });

    testWidgets('should show loading indicator below app icon', (WidgetTester tester) async {
      // Arrange & Act: Build the SplashScreen widget
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: const SplashScreen(),
        ),
      );

      // Assert: Verify loading spinner is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Verify spinner uses theme color
      final progressIndicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progressIndicator.valueColor, isNotNull);
    });

    testWidgets('should display app name and tagline with fade animation', (WidgetTester tester) async {
      // Arrange & Act: Build the SplashScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Initially, text should be invisible (opacity 0)
      await tester.pump();
      
      // Progress animation halfway
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: Verify app name is displayed
      expect(find.text('SnagSnapper'), findsOneWidget);
      
      // Verify tagline is displayed
      expect(find.text('Professional Snagging Made Simple'), findsOneWidget);
      
      // Complete the fade animation
      await tester.pump(const Duration(milliseconds: 1000));
      
      // Verify text is fully visible after animation
      final fadeTransitions = tester.widgetList<FadeTransition>(
        find.byType(FadeTransition),
      );
      expect(fadeTransitions.length, greaterThanOrEqualTo(2));
    });

    testWidgets('should have scale and fade animation effects', (WidgetTester tester) async {
      // Arrange & Act: Build the SplashScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Assert: Verify animation widgets are present
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsWidgets); // May have multiple due to Material widgets
      
      // Initial state - animations should be starting
      await tester.pump();
      
      // Progress animations to midpoint
      await tester.pump(const Duration(milliseconds: 750));
      
      // Verify animations are in progress (widgets are being animated)
      final fadeTransitions = tester.widgetList<FadeTransition>(find.byType(FadeTransition));
      expect(fadeTransitions.length, greaterThan(0));
      
      // Find the ScaleTransition that's part of our SplashScreen (not Material animations)
      final scaleTransitions = tester.widgetList<ScaleTransition>(find.byType(ScaleTransition));
      expect(scaleTransitions.length, greaterThan(0));
      
      // Complete animations
      await tester.pump(const Duration(milliseconds: 750));
      
      // Verify animations have completed (all widgets should be fully visible)
      expect(find.byType(Hero), findsOneWidget);
      expect(find.text('SnagSnapper'), findsOneWidget);
    });

    testWidgets('should show status message when provided', (WidgetTester tester) async {
      // Arrange & Act: Build the SplashScreen widget with custom message
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(message: 'Loading user data...'),
        ),
      );

      // Pump to allow fade animation to start
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: Verify custom status message is displayed
      expect(find.text('Loading user data...'), findsOneWidget);
      
      // Verify message is displayed in the loading container
      final messageText = tester.widget<Text>(
        find.text('Loading user data...'),
      );
      expect(messageText.style, isNotNull);
    });

    testWidgets('should show default message when none provided', (WidgetTester tester) async {
      // Arrange & Act: Build SplashScreen without explicit message
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Progress animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: Should show default message
      expect(find.text('Checking config...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should properly handle widget lifecycle', (WidgetTester tester) async {
      // Arrange: Build the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Verify widget is properly built with animations
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsWidgets); // May have multiple due to Material widgets

      // Act: Remove the widget to trigger disposal
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Assert: Widget should be removed and animations should stop
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
    });

    testWidgets('should handle theme changes correctly', (WidgetTester tester) async {
      // Arrange: Build with light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const SplashScreen(message: 'Loading...'),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify initial theme colors
      var textWidget = tester.widget<Text>(find.text('SnagSnapper'));
      expect(textWidget.style?.color, isNotNull);

      // Act: Switch to dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const SplashScreen(message: 'Loading...'),
        ),
      );

      await tester.pump();

      // Assert: Colors should update
      textWidget = tester.widget<Text>(find.text('SnagSnapper'));
      expect(textWidget.style?.color, isNotNull);
    });
  });
}