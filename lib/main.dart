import 'dart:async';
import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/PdfView.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/checkEmail.dart';
import 'package:snagsnapper/Screens/SignUp_SignIn/forgotPassword.dart';
// import 'package:snagsnapper/Screens/SignUp_SignIn/signUp.dart'; // TODO: DELETE - Replaced by ProfileSetupScreen
import 'package:snagsnapper/Screens/Sites/mySites.dart';
import 'package:snagsnapper/Screens/moreOptions.dart';
import 'package:snagsnapper/Screens/pdfReportFormat.dart';
import 'package:snagsnapper/Screens/profile.dart';
import 'package:snagsnapper/Screens/shareScreen.dart';
import 'package:snagsnapper/Subscriptions/upSellSiteSharing.dart';
import 'package:snagsnapper/Subscriptions/upsellScreen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'Screens/SignUp_SignIn/unified_auth_screen.dart';
import 'Screens/SignUp_SignIn/profile_setup_screen.dart';
import 'Screens/mainMenu.dart';
// import 'package:snagsnapper/Screens/SignUp_SignIn/signIn.dart'; // TODO: DELETE - Replaced by UnifiedAuthScreen
import 'package:snagsnapper/Screens/splash_screen.dart';
import 'package:snagsnapper/Screens/custom_theme_selector.dart';
import 'package:snagsnapper/Constants/initialization_state.dart';
import 'package:snagsnapper/Constants/custom_color_schemes.dart';

import 'firebase_options.dart';

