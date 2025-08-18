import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snagsnapper/Helper/baseAuth.dart';
import 'package:snagsnapper/Helper/error.dart';
import 'package:snagsnapper/services/image_service.dart';


class Auth extends BaseAuth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  @override
  Future<Information> createUserWithEmailAndPassword(String email, String password) async {
    Information info = Information();

    try{
      await _firebaseAuth
          .createUserWithEmailAndPassword(
        email: email,
        password: password,);
    } on FirebaseAuthException catch (e){
      if (kDebugMode) {
        print('Auth.createUserWithEmailAndPassword: Error - ${e.code}: ${e.message}');
      }
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
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Auth.sendPasswordResetEmail: Error - ${e.code}: ${e.message}');
      }
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
    return _firebaseAuth.currentUser;
  }



  @override
  Future<Information> signInWithEmailAndPassword(String email, String password) async {
    Information info = Information();
    try {
      await _firebaseAuth
          .signInWithEmailAndPassword(email: email.toLowerCase().trim(), password: password.trim())
          .then((UserCredential userCredential) async {
            User? user = userCredential.user;
            if (user == null) throw FirebaseAuthException(code: 'user-credential-error', message: 'User credential error');
            if (!user.emailVerified) {
              //_firebaseAuth.signOut();
              info.message = 'Please verify your email before logging in. Check your email for verification link!';
              info.error = true;
            }
      });
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('Auth.signInWithEmailAndPassword: Error - ${e.code}: ${e.message}');
      switch (e.code) {
        case ('invalid-email'):
          {
            info.message = 'Invalid email address';
            info.error = true;
          }
          break;
        case ('user-not-found'):
          {
            info.message = 'No account found with this email. Please sign up first.';
            info.error = true;
          }
          break;
        case ('wrong-password'):
          {
            info.message = 'Incorrect password. Please try again.';
            info.error = true;
          }
          break;
        case ('invalid-credential'):
          {
            info.message = 'Invalid email or password. Please check your credentials.';
            info.error = true;
          }
          break;
        case ('user-disabled'):
          {
            info.message = 'This account has been disabled. Please contact support.';
            info.error = true;
          }
          break;
        case ('too-many-requests'):
          {
            info.message = 'Too many failed attempts. Please try again later.';
            info.error = true;
          }
          break;
        default:
          {
            info.message = e.message ?? 'Login failed. Please try again.';
            info.error = true;
          }
          break;
      }
    }
    return info;
  }

  ///Not in use currently
  ///Could be used later
  @override
  Future<Information> signInWithGoogle() async {
    if (kDebugMode) {
      print('Auth.signInWithGoogle: Starting Google sign-in process');
    }
    try {
      // Initialize GoogleSignIn with serverClientId for Android
      // Web client ID from google-services.json (client_type: 3)
      await _googleSignIn.initialize(
        serverClientId: '752613191889-9dgdtq2s2et165faj5s5f1vf4o1o0nq3.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? account = await _googleSignIn.authenticate();
      if (account == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          print('Auth.signInWithGoogle: User cancelled sign-in');
        }
        Information info = Information();
        info.error = true;
        info.message = 'Sign in cancelled';
        return info;
      }
      if (kDebugMode) {
        print('Auth.signInWithGoogle: Got account: ${account.email}');
      }
      final GoogleSignInAuthentication auth = account.authentication;
      if (kDebugMode) {
        print('Auth.signInWithGoogle: Got authentication token');
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: auth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (kDebugMode) {
        print('Auth.signInWithGoogle: Successfully signed in with Firebase');
      }
      return Information();
    } catch (e) {
      if (kDebugMode) {
        print('Auth.signInWithGoogle: Error occurred - $e');
        print('Auth.signInWithGoogle: Error type - ${e.runtimeType}');
      }
      Information info = Information();
      info.error = true;
      info.message = 'Error signing in with Google: $e';
      return info;
    }
  }

  @override
  Future<void> signOut(BuildContext? context) async {
    try {
      // Clear all cached images
      if (kDebugMode) print('Auth.signOut: Clearing image cache');
      final imageService = ImageService();
      await imageService.clearAllUserCache();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      if (kDebugMode) print('Auth.signOut: Successfully signed out and cleared cache');
    } catch (e) {
      if (kDebugMode) print('Auth.signOut: Error during signout: $e');
      // Still try to sign out even if cache clearing fails
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Future<Information> sendEmailVerification() async {
    try{
      if(kDebugMode) print(' Sending verification email again!');
      await _firebaseAuth.currentUser!.sendEmailVerification();

    } catch (e){
      if (kDebugMode) print ('Auth.sendEmailVerification: ERROR HAPPENED : $e');
      Information info = Information();
      info.error = true;
      info.message = 'Failed to send verification email';
      return info;
    }
    return Information();
  }
}
