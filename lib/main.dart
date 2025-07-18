import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/models/offerings_wrapper.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/PdfView.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/checkEmail.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/forgotPassword.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/signUp.dart';
import 'package:snagsnapper/Screens/Sites/mySites.dart';
import 'package:snagsnapper/Screens/moreOptions.dart';
import 'package:snagsnapper/Screens/pdfReportFormat.dart';
import 'package:snagsnapper/Screens/profile.dart';
import 'package:snagsnapper/Screens/shareScreen.dart';
import 'package:snagsnapper/Subscriptions/upSellSiteSharing.dart';
import 'package:snagsnapper/Subscriptions/upsellScreen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'Helper/purchasesHelper.dart';
import 'Screens/SignUp_SignIn/sign_in_sign_on.dart';
import 'Screens/mainMenu.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/signIn.dart';

import 'firebase_options.dart';

/// App/Program Entry point
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // So as the app does not sleep, screen always awake
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    // Enable crashlytics logs
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    runApp(const StartSnagSnapper());
  }, (error, stackTrace) {
    if (kDebugMode) print('runZonedGuarded: Caught error in my root zone.');
    FirebaseCrashlytics.instance.recordError(error, stackTrace);
  });
}

class StartSnagSnapper extends StatelessWidget {
  const StartSnagSnapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('StartSnagSnapper Rebuild');
    // Content provider class
    return ChangeNotifierProvider<CP>(
      create: (BuildContext context) => CP(),
      child: const MySubApp(),
    );
  }
}

/// After all initialisations, this is the entry point to app layout
class MySubApp extends StatefulWidget {
  const MySubApp({super.key});

  @override
  MySubAppState createState() => MySubAppState();
}

class MySubAppState extends State<MySubApp> {
  // Rate my app feature
  RateMyApp rateMyApp = RateMyApp(
    preferencesPrefix: 'rateMyApp_',
    minDays: 4,
    minLaunches: 10,
    remindDays: 7,
    remindLaunches: 8,
    googlePlayIdentifier: 'com.productiveapps.snagsnapper',
    appStoreIdentifier: '6474559094',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await rateMyApp.init();
      if (mounted && rateMyApp.shouldOpenDialog) {
        rateMyApp.showRateDialog(context,
            title: 'Please rate SnagSnapper',
            message: 'If this app has helped you, please consider a few minutes rating it as it helps a small business to support the app.',
            rateButton: 'RATE',
            noButton: 'NO THANKS',
            laterButton: 'MAYBE LATER',
            listener: (button) {
              switch (button) {
                case RateMyAppDialogButton.rate:
                  // TODO Something
                  break;
                case RateMyAppDialogButton.later:
                  // TODO Something
                  break;
                case RateMyAppDialogButton.no:
                  // TODO Something
                  break;
              }
              return true;
            },
            ignoreNativeDialog: Platform.isAndroid ? Platform.isAndroid : Platform.isIOS,
            onDismissed: () => {
                  // TODO Something as Later button is pressed
                });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('MySubApp Rebuild');
    return MaterialApp(
      debugShowCheckedModeBanner: kDebugMode,
      title: 'SnagSnapper',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Provider.of<CP>(context).seedColour,
          brightness: Provider.of<CP>(context).brightness,
          shadow: Colors.grey,
          contrastLevel: 0.3
        ),
        textTheme: TextTheme(
          labelLarge: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w400),
          labelMedium: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.montserrat(fontSize: 18),
          bodySmall: GoogleFonts.montserrat(fontSize: 14),
          headlineLarge: GoogleFonts.montserrat(fontSize: 40),
          headlineMedium: GoogleFonts.montserrat(fontSize: 30),
          headlineSmall: GoogleFonts.montserrat(fontSize: 20),
          titleSmall: GoogleFonts.montserrat(
            fontSize: 18,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      routes: <String, WidgetBuilder>{
        '/mainMenu': (BuildContext context) => const MainMenu(),
        '/moreOptions': (BuildContext context) => const MoreOptions(),
        '/login': (BuildContext context) => const SignInSignOnScreen(),
        '/profile': (BuildContext context) => const Profile(),
        '/mySites': (BuildContext context) => const MySites(),
        '/forgotPassword': (BuildContext context) => const ForgotPasswordScreen(),
        '/checkEmail': (BuildContext context) => const CheckEmailScreen(),
        '/signIn': (BuildContext context) => const SignInScreen(),
        '/signUp': (BuildContext context) => const SignUpScreen(),
        '/reportFormat': (BuildContext context) => const PDFReportFormat(),
        '/upgradeScreen': (BuildContext context) => const UpsellScreen(),
        '/upSellSiteSharing': (BuildContext context) => const UpSellSiteSharing(),
        '/pdfViewer': (BuildContext context) => const PdfViewer(),
        '/shareScreen': (BuildContext context) => const ShareScreen(),
      },
      home: const HomePage(),
    );
  }
}

// App layout starts here
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String message = 'Checking config...';

