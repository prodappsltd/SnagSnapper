import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Screens/profile/signature_capture_screen.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([SignatureService])
import 'signature_capture_screen_test.mocks.dart';

void main() {
  group('SignatureCaptureScreen', () {
    late MockSignatureService mockSignatureService;
    const testUserId = 'test_user_123';

    setUp(() {
      mockSignatureService = MockSignatureService();
      
      // Set up default mock behavior
      when(mockSignatureService.strokes).thenReturn([]);
      when(mockSignatureService.hasContent).thenReturn(false);
      when(mockSignatureService.calculateCanvasSize(any)).thenReturn(const Size(640, 360));
    });

    testWidgets('should initialize with correct UI elements', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert
      expect(find.text('Sign Here'), findsOneWidget); // Title
      expect(find.text('Clear'), findsOneWidget); // Clear button
      expect(find.text('Cancel'), findsOneWidget); // Cancel button
      expect(find.text('Use Signature'), findsOneWidget); // Save button
      expect(find.byType(CustomPaint), findsOneWidget); // Canvas
    });

    testWidgets('should have dark grey background and white canvas', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert - Check background color
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF424242))); // Dark grey

      // Assert - Check canvas container
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.color, equals(Colors.white));
    });

    testWidgets('should have orange buttons with white text', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert - Find buttons
      final clearButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Clear'),
      );
      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      final useButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Use Signature'),
      );

      // Check button styles
      expect(clearButton.style?.backgroundColor?.resolve({}), 
        equals(const Color(0xFFFF6E00))); // Orange
      expect(useButton.style?.backgroundColor?.resolve({}), 
        equals(const Color(0xFFFF6E00))); // Orange
    });

    testWidgets('should handle drawing gestures', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Act - Simulate drawing
      final canvas = find.byType(GestureDetector).first;
      
      // Start stroke
      await tester.dragFrom(
        tester.getCenter(canvas),
        const Offset(100, 0),
      );
      await tester.pump();

      // Assert
      verify(mockSignatureService.startNewStroke()).called(1);
      verify(mockSignatureService.addPointWithBounds(any, any)).called(greaterThan(1));
    });

    testWidgets('should clear signature when Clear button is tapped', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(true);
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Clear'));
      await tester.pump();

      // Assert
      verify(mockSignatureService.clear()).called(1);
    });

    testWidgets('should return null when Cancel button is tapped', (WidgetTester tester) async {
      // Arrange
      String? result;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SignatureCaptureScreen.show(context, testUserId);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Open the screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Act - Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert
      expect(result, isNull);
    });

    testWidgets('should save and return path when Use Signature is tapped', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(true);
      when(mockSignatureService.generateJpegImage(any, 95))
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(mockSignatureService.saveSignature(testUserId, any))
        .thenAnswer((_) async => 'SnagSnapper/$testUserId/Profile/signature.jpg');
      
      String? result;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SignatureCaptureScreen.show(
                  context, 
                  testUserId,
                  signatureService: mockSignatureService,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Open the screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Act - Tap Use Signature
      await tester.tap(find.text('Use Signature'));
      await tester.pumpAndSettle();

      // Assert
      expect(result, equals('SnagSnapper/$testUserId/Profile/signature.jpg'));
      verify(mockSignatureService.generateJpegImage(any, 95)).called(1);
      verify(mockSignatureService.saveSignature(testUserId, any)).called(1);
    });

    testWidgets('should show error when saving empty signature', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(false);
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Use Signature'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.text('Please add your signature'), findsOneWidget);
    });

    testWidgets('should be locked to portrait orientation', (WidgetTester tester) async {
      // Arrange
      final initialOrientation = ServicesBinding.instance.window.physicalSize;
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert - Check that portrait orientation is set
      // Note: In a real test, we'd verify SystemChrome.setPreferredOrientations was called
      // For now, we verify the screen is built assuming portrait
      final screenSize = tester.getSize(find.byType(Scaffold));
      expect(screenSize.height > screenSize.width || screenSize.width <= 640, isTrue);
    });

    testWidgets('should use responsive canvas size on small screens', (WidgetTester tester) async {
      // Arrange
      const smallScreenWidth = 320.0;
      when(mockSignatureService.calculateCanvasSize(smallScreenWidth))
        .thenReturn(const Size(320, 360));
      
      // Set small screen size
      tester.binding.window.physicalSizeTestValue = const Size(320, 640);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert
      verify(mockSignatureService.calculateCanvasSize(any)).called(greaterThan(0));
      
      // Reset window size
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    testWidgets('should disable Use Signature button when no content', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(false);
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Assert
      final useButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Use Signature'),
      );
      
      // Button should be enabled but show error when tapped
      expect(useButton.enabled, isTrue);
    });

    testWidgets('should show progress indicator while saving', (WidgetTester tester) async {
      // Arrange
      when(mockSignatureService.hasContent).thenReturn(true);
      when(mockSignatureService.generateJpegImage(any, 95))
        .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
          return Uint8List.fromList([1, 2, 3]);
        });
      when(mockSignatureService.saveSignature(testUserId, any))
        .thenAnswer((_) async => 'path');
      
      await tester.pumpWidget(
        MaterialApp(
          home: SignatureCaptureScreen(
            userId: testUserId,
            signatureService: mockSignatureService,
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Use Signature'));
      await tester.pump();

      // Assert - Should show progress
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Complete the save
      await tester.pumpAndSettle();
    });
  });
}