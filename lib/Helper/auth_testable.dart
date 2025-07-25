import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snagsnapper/Helper/baseAuth.dart';
import 'package:snagsnapper/Helper/error.dart';

/// Testable version of Auth class that accepts dependencies via constructor
/// This allows proper unit testing with mocked dependencies
class AuthTestable extends BaseAuth {
  final FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;

  AuthTestable({
    required this.firebaseAuth,
    required this.googleSignIn,
  });

  @override
  Future<Information> createUserWithEmailAndPassword(String email, String password) async {
    Information info = Information();

    try {
      await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case ('email-already-in-use'):
          {
            info.message = 'An account already exists with this email, please try logging in with it.';
            info.error = true;
          }
          break;
        case ('invalid-email'):
          {
            info.message = 'Invalid email address';
            info.error = true;
          }
          break;
        case ('weak-password'):
          {
            info.message = 'Password too weak! \nChoose new password';
            info.error = true;
          }
          break;
        default:
          {
            info.message = 'Unknown error: ${e.message}';
            info.error = true;
          }
          break;
      }
    }
    return info;
  }

  @override
  Future<Information> sendPasswordResetEmail(String email) async {
    Information info = Information();
    try {
      await firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case ('invalid-email'):
          {
            info.message = 'Invalid email address';
            info.error = true;
          }
          break;
        case ('user-not-found'):
          {
            info.message = 'User not found';
            info.error = true;
          }
          break;
        default:
          {
            info.message = 'Unknown error: ${e.message}';
            info.error = true;
          }
          break;
      }
    }
    return info;
  }

  @override
  User? currentUser() {
    return firebaseAuth.currentUser;
  }

  @override
  Future<Information> signInWithEmailAndPassword(String email, String password) async {
    Information info = Information();
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password.trim(),
      );
      
      User? user = userCredential.user;
      if (user == null) {
        info.message = 'Login failed: No user returned';
        info.error = true;
        return info;
      }
      
      if (!user.emailVerified) {
        info.message = 'Please verify your email before logging in. Check your email for verification link!';
        info.error = true;
        return info;
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('ErrorCode: ${e.code}');
      switch (e.code) {
        case ('invalid-email'):
          {
            info.message = 'Invalid email address';
            info.error = true;
          }
          break;
        case ('user-not-found'):
          {
            info.message = 'User not found';
            info.error = true;
          }
          break;
        case ('wrong-password'):
          {
            info.message = 'Wrong password';
            info.error = true;
          }
          break;
        default:
          {
            info.message = 'Unknown Error: ${e.message}';
            info.error = true;
          }
          break;
      }
    }
    return info;
  }

  @override
  Future<Information> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await googleSignIn.authenticate();
      if (account == null) {
        // User cancelled the sign-in
        Information info = Information();
        info.error = true;
        info.message = 'Sign in cancelled';
        return info;
      }
      final GoogleSignInAuthentication auth = account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      
      await firebaseAuth.signInWithCredential(credential);
      return Information();
    } catch (e) {
      Information info = Information();
      info.error = true;
      info.message = 'Error signing in with Google: $e';
      return info;
    }
  }

  @override
  Future<void> signOut(BuildContext? context) {
    return firebaseAuth.signOut();
  }

  @override
  Future<Information> sendEmailVerification() async {
    try {
      if (kDebugMode) print('Sending verification email again!');
      await firebaseAuth.currentUser!.sendEmailVerification();
    } catch (e) {
      if (kDebugMode) print('ERROR HAPPENED : $e');
      Information info = Information();
      info.error = true;
      info.message = 'Failed to send verification email';
      return info;
    }
    return Information();
  }
}