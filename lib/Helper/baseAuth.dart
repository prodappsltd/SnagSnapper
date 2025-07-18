
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:snagsnapper/Helper/error.dart';

abstract class BaseAuth {
  Future<Information> signInWithEmailAndPassword(String email, String password);
  Future<Information> sendEmailVerification();
  Future<Information> createUserWithEmailAndPassword(String email, String password);
  Future<Information> sendPasswordResetEmail(String email);

  User? currentUser();
  Future<void> signOut(BuildContext context);
  Future<Information> signInWithGoogle();
}