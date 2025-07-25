import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snagsnapper/Helper/auth_testable.dart';

// Generate mocks for testing
@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
])
import 'auth_test.mocks.dart';

void main() {
  late AuthTestable auth;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;
  
  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
    
    // Create AuthTestable instance with mocked dependencies
    auth = AuthTestable(
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );
  });

  group('Auth Service - Email/Password Sign In', () {
    test('successful login with valid credentials returns no error', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      
      when(mockUser.emailVerified).thenReturn(true);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      )).thenAnswer((_) async => mockUserCredential);
      
      // Act
      final result = await auth.signInWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, false);
      expect(result.message, '');
      verify(mockFirebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      )).called(1);
    });

    test('login fails with incorrect password', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'wrongpassword';
      
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      )).thenThrow(FirebaseAuthException(code: 'wrong-password'));
      
      // Act
      final result = await auth.signInWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'Wrong password');
    });

    test('login fails with non-existent user', () async {
      // Arrange
      const email = 'nonexistent@example.com';
      const password = 'password123';
      
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      )).thenThrow(FirebaseAuthException(code: 'user-not-found'));
      
      // Act
      final result = await auth.signInWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'User not found');
    });

    test('login fails with unverified email', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      
      when(mockUser.emailVerified).thenReturn(false);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      )).thenAnswer((_) async => mockUserCredential);
      
      // Act
      final result = await auth.signInWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'Please verify your email before logging in. Check your email for verification link!');
    });

    test('email is trimmed and lowercased before authentication', () async {
      // Arrange
      const email = '  TEST@EXAMPLE.COM  ';
      const password = '  password123  ';
      const expectedEmail = 'test@example.com';
      const expectedPassword = 'password123';
      
      when(mockUser.emailVerified).thenReturn(true);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: expectedEmail,
        password: expectedPassword,
      )).thenAnswer((_) async => mockUserCredential);
      
      // Act
      await auth.signInWithEmailAndPassword(email, password);
      
      // Assert
      verify(mockFirebaseAuth.signInWithEmailAndPassword(
        email: expectedEmail,
        password: expectedPassword,
      )).called(1);
    });
  });

  group('Auth Service - Email/Password Sign Up', () {
    test('successful account creation with valid email/password', () async {
      // Arrange
      const email = 'newuser@example.com';
      const password = 'StrongPassword123!';
      
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenAnswer((_) async => mockUserCredential);
      
      // Act
      final result = await auth.createUserWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, false);
      expect(result.message, '');
      verify(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).called(1);
    });

    test('fails when email already exists', () async {
      // Arrange
      const email = 'existing@example.com';
      const password = 'password123';
      
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      
      // Act
      final result = await auth.createUserWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'An account already exists with this email, please try logging in with it.');
    });

    test('fails with invalid email format', () async {
      // Arrange
      const email = 'invalid-email';
      const password = 'password123';
      
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(FirebaseAuthException(code: 'invalid-email'));
      
      // Act
      final result = await auth.createUserWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'Invalid email address');
    });

    test('fails with weak password', () async {
      // Arrange
      const email = 'test@example.com';
      const password = '123';
      
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).thenThrow(FirebaseAuthException(code: 'weak-password'));
      
      // Act
      final result = await auth.createUserWithEmailAndPassword(email, password);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'Password too weak! \nChoose new password');
    });
  });

  group('Auth Service - Google Sign In', () {
    test('successful Google authentication', () async {
      // Arrange
      final mockGoogleSignInAccount = MockGoogleSignInAccount();
      final mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
      
      when(mockGoogleSignIn.authenticate()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenReturn(mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.idToken).thenReturn('mock-id-token');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);
      
      // Act
      final result = await auth.signInWithGoogle();
      
      // Assert
      expect(result.error, false);
      expect(result.message, '');
      verify(mockGoogleSignIn.authenticate()).called(1);
      verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
    });

    test('handles Google sign-in cancellation', () async {
      // Arrange
      when(mockGoogleSignIn.authenticate()).thenThrow(Exception('User cancelled'));
      
      // Act
      final result = await auth.signInWithGoogle();
      
      // Assert
      expect(result.error, true);
      expect(result.message, contains('Error signing in with Google'));
      verify(mockGoogleSignIn.authenticate()).called(1);
      verifyNever(mockFirebaseAuth.signInWithCredential(any));
    });

    test('handles Google sign-in errors', () async {
      // Arrange
      when(mockGoogleSignIn.authenticate()).thenThrow(Exception('Google sign-in failed'));
      
      // Act
      final result = await auth.signInWithGoogle();
      
      // Assert
      expect(result.error, true);
      expect(result.message, contains('Error signing in with Google'));
    });
  });

  group('Auth Service - Other Methods', () {
    test('currentUser returns logged-in user', () {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
      
      // Act
      final user = auth.currentUser();
      
      // Assert
      expect(user, mockUser);
      verify(mockFirebaseAuth.currentUser).called(1);
    });

    test('currentUser returns null when not logged in', () {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      
      // Act
      final user = auth.currentUser();
      
      // Assert
      expect(user, null);
      verify(mockFirebaseAuth.currentUser).called(1);
    });

    test('signOut successfully logs out user', () async {
      // Arrange
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
      
      // Act
      await auth.signOut(null);
      
      // Assert
      verify(mockFirebaseAuth.signOut()).called(1);
    });

    test('sendPasswordResetEmail with valid email', () async {
      // Arrange
      const email = 'test@example.com';
      when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
          .thenAnswer((_) async {});
      
      // Act
      final result = await auth.sendPasswordResetEmail(email);
      
      // Assert
      expect(result.error, false);
      expect(result.message, '');
      verify(mockFirebaseAuth.sendPasswordResetEmail(email: email)).called(1);
    });

    test('sendPasswordResetEmail with invalid email', () async {
      // Arrange
      const email = 'invalid-email';
      when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
          .thenThrow(FirebaseAuthException(code: 'invalid-email'));
      
      // Act
      final result = await auth.sendPasswordResetEmail(email);
      
      // Assert
      expect(result.error, true);
      expect(result.message, 'Invalid email address');
    });

    test('sendEmailVerification sends verification email', () async {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(mockUser.sendEmailVerification()).thenAnswer((_) async {});
      
      // Act
      final result = await auth.sendEmailVerification();
      
      // Assert
      expect(result.error, false);
      verify(mockUser.sendEmailVerification()).called(1);
    });
  });
}