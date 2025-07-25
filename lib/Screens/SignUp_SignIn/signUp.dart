
// TODO: DELETE THIS FILE - Replaced by ProfileSetupScreen
// This old signup flow is no longer used. Users now:
// 1. Create account via UnifiedAuthScreen
// 2. Complete profile via ProfileSetupScreen

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Widgets/SelectionButton.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/signUp2.dart';

import '../../Data/user.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {

  // @override
  // void initState() {
  //   super.initState();
  //   SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // }

  @override
  Widget build(BuildContext context) {


  if (Provider.of<CP>(context, listen: false).getAppUser() == null) {
    Provider.of<CP>(context, listen: false).setAppUser(AppUser());
  }


    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 50),
            child: IntrinsicHeight(
              child: Container(
                margin: const EdgeInsets.only(left: 10.0, right: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ImageHelper(
                        b64Image: Provider.of<CP>(context, listen: false).getAppUser()!.image,
                        height: getProportionalHeightForTopImage(context, FRACTION),
                        text: 'Click to add your \ncompany logo',
                        callBackFunction: () async {
                          Provider.of<CP>(context, listen: false).getAppUser()!.image.isEmpty
                              ? Provider.of<CP>(context, listen: false).getAppUser()!.image = await optionsDialogBox(context, 2000)?? Provider.of<CP>(context, listen: false).getAppUser()!.image
                              : Provider.of<CP>(context, listen: false).getAppUser()!.image = await optionsDialogBoxWithDEL(context, () {
                                  setState(() => Provider.of<CP>(context, listen: false).getAppUser()!.image = '');
                                  Navigator.pop(context);
                                })?? Provider.of<CP>(context, listen: false).getAppUser()!.image;
                          if (Provider.of<CP>(context, listen: false).getAppUser()!.image.isNotEmpty) setState(() => Provider.of<CP>(context, listen: false).getAppUser()!.image);
                        }),
                    const RemainFormStateful(),
                    Center(
                        child: GestureDetector(
                            onTap: () {
                                //Provider.of<CP>(context, listen: false).setAppUser(null);
                                Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
                            },
                            child: Text('Already have an account? Sign-In', style: TextStyle(color: Theme.of(context).colorScheme.primary),))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RemainFormStateful extends StatefulWidget {
  const RemainFormStateful({super.key});

  @override
  RemainFormStatefulState createState() => RemainFormStatefulState();
}

class RemainFormStatefulState extends State<RemainFormStateful> {
  final _formKey = GlobalKey<FormState>();


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(left: 0.0, right: 0.0, top: 10.0, bottom: 15.0),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
          boxShadow: [BoxShadow(color:Theme.of(context).colorScheme.shadow, offset: const Offset(0.0, 0.0), blurRadius: 2.0, spreadRadius: 0.0)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Sign up',
                style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold, fontSize: 25),
              ),
              Text(
                'Step 1/2',
                style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontWeight: FontWeight.normal, fontSize: 20),
              ),
            ],
          ),
          Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                    //inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    initialValue: Provider.of<CP>(context, listen: false).getAppUser()!.name,
                    decoration: InputDecoration(
                      //    border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.perm_identity, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        labelText: 'Name (Required)'),
                    onChanged: (value) {
                      Provider.of<CP>(context, listen: false).getAppUser()!.name = value.toString().trim();
                    },
                    validator: (value) {
                      return value.toString().isNotEmpty ? null : '*Required*';
                    },
                  ),
                  TextFormField(
                    //inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    initialValue: Provider.of<CP>(context, listen: false).getAppUser()!.jobTitle,
                    decoration: InputDecoration(
                      //    border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.perm_contact_calendar, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        labelText: 'Job Title (Required)'),
                    onChanged: (value) {
                      Provider.of<CP>(context, listen: false).getAppUser()!.jobTitle = value.toString().trim();
                    },
                    validator: (value) {
                      return value.toString().isNotEmpty ? null : '*Required*';
                    },
                  ),
                  TextFormField(
                    //inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    initialValue: Provider.of<CP>(context, listen: false).getAppUser()!.companyName,
                    decoration: InputDecoration(
                      //    border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        labelText: 'Company Name (Required)'),
                    onChanged: (value) {
                      Provider.of<CP>(context, listen: false).getAppUser()!.companyName = value.toString().trim();
                    },
                    validator: (value) {
                      return value.toString().isNotEmpty ? null : '*Required*';
                    },
                  ),
                ],
              )),
          const SizedBox(height: 18,),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
              if (_formKey.currentState!.validate()) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUp2Screen()));
              }
            },
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
              padding: const EdgeInsets.all(20.0),
              margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
              width: double.infinity,
              height: 80.0,
              child: Center(
                  child: Text(
                    'NEXT',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),
                  )),
            ),
          )
        ],
      ),
    );
  }
}