/// App/Program Entry point
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with proper error handling
    try {
      // Check if Firebase is already initialized to prevent duplicate app error
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (kDebugMode) print('Firebase initialized successfully');
        
        // Initialize Firebase App Check immediately after core initialization for better security
        // For iOS physical devices, we need to use deviceCheck in debug mode
        final isIOSDevice = Platform.isIOS && !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
        
        await FirebaseAppCheck.instance.activate(
          androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider: kDebugMode && !isIOSDevice 
              ? AppleProvider.debug 
              : AppleProvider.appAttestWithDeviceCheckFallback,
        );
        
        if (kDebugMode) {
          print('Firebase App Check activated');
          print('Platform: ${Platform.operatingSystem}');
          print('Is iOS Device: $isIOSDevice');
          
          // Only try to get token for Android or iOS Simulator in debug mode
          if (Platform.isAndroid || (Platform.isIOS && !isIOSDevice)) {
            try {
              final token = await FirebaseAppCheck.instance.getToken(true);
              print('App Check token obtained: ${token != null}');
            } catch (e) {
              print('Debug token fetch error (expected on iOS device): $e');
            }
          }
        }
      }
      
      // Set up crash reporting handlers after successful Firebase initialization
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      // Enable crashlytics logs
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
    } catch (e, stackTrace) {
      // Log Firebase initialization error
      if (kDebugMode) {
        print('Firebase initialization error: $e');
        print('Stack trace: $stackTrace');
      }
      // Continue app execution but with limited Firebase functionality
    }
    
    // Configure device settings (these can continue even if Firebase fails)
    // So as the app does not sleep, screen always awake
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
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
  ColorScheme _getColorScheme(Brightness brightness, String themeType) {
    if (brightness == Brightness.light) {
      switch (themeType) {
        case 'safety':
          return CustomColorSchemes.safetyOrangeLight;
        case 'orange':
        default:
          return CustomColorSchemes.orangeLight;
      }
    } else {
      // For now, always use orangeDark for dark mode
      return CustomColorSchemes.orangeDark;
    }
  }
  
  // Rate my app feature
  RateMyApp rateMyApp = RateMyApp(
    preferencesPrefix: 'rateMyApp_',
    minDays: 4,
    minLaunches: 10,
    remindDays: 7,
    remindLaunches: 8,
    googlePlayIdentifier: 'uk.co.productiveapps.snagsnapper',
    appStoreIdentifier: '6748839667',
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
            ignoreNativeDialog: Platform.isAndroid || Platform.isIOS,
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
        colorScheme: _getColorScheme(
          Provider.of<CP>(context).brightness,
          Provider.of<CP>(context).themeType,
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
        '/login': (BuildContext context) => const UnifiedAuthScreen(),
        '/profile': (BuildContext context) => const Profile(),
        '/profileSetup': (BuildContext context) => const ProfileSetupScreen(),
        '/mySites': (BuildContext context) => const MySites(),
        '/forgotPassword': (BuildContext context) => const ForgotPasswordScreen(),
        '/checkEmail': (BuildContext context) => const CheckEmailScreen(),
        // '/signIn': (BuildContext context) => const SignInScreen(), // TODO: DELETE - Replaced by UnifiedAuthScreen
        // '/signUp': (BuildContext context) => const SignUpScreen(), // TODO: DELETE - Replaced by ProfileSetupScreen
        '/reportFormat': (BuildContext context) => const PDFReportFormat(),
        '/upgradeScreen': (BuildContext context) => const UpsellScreen(),
        '/upSellSiteSharing': (BuildContext context) => const UpSellSiteSharing(),
        '/pdfViewer': (BuildContext context) => const PdfViewer(),
        '/shareScreen': (BuildContext context) => const ShareScreen(),
        '/themeSelector': (BuildContext context) => const CustomThemeSelector(),
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
  /// Status message displayed on splash screen
  /// Updates during different initialization phases to inform user
  String message = 'Checking config...';
  
  /// Tracks when splash screen started to ensure minimum display time
  /// Used to calculate remaining time for splash screen duration
  late DateTime _splashStartTime;
  
  /// Stores the initialization future to prevent re-execution on rebuilds
  /// This ensures network calls and Firebase operations only happen once
  late Future<InitializationState> _initializationFuture;
  
  /// Stores user data retrieved during initialization
  /// Prevents Provider access after async delays which could cause errors
  /// Only populated when state is profileFound
  dynamic _userDataForNavigation;

  @override
  void initState() {
    super.initState();
    // Record splash screen start time for minimum display duration
    _splashStartTime = DateTime.now();
    
    // Add debug breadcrumb for splash screen start
    if (kDebugMode) {
      print('Splash screen started at: $_splashStartTime');
    } else {
      FirebaseCrashlytics.instance.log('Splash screen started');
    }
    
    // Initialize the future once to prevent re-execution
    _initializationFuture = _executeInitialSetup();
  }

  /// Executes app initialization with minimum splash screen duration
  /// Runs initialization and splash duration timer in parallel for efficiency
  /// Returns the initialization state once both complete
  Future<InitializationState> _executeInitialSetup() async {
    // Execute initialization and minimum splash duration in parallel
    // This ensures splash shows for minimum time while work is being done
    final results = await Future.wait<dynamic>([
      _performInitialization(),
      _ensureMinimumSplashDuration(),
    ]);
    
    // Return the initialization state (first element of results)
    return results[0] as InitializationState;
  }
  
  /// Ensures splash screen is displayed for minimum duration
  Future<void> _ensureMinimumSplashDuration() async {
    final elapsedTime = DateTime.now().difference(_splashStartTime);
    // Splash screen minimum duration for production
    final minimumDuration = const Duration(seconds: 3); // Production: 3s
    final remainingTime = minimumDuration - elapsedTime;
    
    if (remainingTime > Duration.zero) {
      // Wait for remaining time to complete minimum duration
      if (kDebugMode) print('Waiting ${remainingTime.inMilliseconds}ms to complete splash duration');
      await Future.delayed(remainingTime);
    } else {
      // Already displayed for minimum duration
      if (kDebugMode) print('Splash screen already displayed for ${elapsedTime.inMilliseconds}ms');
    }
  }
  
  /// Performs actual app initialization steps
  /// Checks network, verifies Firebase, and loads user profile
  /// Updates status message during each phase
  /// Returns appropriate InitializationState based on results
  Future<InitializationState> _performInitialization() async {
    try {
      // Phase 1: Check widget is still mounted
      if (!mounted) return InitializationState.contextError;
      
      // Phase 2: Check internet connectivity
      if (mounted) {
        setState(() => message = 'Checking internet connection...');
      }
      bool hasInternet = await Provider.of<CP>(context, listen: false).getNetworkStatus();
      if (!hasInternet) {
        // Log breadcrumb for no internet
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.log('Initialization failed: No internet connection');
        }
        return InitializationState.noInternet;
      }
      
      // Verify still mounted after async operation
      if (!mounted) return InitializationState.contextError;
      
      // Phase 3: Firebase App Check verification (non-blocking)
      if (mounted) {
        setState(() => message = 'Verifying app security...');
      }
      
      // Skip App Check token verification on iOS physical devices in debug mode
      final isIOSDevice = Platform.isIOS && !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
      final shouldVerifyToken = !kDebugMode || (kDebugMode && !isIOSDevice);
      
      if (shouldVerifyToken) {
        try {
          final token = await FirebaseAppCheck.instance.getToken();
          if (kDebugMode) print('App Check token verified: ${token != null}');
          if (!kDebugMode) FirebaseCrashlytics.instance.log('App Check token verified');
        } catch (e) {
          if (kDebugMode) print('App Check token error: $e');
          // App Check errors don't block startup - continue
        }
      } else {
        if (kDebugMode) print('Skipping App Check token verification on iOS device in debug mode');
      }
      
      if (!kDebugMode) {
        // Production breadcrumb for successful network check
        FirebaseCrashlytics.instance.log('Network check passed');
      }
      
      // Phase 4: Check and load user profile
      if (mounted) {
        setState(() => message = 'Loading user profile...');
      }
      return await _checkAndLoadUser();
      
    } catch (e, stackTrace) {
      // Log unexpected errors with full context
      if (kDebugMode) {
        print('Initialization error: $e');
        print('Stack trace: $stackTrace');
      } else {
        // Production error logging with breadcrumb
        FirebaseCrashlytics.instance.log('Initialization failed with exception');
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
      return InitializationState.initializationError;
    }
  }

  /// Checks Firebase authentication status and loads user profile
  /// Returns appropriate state based on auth status and profile loading result
  /// Stores user data for navigation if profile is successfully loaded
  Future<InitializationState> _checkAndLoadUser() async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) {
        print('No authenticated user - navigating to login');
      } else {
        // Production breadcrumb
        FirebaseCrashlytics.instance.log('User not authenticated');
      }
      return InitializationState.goToLogin;
    }
    
    // Verify widget is still mounted
    if (!mounted) return InitializationState.contextError;
    
    // Load user profile from Firebase
    final result = await Provider.of<CP>(context, listen: false).loadProfileOfUser();
    
    if (kDebugMode) {
      print('_checkAndLoadUser: loadProfileOfUser returned: "$result"');
    }
    
    // Convert legacy string response to enum
    // Workaround: Manual conversion due to extension method issue
    InitializationState state;
    switch (result) {
      case 'Profile Not Found':
        state = InitializationState.profileNotFound;
        break;
      case 'Profile Found':
        state = InitializationState.profileFound;
        break;
      case 'Goto Login':
        state = InitializationState.goToLogin;
        break;
      case 'Email Not Verified':
        state = InitializationState.emailNotVerified;
        break;
      case 'No internet':
        state = InitializationState.noInternet;
        break;
      case 'Firebase Error':
        state = InitializationState.firebaseError;
        break;
      case 'Firebase Error Owned Sites':
        state = InitializationState.firebaseErrorOwnedSites;
        break;
      case 'Firebase Error Shared Sites':
        state = InitializationState.firebaseErrorSharedSites;
        break;
      default:
        state = InitializationState.unknownError;
    }
    
    // If user is authenticated but profile not found, they need to complete profile setup
    // This handles the case where auth exists but profile doesn't (new users)
    if (state == InitializationState.profileNotFound) {
      if (kDebugMode) {
        print('User authenticated but profile not found - navigating to profile setup');
      }
      // Return profileNotFound state to navigate to profile setup
      return InitializationState.profileNotFound;
    }
    
    // If profile is successfully loaded, store user data for navigation
    if (state == InitializationState.profileFound && mounted) {
      _userDataForNavigation = Provider.of<CP>(context, listen: false).getAppUser();
      
      // Production breadcrumb for successful profile load
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.log('User profile loaded successfully');
      }
    }
    
    return state;
  }

  /// Handles navigation based on initialization state
  /// Validates routes exist before navigating
  /// Only navigates for states that require navigation
  void _handleNavigation(InitializationState state) {
    if (!mounted) return;
    
    // Debug logging
    if (kDebugMode) {
      print('Handling navigation for state: ${state.name}');
    }
    
    // Only navigate if state requires it
    if (!state.shouldNavigate) return;
    
    // Get the route name for this state
    final routeName = state.routeName;
    if (routeName == null) return;
    
    // Note: Route validation simplified as Flutter doesn't expose route table at runtime
    // Routes are defined in MySubApp widget and assumed to be correct
    
    // Perform navigation based on state
    switch (state) {
      case InitializationState.goToLogin:
      case InitializationState.emailNotVerified:
      case InitializationState.profileNotFound:
        Navigator.pushReplacementNamed(context, routeName);
        break;
      case InitializationState.profileFound:
        Navigator.pushReplacementNamed(
          context, 
          routeName, 
          arguments: _userDataForNavigation
        );
        break;
      default:
        // Other states don't navigate
        break;
    }
    
    // Production breadcrumb for navigation
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.log('Navigated to: $routeName');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print('HomePage build');
    
    return FutureBuilder<InitializationState>(
      future: _initializationFuture,
      builder: (BuildContext context, AsyncSnapshot<InitializationState> snapshot) {
        if (kDebugMode) print('FutureBuilder: ${snapshot.connectionState}');
        
        // Show splash screen while loading
        if (snapshot.connectionState != ConnectionState.done) {
          return SplashScreen(message: message);
        }
        
        // Handle completed state with proper null safety
        final state = snapshot.data ?? InitializationState.unknownError;
        if (kDebugMode) print('Initialization state: ${state.name}');
        
        // Handle navigation for states that require it
        if (state.shouldNavigate) {
          // Use post frame callback to avoid building during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNavigation(state);
          });
          // Show splash screen during navigation
          return SplashScreen(message: message);
        }
        
        // Handle error states
        if (state.isError) {
          // Create retry callback that properly resets initialization
          void retryCallback() => setState(() {
            // Reset splash start time for new minimum duration
            _splashStartTime = DateTime.now();
            // Reset message to initial state
            message = 'Checking config...';
            // Create new initialization future
            _initializationFuture = _executeInitialSetup();
          });
          
          // Get error message from state or use default
          final errorMessage = state.errorMessage ?? 'An unexpected error occurred';
          
          // Return error page with appropriate message
          return InternetErrorPage(retryCallback, errorMessage);
        }
        
        // Fallback for any unhandled states (shouldn't happen with proper enum)
        if (kDebugMode) {
          print('Warning: Unhandled initialization state: ${state.name}');
        }
        return InternetErrorPage(
          () => setState(() {
            _splashStartTime = DateTime.now();
            message = 'Checking config...';
            _initializationFuture = _executeInitialSetup();
          }), 
          'Unexpected state: ${state.name}. Please restart the app.'
        );
      },
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