  ///This function does 3 things and executes FIRST in the app
  /// 1) Makes sure internet is available, including data exchange
  /// 2) Loads user profile from Firebase
  _executeInitialSetup() async {
    if (kDebugMode) await Future.delayed(const Duration(seconds: 1));
    //1 - Check internet
    if (!context.mounted) return "";
    bool status = await Provider.of<CP>(context, listen: false).getNetworkStatus();
    if (!status) return 'No internet';
    if (!context.mounted) return "";
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback,
    );
    if (kDebugMode) print(await FirebaseAppCheck.instance.getToken());
    return await _checkAndLoadUser();
  }

  /// If current user is null then return message as goto login else
  /// if gets the message as profile found OR Email not verified
  Future<String> _checkAndLoadUser() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) print('Sending -Goto Login');
      return 'Goto Login';
    }
    return await Provider.of<CP>(context,listen: false).loadProfileOfUser();
  }



  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('HomePage Rebuild');
    return FutureBuilder(
      future: _executeInitialSetup(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (kDebugMode) print(snapshot.connectionState);
        if (snapshot.connectionState == ConnectionState.done) {
          if (kDebugMode) print('SnapShot.data = ${snapshot.data}');
          if (snapshot.data == 'Goto Login' || snapshot.data == 'Email Not Verified' || snapshot.data == null) {
            if (kDebugMode) print('Should goto login page');
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              Navigator.pushReplacementNamed(context, "/login");
            });
            return Container();
          } else if (snapshot.data == 'No internet') {
            if (kDebugMode) print(' Show no internet warning');
            // Press reload and the whole thing loads again by calling setState
            return InternetErrorPage(() => setState(() {}), 'No internet');
          } else if (snapshot.data == 'RevCat Error') {
            if (kDebugMode) print('RevCat Initialisation Error');
            // Press reload and the whole thing loads again by calling setState
            return InternetErrorPage(
                () => setState(() {}), 'RevCat Initialisation error. If this error persists, please contact the developer on developer@productiveapps.co.uk');
          } else if (snapshot.data == 'Firebase Error') {
            if (kDebugMode) print('Firebase Load Profile Error');
            // Press reload and the whole thing loads again by calling setState
            return InternetErrorPage(
                () => setState(() {}), 'Error loading profile. If this error persists, please contact the developer on developer@productiveapps.co.uk');
          } else if (snapshot.data == 'Firebase Error Owned Sites') {
            if (kDebugMode) print('Firebase Load Owned Sites Error');
            // Press reload and the whole thing loads again by calling setState
            return InternetErrorPage(
                () => setState(() {}), 'Error loading owned sites. If this error persists, please contact the developer on developer@productiveapps.co.uk');
          } else if (snapshot.data == 'Firebase Error Shared Sites') {
            if (kDebugMode) print('Firebase Load Shared Sites Error');
            // Press reload and the whole thing loads again by calling setState
            return InternetErrorPage(
                () => setState(() {}), 'Error loading shared sites. If this error persists, please contact the developer on developer@productiveapps.co.uk');
          } else if (snapshot.data == 'Profile Found') {
            if (kDebugMode) print('Profile found, Enter App');
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              Navigator.pushReplacementNamed(context, "/mainMenu", arguments: Provider.of<CP>(context, listen: false).getAppUser());
            });
            return Container();
          }
        }
        return Scaffold(
          //backgroundColor: Theme.of(context).colorScheme.primary,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const AppIcon(),
              const SizedBox(
                width: 18.0,
              ),
              Container(
                //constraints: const BoxConstraints(maxWidth: 450),
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: const BorderRadius.all(Radius.circular(8.0))),
                child: Row(
                  children: <Widget>[
                    SpinKitRipple(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      size: 50.0,
                    ),
                    const SizedBox(
                      width: 8.0,
                    ),
                    Center(
                        child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer),
                    )),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: 150,
      margin: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage(
              'images/1024LowPoly.png',
            ),
            fit: BoxFit.contain),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
    );
  }
}

class InternetErrorPage extends StatelessWidget {
  final VoidCallback callBackFunction;
  final String errorText;
  const InternetErrorPage(this.callBackFunction, this.errorText, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          //const ShimmeringLogo(),
          Container(
            //constraints: const BoxConstraints(maxWidth: 450),
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: const BorderRadius.all(Radius.circular(8.0))),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onError,
                  size: 50.0,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                Flexible(
                  child: Text(
                    errorText,
                    style: GoogleFonts.montserrat(color: Theme.of(context).colorScheme.onError, fontSize: 20),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Positioned.fill(
                    child: Container(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer),
                )),
                TextButton(
                    onPressed: callBackFunction,
                    child: Text(
                      'Retry',
                      style: GoogleFonts.montserrat(fontSize: 18, color: Theme.of(context).colorScheme.onErrorContainer),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
