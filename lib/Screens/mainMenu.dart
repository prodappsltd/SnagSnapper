import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/moreOptions.dart';
// import 'package:snagsnapper/Screens/profile.dart'; // TODO: DELETE - Old profile replaced
// import 'package:snagsnapper/Screens/profile_cleaned.dart'; // TODO: DELETE - Temporary for comparison
import 'package:snagsnapper/screens/profile/profile_screen_ui_matched.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  _MainMenuState createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin, WidgetsBindingObserver {

  String message1='';
  String message2='';
  
  // Rate my app feature
  final RateMyApp _rateMyApp = RateMyApp(
    preferencesPrefix: 'rateMyApp_snagSnapper',
    minDays: 4,
    minLaunches: 10,
    remindDays: 7,
    remindLaunches: 8,
    googlePlayIdentifier: 'uk.co.productiveapps.snagsnapper',
    appStoreIdentifier: '6748839667',
  );
  
  // Sync service and connectivity
  late SyncService _syncService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasPendingSync = false;
  bool _isSyncInitialized = false;
  bool _profileNeedsSync = false;
  StreamSubscription? _profileSyncSubscription;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) print ('-----  * In Main Menu *  -----');
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await initDynamicLinks();
      await _initRateMyApp();
      await _initializeSyncService();
      _setupConnectivityListener();
      _checkForPendingSync();
      _setupProfileSyncListener();
    });
  }
  
  Future<void> _initRateMyApp() async {
    try {
      await _rateMyApp.init();
      if (mounted && _rateMyApp.shouldOpenDialog) {
        _rateMyApp.showRateDialog(
          context,
          title: 'Please rate SnagSnapper',
          message: 'If this app has helped you, please consider a few minutes rating it as it helps a small business to support the app.',
          rateButton: 'RATE',
          noButton: 'NO THANKS',
          laterButton: 'MAYBE LATER',
          listener: (button) {
            switch (button) {
              case RateMyAppDialogButton.rate:
                if (kDebugMode) print('User chose to rate the app');
                break;
              case RateMyAppDialogButton.later:
                if (kDebugMode) print('User chose maybe later');
                break;
              case RateMyAppDialogButton.no:
                if (kDebugMode) print('User declined to rate');
                break;
            }
            return true;
          },
          ignoreNativeDialog: Platform.isAndroid || Platform.isIOS,
          onDismissed: () {
            if (kDebugMode) print('Rate dialog dismissed');
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing RateMyApp: $e');
    }
  }
  
  void _setupAnimations() {
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // Slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Pulse animation for My Sites
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }
  
  /// Initialize sync service for background syncing
  Future<void> _initializeSyncService() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (kDebugMode) print('MainMenu: No user logged in, skipping sync initialization');
        return;
      }
      
      _syncService = SyncService.instance;
      
      // Initialize if not already done
      if (!_syncService.isInitialized) {
        await _syncService.initialize(userId);
      }
      
      // Setup auto-sync for connectivity changes
      _syncService.setupAutoSync();
      
      _isSyncInitialized = true;
      
      if (kDebugMode) print('MainMenu: SyncService initialized for background sync');
    } catch (e) {
      if (kDebugMode) print('MainMenu: Error initializing sync service: $e');
    }
  }
  
  /// Setup listener for connectivity changes
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (kDebugMode) print('MainMenu: Connectivity changed: $result');
      
      // When network becomes available, check for pending syncs
      if (!result.contains(ConnectivityResult.none)) {
        await _checkForPendingSync();
      }
    });
  }
  
  /// Setup listener for profile sync status changes
  void _setupProfileSyncListener() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final database = AppDatabase.instance;
    
    // Listen to profile sync status changes
    _profileSyncSubscription = database.profileDao.watchProfile(userId).listen((profile) {
      if (profile != null && mounted) {
        final needsSync = profile.needsProfileSync || 
                         profile.needsImageSync || 
                         profile.needsSignatureSync;
        
        setState(() {
          _profileNeedsSync = needsSync;
        });
        
        if (kDebugMode) print('MainMenu: Profile sync status changed - needsSync: $needsSync');
      }
    });
  }
  
  /// Check for pending sync items in background
  Future<void> _checkForPendingSync() async {
    if (!_isSyncInitialized) return;
    
    try {
      final database = AppDatabase.instance;
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) return;
      
      // Check if profile needs sync
      final profile = await database.profileDao.getProfile(userId);
      if (profile != null) {
        final needsSync = profile.needsProfileSync || 
                         profile.needsImageSync || 
                         profile.needsSignatureSync;
        
        if (needsSync && mounted) {
          setState(() {
            _hasPendingSync = true;
            _profileNeedsSync = true;
          });
          
          if (kDebugMode) print('MainMenu: Found pending sync items, triggering background sync...');
          
          // Trigger sync in background (non-blocking)
          _syncService.syncNow().then((result) {
            if (result.success && mounted) {
              setState(() {
                _hasPendingSync = false;
              });
              if (kDebugMode) print('MainMenu: Background sync completed successfully');
            }
          }).catchError((e) {
            if (kDebugMode) print('MainMenu: Background sync error: $e');
          });
        } else if (mounted) {
          setState(() {
            _profileNeedsSync = false;
          });
        }
      }
      
      // TODO: In future, also check for pending Sites and Snags sync
      
    } catch (e) {
      if (kDebugMode) print('MainMenu: Error checking for pending sync: $e');
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes to foreground, check for pending syncs
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) print('MainMenu: App resumed, checking for pending syncs...');
      _checkForPendingSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _profileSyncSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    if (kDebugMode) print('MainMenu: Disposed with sync cleanup');
    super.dispose();
  }

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
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background with modern gradient mesh
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, -0.5),
                radius: 1.5,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.3),
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),
          
          // Animated background shapes
          Positioned(
            top: -100,
            right: -100,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.secondary.withValues(alpha: 0.2),
                      theme.colorScheme.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top section with title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'SnagSnapper',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Project Management Made Simple',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // My Sites - Hero Button
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/mySites');
                              },
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withValues(
                                        red: theme.colorScheme.primary.r * 0.8,
                                        green: theme.colorScheme.primary.g * 0.8,
                                        blue: theme.colorScheme.primary.b * 0.8,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                      blurRadius: 60,
                                      offset: const Offset(0, 25),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Decorative elements
                                    Positioned(
                                      right: -30,
                                      top: -30,
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: -20,
                                      bottom: -20,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.05),
                                        ),
                                      ),
                                    ),
                                    // Content
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.dashboard_rounded,
                                              color: Colors.white,
                                              size: 50,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'MY SITES',
                                            style: GoogleFonts.poppins(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Manage all your projects',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(50),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'ENTER',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Bottom options - minimal design
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        // Profile button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to profile screen with offline-first implementation
                              Navigator.pushNamed(context, '/profile');
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Button container
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Profile',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Sync indicator badge
                                if (_profileNeedsSync)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.colorScheme.surface,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.error.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.sync,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Settings button
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.push(context, MaterialPageRoute(builder: (
                                    context) => const MoreOptions())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    color: theme.colorScheme.secondary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Settings',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy widget kept for compatibility - not used in new design
class MainMenuItems extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String subHeading;
  const MainMenuItems(this.icon, this.heading, this.subHeading, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
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
        ],
      ),
    );
  }
}




