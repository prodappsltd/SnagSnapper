
import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Helper/auth.dart';
import 'package:snagsnapper/Helper/error.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';

import '../../Data/user.dart';


class SignUp2Screen extends StatefulWidget {
  const SignUp2Screen({super.key});

  @override
  _SignUp2ScreenState createState() => _SignUp2ScreenState();
}

class _SignUp2ScreenState extends State<SignUp2Screen> {
  final _formKey = GlobalKey<FormState>();
  bool busy=false;
  String _password = '';
  String _repeatPassword = '';

  // @override
  // void initState() {
  //   super.initState();
  //   SystemChrome.setPreferredOrientations([
  //     DeviceOrientation.portraitUp,
  //     DeviceOrientation.portraitDown,
  //   ]);
  // }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height-30),
            child: IntrinsicHeight(
              child: Container(
                margin: const EdgeInsets.only(left: 10.0, right: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ImageHelper(
                        b64Image: Provider.of<CP>(context, listen: false).getAppUser()?.image?? '',
                        height: getProportionalHeightForTopImage(context,FRACTION),
                        text: 'Click to add your \ncompany logo',
                        callBackFunction :() async {
                          Provider.of<CP>(context, listen: false).getAppUser()!.image.isEmpty
                              ? Provider.of<CP>(context, listen: false).getAppUser()!.image = await optionsDialogBox(context, 1000)?? Provider.of<CP>(context, listen: false).getAppUser()!.image
                              : Provider.of<CP>(context, listen: false).getAppUser()!.image = await optionsDialogBoxWithDEL(context,(){
                            setState(() =>  Provider.of<CP>(context, listen: false).getAppUser()!.image = '');
                            Navigator.pop(context);
                          })?? Provider.of<CP>(context, listen: false).getAppUser()!.image;
                          if (Provider.of<CP>(context, listen: false).getAppUser()!.image.isNotEmpty) setState(() =>  Provider.of<CP>(context, listen: false).getAppUser()!.image);
                        }
                    ),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      margin: const EdgeInsets.only(left:0.0, right: 0.0, top: 10.0, bottom: 15.0),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                          boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0),blurRadius: 5.0, spreadRadius: 1.0)]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text('Sign up', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold, fontSize: 25),),
                              Text('Step 2/2', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontSize: 20),),
                            ],),
                          Form(
                              key: _formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  TextFormField(
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@_ ]'))],
                                    keyboardType: TextInputType.emailAddress,
                                    textCapitalization: TextCapitalization.none,
                                    //initialValue: Provider.of<UserData>(context, listen: false).getAppUser()!.name,
                                    decoration: InputDecoration(
                                      //    border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                        labelText: 'Email (Required)'),
                                    onChanged: (value) {
                                      Provider.of<CP>(context, listen: false).getAppUser()!.email = value.toString().trim();
                                    },
                                    validator: (value) {
                                      String pattern1 =
                                          r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
                                      RegExp regex = new RegExp(pattern1);
                                      return (!regex.hasMatch(value?? ''))? 'Invalid email' : null;
                                    },
                                  ),

                                  TextFormField(
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_@.&*!"/,:+)(%£?-|; ]'))],
                                    keyboardType: TextInputType.text,
                                    //textCapitalization: TextCapitalization.none,
                                    //initialValue: Provider.of<UserData>(context, listen: false).getAppUser()!.name,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      //    border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.security, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                        labelText: 'password (Required)'),
                                    onChanged: (value) {
                                      _password = value.toString().trim();
                                    },
                                    validator: (value) {
                                      return (value.toString().isEmpty || value.toString().length<6)? '* Please enter at least 6 characters *' : null;
                                    },
                                  ),

                                  TextFormField(
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_@.&*!"/,:+)(%£?-|; ]'))],
                                    keyboardType: TextInputType.text,
                                    //textCapitalization: TextCapitalization.none,
                                    //initialValue: Provider.of<UserData>(context, listen: false).getAppUser()!.name,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      //    border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.security, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                        labelText: 'Repeat password (Required)'),
                                    onChanged: (value) {
                                      _repeatPassword = value.toString().trim();
                                    },
                                    validator: (value) {
                                      return (_repeatPassword != _password || _repeatPassword.isEmpty)? '* Passwords don\'t match *' : null;
                                    },
                                  ),

                                  TextFormField(
                                    //TODO - FIX THIS RESTRICTIONS
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[+0-9]'))],
                                    keyboardType: TextInputType.phone,
                                    //textCapitalization: TextCapitalization.none,
                                    //initialValue: Provider.of<UserData>(context, listen: false).getAppUser()!.name,
                                    decoration: InputDecoration(
                                      //    border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                        labelText: 'Phone (Required)'),
                                    onChanged: (value) {
                                      Provider.of<CP>(context, listen: false).getAppUser()!.phone = value.toString().trim();
                                    },
                                    validator: (value) {
                                      return value.toString().isEmpty? '* Required *' : null;
                                    },
                                  ),
                                ],
                              )
                          ),
                          GestureDetector(
                            onTap: () async {
                              if (busy) return;
                              FocusScope.of(context).requestFocus(FocusNode());
                              setState(() => busy = true);
                              bool hasInternet = await Provider.of<CP>(context, listen: false).getNetworkStatus();
                              if (_formKey.currentState!.validate() && hasInternet){
                                AppUser appUser = Provider.of<CP>(context, listen: false).getAppUser()!;

                                if (kDebugMode) print (appUser.name);
                                if (kDebugMode) print (appUser.jobTitle);
                                if (kDebugMode) print (appUser.companyName);
                                if (kDebugMode) print (appUser.postcodeOrArea);
                                if (kDebugMode) print (appUser.email);
                                if (kDebugMode) print (_password);
                                if (kDebugMode) print (appUser.phone);

                                Auth auth = Auth();
                                await auth.createUserWithEmailAndPassword(appUser.email.toLowerCase(), _password).then((Information info) async {
                                  if (info.error){
                                    _showFlushbar(context, Colors.red, info.message,errorDisplaytime);
                                    setState(() => busy=false);
                                  } else {
                                    await auth.sendEmailVerification();
                                    await showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text("Verify Email"),
                                          content: const Text("Please check your email for the verification link!"),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: const Text("OK"),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    appUser.dateFormat = 'dd-MM-yyyy'; // First time it should be saved.
                                    appUser.listOfALLColleagues = [];
                                    appUser.mapOfSitePaths = {};
                                    appUser.signature = '';
                                    //Store in FIRESTORE
                                    User? firebaseUser = auth.currentUser();
                                    FirebaseFirestore.instance
                                        .collection('Profile')
                                        .doc(firebaseUser!.uid)
                                        .set(appUser.toJson()).then((onValue) async {
                                          await auth.signOut(context);
                                          setState(() => busy=false);
                                          Provider.of<CP>(context, listen: false).resetVariables(); // Also signs out
                                          Navigator.pushNamedAndRemoveUntil(context, '/login',(Route<dynamic> route)=>false);
                                    }).catchError((onError) async {
                                      _showFlushbar(context, Colors.red, 'Could not create a profile for you. Please try again. If this error persists, please contact us at developer@productiveapps.co.uk',errorDisplaytime);
                                      await Future.delayed(Duration(seconds: 10));
                                      if (kDebugMode) print('Going to delete the user account');
                                      await FirebaseAuth.instance.currentUser!.delete();
                                      setState(() => busy=false);
                                    });
                                  }
                                });
                                setState(() => busy=false);
                              } else if (!hasInternet) {
                                _showFlushbar(context, Colors.red,'Please check your internet connection',errorDisplaytime);
                                setState(() => busy=false);
                              } else {
                                setState(() => busy=false);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: const BorderRadius.all(Radius.circular(10.0))
                              ),
                              padding: const EdgeInsets.all(20.0),
                              margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
                              width: double.infinity,
                              child: Center(child: busy?
                              SpinKitRipple(color: Theme.of(context).colorScheme.onPrimary,)
                                  :
                                Text('SAVE', style: TextStyle(fontWeight:FontWeight.bold,color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),)),
                            ),
                          )
                        ],
                      ),
                    ),
                    Center(child: GestureDetector(
                        onTap:(){
                          Navigator.pushNamedAndRemoveUntil(context, '/login',(Route<dynamic> route)=>false);
                        },
                        child: Text('Already have an account? Sign-In', style: TextStyle(color: Theme.of(context).colorScheme.primary )))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _showFlushbar(BuildContext context, Color color, String message, int time){
    Flushbar(
      title: time<errorDisplaytime? "Success":"Error",
      icon: time<errorDisplaytime? Icon(Icons.check_circle):Icon(Icons.error),
      backgroundColor: color,
      message: message,
      duration: Duration(milliseconds: time),
    )..show(context);

  }
}