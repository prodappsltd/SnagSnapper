import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snagsnapper/Helper/baseAuth.dart';
import 'package:snagsnapper/Helper/error.dart';


class Auth extends BaseAuth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Future<Information> createUserWithEmailAndPassword(String email, String password) async {
    Information info = Information();

    try{
      await _firebaseAuth
          .createUserWithEmailAndPassword(
        email: email,
        password: password,);
    } on FirebaseAuthException catch (e){
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
      switch (e.code) {
        case ('ERROR_INVALID_EMAIL'):
          {
            info.message = 'Invalid email address';
            info.error = true;
          }
          break;
        case ('ERROR_USER_NOT_FOUND'):
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
            if (user == null) throw PlatformException(code: 'User Credential Error');
            if (!user.emailVerified) {
              //_firebaseAuth.signOut();
              info.message = 'Please verify your email before logging in. Check your email for verification link!';
              info.error = true;
            }
      });
    } on PlatformException catch (e) {
      if (kDebugMode) print('ErrorCode: ${e.message}');
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

  ///Not in use currently
  ///Could be used later
  @override
  Future<Information> signInWithGoogle() async {
    final GoogleSignInAccount? _account = await _googleSignIn.signIn();
    final GoogleSignInAuthentication? _auth = await _account?.authentication;
    if (_account != null && _auth !=null) {
      final AuthCredential _credential = GoogleAuthProvider.credential(
          idToken: _auth.idToken,
          accessToken: _auth.accessToken);
      await FirebaseAuth.instance.signInWithCredential(_credential);
      return Information();
    } else {
      Information info = Information();
      info.error = true;
      info.message = 'Error signing in with google';
      return info;
    }
  }

  @override
  Future<void> signOut(BuildContext context) {
    return FirebaseAuth.instance.signOut();
  }

  @override
  Future<Information> sendEmailVerification() async {
    try{
      if(kDebugMode) print(' Sending verification email again!');
      await _firebaseAuth.currentUser!.sendEmailVerification();

    } catch (e){
      if (kDebugMode) print ('ERROR JAPPENED : $e');
    }
    return Information();
  }
}
