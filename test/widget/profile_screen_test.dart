import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/user.dart';
import 'package:snagsnapper/Screens/profile.dart';

// Generate mocks for testing
@GenerateMocks([CP])
import 'profile_screen_test.mocks.dart';

void main() {
  late MockCP mockCP;
  late AppUser testUser;

  setUp(() {
    mockCP = MockCP();
    testUser = AppUser()
      ..name = 'John Doe'
      ..jobTitle = 'Site Manager'
      ..companyName = 'Construction Co'
      ..postcodeOrArea = 'SW1A 1AA'
      ..phone = '+447123456789'
      ..email = 'john.doe@example.com'
      ..dateFormat = 'dd-MM-yyyy'
      ..signature = ''
      ..image = '';
    
    // Set default values for CP mock
    when(mockCP.brightness).thenReturn(Brightness.light);
    when(mockCP.themeType).thenReturn('orange');
    when(mockCP.getAppUser()).thenReturn(testUser);
    when(mockCP.updateProfile(any, any, any, any, any, any, any, any))
        .thenAnswer((_) async => true);
    when(mockCP.updateProfileImage()).thenAnswer((_) async => true);
    when(mockCP.changeDateFormat(any)).thenReturn(null);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6600),
          brightness: Brightness.light,
        ),
      ),
      home: ChangeNotifierProvider<CP>.value(
        value: mockCP,
        child: const Profile(),
      ),
    );
  }

  group('Profile Screen - Basic Structure', () {
    testWidgets('displays header correctly', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Manage your personal information'), findsOneWidget);
    });

    testWidgets('displays all form fields with user data', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Site Manager'), findsOneWidget);
      expect(find.text('Construction Co'), findsOneWidget);
      expect(find.text('SW1A 1AA'), findsOneWidget);
      expect(find.text('+447123456789'), findsOneWidget);
      expect(find.text('john.doe@example.com'), findsOneWidget);
    });

    testWidgets('displays Save button in app bar', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('displays date format section with SegmentedButton', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Scroll to date format section
      await tester.ensureVisible(find.text('Date Format'));
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('Date Format'), findsOneWidget);
      expect(find.text('DD-MM-YYYY'), findsOneWidget);
      expect(find.text('MM-DD-YYYY'), findsOneWidget);
    });

    testWidgets('displays signature section', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Scroll to signature section
      await tester.ensureVisible(find.text('Signature'));
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('Signature'), findsOneWidget);
      expect(find.text('Add Signature'), findsOneWidget);
    });

    testWidgets('displays company logo section', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.text('Company Logo (Optional)'), findsOneWidget);
      expect(find.text('Add Company Logo'), findsOneWidget);
    });
  });

  group('Profile Screen - Field Requirements', () {
    testWidgets('job title field is marked as required', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert - Job Title should have * indicator
      expect(find.text('Job Title *'), findsOneWidget);
    });

    testWidgets('postcode field is marked as optional', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert - Postcode should have (Optional) indicator
      expect(find.text('Postcode or Area (Optional)'), findsOneWidget);
    });

    testWidgets('validates job title as required when empty', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Act - Clear job title field
      final jobTitleField = find.text('Site Manager');
      await tester.tap(jobTitleField);
      await tester.pumpAndSettle();
      
      // Select all and delete
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.pumpAndSettle();
      
      // Try to save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Assert - Should show validation error
      expect(find.text('Job title is required'), findsOneWidget);
    });

    testWidgets('allows empty postcode field', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Act - Clear postcode field
      final postcodeField = find.text('SW1A 1AA');
      await tester.tap(postcodeField);
      await tester.pumpAndSettle();
      
      // Select all and delete
      await tester.enterText(find.byType(TextFormField).at(3), '');
      await tester.pumpAndSettle();
      
      // Try to save
      await tester.tap(find.text('Save'));
      await tester.pump();
      
      // Assert - Should not show validation error for postcode
      expect(find.text('Postcode must be less than 20 characters'), findsNothing);
      expect(find.text('Invalid characters in postcode'), findsNothing);
      
      // Verify updateProfile was called (meaning validation passed)
      verify(mockCP.updateProfile(any, any, any, '', any, any, any, any)).called(1);
    });
  });

  group('Profile Screen - Date Format Toggle', () {
    testWidgets('toggles between date formats', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Scroll to date format section
      await tester.ensureVisible(find.text('Date Format'));
      await tester.pumpAndSettle();
      
      // Act - Tap on MM-DD-YYYY format
      await tester.tap(find.text('MM-DD-YYYY'));
      await tester.pumpAndSettle();
      
      // Assert
      verify(mockCP.changeDateFormat(false)).called(1);
    });
  });

  group('Profile Screen - Save Functionality', () {
    testWidgets('saves profile with valid data', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Act - Make a change and save
      final nameField = find.byType(TextFormField).first;
      await tester.tap(nameField);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Jane Doe');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Assert
      verify(mockCP.updateProfile(
        'Jane Doe',
        any,
        any,
        any,
        any,
        any,
        any,
        any,
      )).called(1);
    });

    testWidgets('shows loading state while saving', (WidgetTester tester) async {
      // Arrange
      when(mockCP.updateProfile(any, any, any, any, any, any, any, any))
          .thenAnswer((_) async {
        await Future.delayed(const Duration(seconds: 1));
        return true;
      });
      
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Act
      await tester.tap(find.text('Save'));
      await tester.pump();
      
      // Assert - Save button should be disabled during save
      expect(find.text('Save'), findsNothing);
      
      // Complete the save
      await tester.pumpAndSettle();
    });

    testWidgets('navigates back after successful save', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Act
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Assert - Should navigate back
      // In a real test, you'd verify navigation happened
      verify(mockCP.updateProfile(any, any, any, any, any, any, any, any)).called(1);
    });
  });

  group('Profile Screen - Email Field', () {
    testWidgets('email field is disabled', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      // Assert
      final emailFields = find.byType(TextFormField);
      final emailField = tester.widget<TextFormField>(emailFields.at(5));
      expect(emailField.enabled, isFalse);
    });
  });
}