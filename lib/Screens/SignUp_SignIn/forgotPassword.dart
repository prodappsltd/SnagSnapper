

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Helper/auth.dart';
import 'package:snagsnapper/Helper/error.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String email = '';
  final _formKey = GlobalKey<FormState>();
  bool busy = false;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SvgPicture.asset(
                    'images/stupid.svg',
                    color: Theme.of(context).colorScheme.primary,
                    semanticsLabel: 'Forgot password',
                    width: 250,
                    height: 250,
                  ),
                  const SizedBox(height: 10.0,),
                  Text('Forgot your password?', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 20.0, fontWeight: FontWeight.normal),),
                  //SizedBox(height: 8.0,),
                  //Text('Enter your e-mail and we\'ll send \nyou a link to reset your password',)
                ],
              ),
              Container(
                padding: const EdgeInsets.all(20.0),
                margin: const EdgeInsets.only(left:20.0, right: 20.0, top: 10.0, bottom: 15.0),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                    boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0),blurRadius: 5.0, spreadRadius: 1.0)]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Password Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30.0, color: Theme.of(context).colorScheme.onTertiaryContainer),),
                        Text('', style: TextStyle(color: Colors.grey[600]),),
                      ],),
                    Form(
                      key: _formKey,
                      child:
                      TextFormField(
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@_ ]'))],
                        keyboardType: TextInputType.emailAddress,
                        textCapitalization: TextCapitalization.none,
                        //initialValue: Provider.of<UserData>(context).getAppUser()!.name,
                        decoration: InputDecoration(
                          //    border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            labelText: 'Email (Required)'),
                        onChanged: (value) {
                          email = value.toString().trim();
                        },
                        validator: (value) {
                          String pattern1 =
                              r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
                          RegExp regex = RegExp(pattern1);
                          return (!regex.hasMatch(value?? ''))? 'Invalid email' : null;
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (busy) return;
                        setState(() => busy = true);

                        bool hasInternet = await Provider.of<CP>(context, listen: false).getNetworkStatus();
                        if (_formKey.currentState!.validate() && hasInternet) {
                            Auth auth = Auth();
                            auth.sendPasswordResetEmail(email)
                            .then((Information info){
                              if (info.error) {
                                _showFlushbar(context, Colors.red, info.message,
                                    errorDisplaytime);
                                setState(() => busy = false);
                              } else {
                                _showFlushbar(
                                    context, Colors.green, 'If there is an associated account with this email then a password reset email has been sent!',
                                    successDisplaytime);
                                Future.delayed(const Duration(milliseconds: successDisplaytime + 100), () {
                                  setState(() => busy = false);
                                  if (mounted) Navigator.pushNamed(context, '/checkEmail');
                                });
                              }
                            });
                        } else if (!hasInternet){
                          _showFlushbar(context, Colors.red, 'Please check your internet connection', errorDisplaytime);
                        }
                        setState(() => busy = false);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.all(Radius.circular(20.0))
                        ),
                        padding: const EdgeInsets.all(20.0),
                        margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
                        width: double.infinity,
                        height: 80,
                        child: Center(child: busy? const SpinKitRipple(color: Colors.white,) : Text('RESET PASSWORD', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0, fontWeight: FontWeight.bold),)),
                      ),
                    ),
                    Center(child: Padding(
                      padding: const EdgeInsets.only(top: 25.0),
                      child: GestureDetector(
                        onTap: ()=> Navigator.of(context).pop(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            Text(' Back to Sign-in', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              // Center(child: GestureDetector(onTap: () {
              //   Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
              //   },
              //     child: const Text('Don\'t have an account yet? Sign-Up'))),
            ],
          ),
        ),
      ),
    );
  }


  _showFlushbar(BuildContext context, Color color, String message, int time){
    Flushbar(
      title: time<errorDisplaytime? "Success":"Error",
      icon: time<errorDisplaytime? const Icon(Icons.check_circle):const Icon(Icons.error),
      backgroundColor: color,
      message: message,
      duration: Duration(milliseconds: time),
    ).show(context);

  }

}