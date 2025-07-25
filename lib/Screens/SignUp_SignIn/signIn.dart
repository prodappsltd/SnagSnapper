// TODO: DELETE THIS FILE - Replaced by UnifiedAuthScreen
// This old sign-in screen is no longer used.
// UnifiedAuthScreen now handles both login and signup in one screen.

import 'dart:developer';

import 'package:another_flushbar/flushbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Helper/auth.dart';
import 'package:snagsnapper/Helper/error.dart';

import '../../main.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late User? firebaseUser;
  late String email;
  late String password;
  bool busy = false;
  final _formKey = GlobalKey<FormState>();

  // @override
  // void initState() {
  //   super.initState();
  //   if (kDebugMode) print ('-----   In SignIn Screen   -----');
  //   // SystemChrome.setPreferredOrientations([
  //   //   DeviceOrientation.portraitUp,
  //   //   DeviceOrientation.portraitDown
  //   // ]);
  // }

  // @override
  // void dispose() {
  //   SystemChrome.setPreferredOrientations([
  //     DeviceOrientation.portraitUp
  //   ]);
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    firebaseUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              margin: const EdgeInsets.only(left: 10.0, right: 10.0, top: 0.0, bottom: 0.0),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                  boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.shadow, offset: Offset(0.0, 0.0), blurRadius: 5.0, spreadRadius: 1.0)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Sign In',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25.0, color: Theme.of(context).colorScheme.onTertiaryContainer),
                  ),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          style: TextStyle(color:Theme.of(context).colorScheme.onTertiaryContainer ),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@_ ]'))],
                          keyboardType: TextInputType.emailAddress,
                          textCapitalization: TextCapitalization.none,
                          initialValue: '',
                          decoration: InputDecoration(
                              //    border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
                              labelStyle: TextStyle(color:Theme.of(context).colorScheme.onTertiaryContainer),
                              labelText: 'Email (Required)'),
                          onChanged: (value) {
                            email = value.toString().trim();
                          },
                          validator: (value) {
                            return value.toString().isNotEmpty ? null : '*Required*';
                          },
                        ),
                        TextFormField(
                          style: TextStyle(color:Theme.of(context).colorScheme.onTertiaryContainer ),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@!_ ]'))],
                          keyboardType: TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.none,
                          initialValue: '',
                          obscureText: false,
                          decoration: InputDecoration(
                              //    border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.security, color: Theme.of(context).colorScheme.onTertiaryContainer),
                              labelText: 'Password (Required)',
                            labelStyle: TextStyle(color:Theme.of(context).colorScheme.onTertiaryContainer),
                          ),
                          onChanged: (value) {
                            password = value.toString().trim();
                          },
                          validator: (value) {
                            return value.toString().isNotEmpty ? null : '*Required*';
                          },
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () async {
                            FocusScope.of(context).requestFocus(FocusNode()); // To hide keyboard
                            setState(() => busy = true);
                            bool hasInternet = await Provider.of<CP>(context, listen: false).getNetworkStatus();
                            if (_formKey.currentState!.validate() && hasInternet) {
                              Auth auth = Auth();

                              try {
                                await auth.signInWithEmailAndPassword(email, password).then((Information info) async {
                                  if (!FirebaseAuth.instance.currentUser!.emailVerified) {
                                    await _showVerificationResendEmailDialog();
                                    setState(() => busy = false);
                                    if (context.mounted) await auth.signOut(context);
                                    return;
                                  }
                                  if (kDebugMode) print('>> Leaving Sign-in Screen - Sign-in Success');
                                  String resultString = await Provider.of<CP>(context, listen: false).loadProfileOfUser();
                                  if (kDebugMode) print(resultString);
                                  if (resultString == 'Profile Found') {
                                    // Proceed to main Menu
                                    Navigator.of(context).pushNamedAndRemoveUntil('/mainMenu', (Route<dynamic> route) => false);
                                  } else {
                                    displaySnackBarError(resultString);
                                  }
                                  setState(() => busy = false);
                                });
                              } on FirebaseAuthException catch (e) {
                                if (kDebugMode) print(e);
                                _showFlushbar(context, Theme.of(context).colorScheme.error, e.message ?? "Unknown Authentication Error", errorDisplaytime);
                                setState(() => busy = false);
                              }
                            } else if (!hasInternet) {
                              _showFlushbar(context, Theme.of(context).colorScheme.error, 'Please check your internet connection', errorDisplaytime);
                              setState(() => busy = false);
                            }
                            setState(() => busy = false);
                          },
                    child: Container(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                      padding: const EdgeInsets.all(20.0),
                      margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
                      width: double.infinity,
                      height: 80.0,
                      child: Center(
                          child: busy
                              ? SpinKitRipple(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 80.0,
                                )
                              : Text(
                                  'SIGN IN',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),
                                )),
                    ),
                  ),
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/forgotPassword'),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                        )),
                  )),
                  Center(
                      child: GestureDetector(
                        onTap: ()=> Navigator.of(context).pop(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            Text(' Back', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  _showVerificationResendEmailDialog() async {
    return Alert(
      context: context,
      style: kWelcomeAlertStyle(context),
      image: SvgPicture.asset(
        'images/stupid.svg',
        color: Theme.of(context).colorScheme.onTertiaryContainer,
        // colorFilter: const ColorFilter.mode(Colors.white, BlendMode.multiply),
        semanticsLabel: 'Forgot password',
        width: 125,
        height: 125,
      ),
      title: "Verify Email",
      content: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 20.0, right: 8.0, left: 8.0, bottom: 20.0),
            child: Text(
              '\' ${FirebaseAuth.instance.currentUser!.email} \' is registered but has not been verified yet. Please check your email for a verification link.\n\nDO NOT FORGET TO CHECK YOUR JUNK EMAIL FOLDER FOR THE LINK AS WELL!',
              textAlign: TextAlign.center,
              style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer), // TODO - Try something else, description too bold
              // style: kSendButtonTextStyle,
            ),
          )
        ],
      ),
      buttons: [
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () async {
            if (kDebugMode) print(' Sending verification email...');
            try {
              //throw FirebaseAuthException(code: 'Test Error');
              await FirebaseAuth.instance.currentUser!.sendEmailVerification();
              if (!mounted) return;
              Navigator.pop(context);
            } on FirebaseAuthException catch (e) {
              Navigator.pop(context);
              if (kDebugMode) print(' Sending verification email...EXCEPTION HAPPENED : $e');
              switch (e.code) {
                case ('too-many-requests'):
                  displaySnackBarError('too-many-requests');
                  break;
                default:
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      e.toString(),
                      style: const TextStyle(fontSize: 18.0, color: Colors.white),
                    ),
                    duration: const Duration(seconds: 5),
                    backgroundColor: Colors.red,
                  ));
                  break;
              }
            }
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "Resend Link",
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary,),
          ),
        ),
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "CLOSE",
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary,),
          ),
        ),
      ],
    ).show();
  }

  void displaySnackBarError(String resultString) {
    switch (resultString) {
      case 'RevCat Error':
        _showFlushbar(context, Theme.of(context).colorScheme.error,
            'RevCat Initialisation error. If this error persists, please contact the developer on developer@productiveapps.co.uk', errorDisplaytime);
        break;
      case 'Firebase Error Owned Sites':
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Error loading owned sites. If this error persists, please contact the developer on developer@productiveapps.co.uk',
            errorDisplaytime);
        break;
      case 'Firebase Error Shared Sites':
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Error loading shared sites. If this error persists, please contact the developer on developer@productiveapps.co.uk',
            errorDisplaytime);
        break;
      case 'Profile Not Found':
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Profile not found! Which is not what I expected', errorDisplaytime);
        break;
      case 'Firebase Error': // User Profile Load Error
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Error loading profile. If this error persists, please contact the developer on developer@productiveapps.co.uk',
            errorDisplaytime);
        break;
      case 'too-many-requests': // User Profile Load Error
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Too many requests from this device, please try again in a few minutes', errorDisplaytime);
        break;
      default:
        _showFlushbar(context, Theme.of(context).colorScheme.error, 'Unknown error is happening, please contact the developer on developer@productiveapps.co.uk', errorDisplaytime);
        break;
    }
  }
}

_showFlushbar(BuildContext context, Color color, String message, int time) {
  Flushbar(
    title: time < errorDisplaytime ? "Success" : "Error",
    icon: time < errorDisplaytime ? const Icon(Icons.check_circle) : const Icon(Icons.error),
    backgroundColor: color,
    message: message,
    duration: Duration(milliseconds: time),
  ).show(context);
}
