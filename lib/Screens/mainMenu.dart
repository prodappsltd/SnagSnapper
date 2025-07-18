
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/moreOptions.dart';
import 'package:snagsnapper/Screens/profile.dart';
import 'package:snagsnapper/Widgets/ActionButton.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'SignUp_SignIn/sign_in_sign_on.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {

  String message1='';
  String message2='';

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print ('-----  * In Main Menu *  -----');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initDynamicLinks();
    });
  }

  /// Initiate Notifications Settings
  // initNotifications() async {
  //   if (kDebugMode) print ('Notification initialisation');
  //   var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
  //   var initializationSettingsIOS = IOSInitializationSettings(
  //       requestSoundPermission: true,
  //       requestBadgePermission: true,
  //       requestAlertPermission: true,
  //       onDidReceiveLocalNotification: onDidReceiveLocalNotification);
  //   var initializationSettings = InitializationSettings(
  //       android: initializationSettingsAndroid,
  //       iOS: initializationSettingsIOS
  //   );
  //   // Get Permissions as required
  //   await flutterLocalNotificationsPlugin
  //       .resolvePlatformSpecificImplementation<
  //       IOSFlutterLocalNotificationsPlugin>()
  //       ?.requestPermissions(
  //     alert: true,
  //     badge: true,
  //     sound: true,
  //   );
  //   await flutterLocalNotificationsPlugin.initialize(
  //       initializationSettings); //,onSelectNotification: onSelectNotification);
  //   _showNotification(true);
  // }

  /// Initialise Dynamic Links first
  initDynamicLinks() async {
    if (kDebugMode) print('Dynamic link initialisation');
    if (kDebugMode) print('MAIN Menu >initDynamicLinks: ---- CHECKING FOR DYNAMIC LINKS');
    // When application is TERMINATED - This gets the link which opened the application
    final PendingDynamicLinkData? dynamicLink = await FirebaseDynamicLinks.instance.getInitialLink();

    final Uri? deepLink = dynamicLink?.link;
    if (kDebugMode && deepLink != null) print('DEEP LINK NOT NUll...: ${deepLink.data}');
    if (deepLink != null) await _dealWithDeepLink(dynamicLink!);

    // When app is in Foreground Or Background - Listener
    FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData? dynamicLink) async {
      if (kDebugMode) print(':: APP IN BACKGROUND TRIGGER HERE ::');
      if (dynamicLink != null) await _dealWithDeepLink(dynamicLink);
    });
  }

  // TODO - See what this does - experiment with an open app
  Future onDidReceiveLocalNotification(int id, String? title, String? body, String? payLoad) async {
    showDialog(
      context: context,
      builder: (BuildContext context)=>CupertinoAlertDialog(
        title: Text(title?? ''),
        content: Text(body?? ''),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: (){
              if (kDebugMode) print('Cupertino Alert Dialog Pressed ***********');
            },
          )
        ],
      )
    );
  }

  /// Show in notification that download was a success
  Future _downloadSuccess(platformSpecifics) async {

    // await flutterLocalNotificationsPlugin.show(
    //   5,
    //   'Successfully downloaded shared site',
    //   'See site under \'My Sites\'',
    //   platformSpecifics,
    //   //payload: 'test Payload String'
    // );
  }
  /// Show in notification that download was a failure
  Future _downloadFailure(platformSpecifics) async {

    //     await flutterLocalNotificationsPlugin.show(
//       5,
//       'Error downloading shared site!',
//       'Permission denied.',
//       platformSpecifics,
// //      payload: 'test Payload String'
//     );
  }

  showPopUpResult(bool result) {
      return Alert(
        context: context,
        style: kWelcomeAlertStyle(context),
        image: Image.asset(
          result? 'images/success.png' : 'images/error.png',
          color: Colors.white,
          width: 150,
          height: 150,
        ),
        title: result? 'Download Success' : 'Download Failure',
        content: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 20.0, right: 8.0, left: 8.0, bottom: 20.0),
              child: Text(
                result? 'Successfully downloaded shared site, See site under \'SHARED\'' : 'Error downloading shared site! Permission denied. Ask Site Owner to authorise this share site with you first.',
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
              Navigator.pop(context);
            },
            width: 127,
            color: Theme.of(context).colorScheme.primary,
            height: 52,
            child: Text(
              "OK",
              style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ).show();


  }

  /// If dynamic link was found then deal with the deep link it comes with
  _dealWithDeepLink(PendingDynamicLinkData dynamicLink) async {
    if (kDebugMode) print ('... Dealing with deep link...');
    bool result = false;
    final Uri deepLink = dynamicLink.link;
    if (deepLink.data != null) {
      if (kDebugMode) print('Deeplink : $deepLink');
      if (kDebugMode) print('Deeplink path: ${deepLink.path}');
      if (deepLink.path.toString().contains('snagsnapper.produtiveapps.co.uk')){
        var url = '$deepLink';
        if (kDebugMode) print('DeepLink is a URL');
        if (await canLaunchUrlString(url)) {
          if (kDebugMode) print('----Launching URL----');
          await launchUrlString(url);
          if (kDebugMode) print('----Launching URL----');
          return;
        } else {
          if (kDebugMode) print('----Can\'t launch URL----');
          return;
        }
      } else {
        if (kDebugMode) print('Deeplink does NOT contain ::: snagsnapper.produtiveapps.co.uk');
        String? ownerID = deepLink.queryParameters['ownerID'];
        String? siteID = deepLink.queryParameters['siteID'];
        if (kDebugMode) print ('Owner UID Encrypted: $ownerID');
        if (kDebugMode) print ('Site UID Encrypted: $siteID');
        //ownerID = decryptText(ownerID??'');
        //siteID = decryptText(siteID??'');
        if (kDebugMode) print ('Owner UID: $ownerID');
        if (kDebugMode) print ('Site UID: $siteID');
      }
    }
    if (deepLink.queryParameters['ownerID'] != null && deepLink.queryParameters['siteID'] != null) {
      result = await Provider.of<CP>(context, listen: false).downloadSite(deepLink.queryParameters['ownerID']!, deepLink.queryParameters['siteID']!);
      // result = await Provider.of<CP>(context, listen: false).downloadSite(decryptText(deepLink.queryParameters['ownerID']!), decryptText(deepLink.queryParameters['siteID']!));
    }
    if (kDebugMode) print ('*** RESULT: $result');
    showPopUpResult(result);
  }
  
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print ('MAIN-MENU: -----  BUILD SECTION   -----');
    // if (Provider
    //     .of<CP>(context, listen: false)
    //     .getAppUser()!
    //     .image.isNotEmpty) print ('IS NOT EMPTY');
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 10.0, right: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ImageHelper(
                  b64Image: Provider
                      .of<CP>(context, listen: false)
                      .getAppUser()!
                      .image,
                  height: getProportionalHeightForTopImage(context,FRACTION),
                  text: 'Click to add your \ncompany logo',
                  callBackFunction :() async {
                    if (Provider.of<CP>(context, listen: false).getAppUser()!.image.isEmpty) {
                      String image = await optionsDialogBox(context, 2000) ?? ''; //TODO - FIX THE IMAGE RESOLUTION
                        if (image.isNotEmpty) setState(() => Provider.of<CP>(context, listen: false).getAppUser()!.image = image );
                      Provider.of<CP>(context, listen: false).updateProfileImage();
                    } else return;
                  }
              ),
              //const SizedBox(height: 50.0,),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    GestureDetector(
                        onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (
                            context) => const Profile())).then((value) => setState((){})),
                        child: const MainMenuItems(
                            Icons.person, 'Profile', 'View your profile')),
                    GestureDetector(
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (
                                context) => const MoreOptions())),
                        child: const MainMenuItems(
                            Icons.settings, 'More Options', 'View settings')),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/mySites');
                      },
                      child: const ActButton(busy: false, text: 'MY SITES')
                    ),

                  ],
                ),
              ),
              GestureDetector(
                  onTap: () => Provider.of<CP>(context, listen: false).changeBrightness(Theme.of(context).brightness==Brightness.light? Brightness.dark: Brightness.light),
                  child: ThemeSelector(Theme.of(context).brightness==Brightness.light? 'dark' : 'light')
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainMenuItems extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String subHeading;
  const MainMenuItems(this.icon, this.heading, this.subHeading, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
        border: Border.all(color: Theme.of(context).colorScheme.tertiaryContainer, width: 3.0),
        borderRadius: const BorderRadius.all(Radius.circular(30.0))
      ),
      padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(width: 10.0,),
              Icon (icon, color: Theme.of(context).colorScheme.onTertiaryContainer, size: 35.0,),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left:10.0),
                  child: RichText(
                    softWrap:true,
                    text: TextSpan(
                      children: <TextSpan>[
                        TextSpan(
                          text: '$heading\n',
                            style: GoogleFonts.roboto(textStyle: TextStyle(fontSize: 23, color: Theme.of(context).colorScheme.onTertiaryContainer))
                        ),
                        TextSpan(
                          text: subHeading,
                            style: GoogleFonts.montserrat(textStyle: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onTertiaryContainer))

                        )
                      ]
                    ),),
                ),
              ),
            ],
          ),
          // Container(
          //   margin: const EdgeInsets.only(top: 8.0, left: 0.0, right: 0.0),
          //   color: Theme.of(context).colorScheme.onTertiaryContainer,
          //   height: 1.0,
          //   width: double.infinity,),
        ],
      ),
    );
  }
}
