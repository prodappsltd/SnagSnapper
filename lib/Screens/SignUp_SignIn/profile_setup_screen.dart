import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/user.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart' as models;
import 'package:snagsnapper/services/sync_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Profile setup screen for new users after email verification
/// Collects required profile information before allowing access to the app
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ProfileSetupScreenState createState() => ProfileSetupScreenState();
}

class ProfileSetupScreenState extends State<ProfileSetupScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AppUser _appUser;
  
  // Animation controllers for modern UI
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  // Track which field is focused for visual feedback
  final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'job': FocusNode(),
    'company': FocusNode(),
    'phone': FocusNode(),
  };
  String _focusedField = '';
  
  // Get current Firebase user info
  User? get _firebaseUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      // Handle case where Firebase is not initialized (e.g., in tests)
      if (kDebugMode) {
        print('ProfileSetupScreen: Firebase not initialized - $e');
      }
      return null;
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we need to navigate away due to no authenticated user
    // Skip navigation in test mode (when Firebase is not initialized)
    if (_firebaseUser == null && mounted) {
      // Check if we're in a test environment by seeing if Firebase throws an error
      try {
        FirebaseAuth.instance.app; // This will throw if Firebase isn't initialized
        // Firebase is initialized but no user - navigate away
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      } catch (e) {
        // In test mode - don't navigate
        if (kDebugMode) {
          print('ProfileSetupScreen: Skipping navigation in test mode');
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('ProfileSetupScreen: Modern UI version loaded');
    }
    _initializeUserData();
    _setupAnimations();
    _setupFocusListeners();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeController.forward();
    _scaleController.forward();
  }
  
  void _setupFocusListeners() {
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        setState(() {
          _focusedField = node.hasFocus ? key : _focusedField;
        });
      });
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _focusNodes.forEach((_, node) => node.dispose());
    super.dispose();
  }

  /// Initialize user data with any available information
  void _initializeUserData() {
    // Create new AppUser instance
    _appUser = AppUser();
    
    // Pre-fill data from Firebase Auth if available
    if (_firebaseUser != null) {
      _appUser.email = _firebaseUser!.email?.toLowerCase() ?? '';
      // For Google Sign-In, displayName might be available
      if (_firebaseUser!.displayName != null && _firebaseUser!.displayName!.isNotEmpty) {
        _appUser.name = _firebaseUser!.displayName!;
      }
    }
    
    // Set in provider for image picker to work
    Provider.of<CP>(context, listen: false).setAppUser(_appUser);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
          // Modern gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.05),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),
          
          // Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Welcome Header with modern styling
                      const SizedBox(height: 32),
                      // Progress indicator
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 80),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Welcome text with emoji
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '👋',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Welcome to\n',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            TextSpan(
                              text: 'SnagSnapper',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Let\'s get your profile set up in just a few steps',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                  
                  // Profile Form with glassmorphism effect
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Name Field with modern design
                          _buildModernInputField(
                            icon: Icons.person_outline,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            initialValue: _appUser.name,
                            isFocused: _focusedField == 'name',
                            focusNode: _focusNodes['name'],
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) => _appUser.name = value.trim(),
                            validator: ValidationRules.validateName,
                            isRequired: true,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Job Title Field with modern design
                          _buildModernInputField(
                            icon: Icons.work_outline,
                            label: 'Job Title',
                            hint: 'e.g. Site Manager, Inspector',
                            isRequired: true,
                            isFocused: _focusedField == 'job',
                            focusNode: _focusNodes['job'],
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) => _appUser.jobTitle = value.trim(),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Job title is required';
                              }
                              return ValidationRules.validateJobTitle(value);
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Company Name Field with modern design
                          _buildModernInputField(
                            icon: Icons.business_outlined,
                            label: 'Company Name',
                            hint: 'Enter your company name',
                            isFocused: _focusedField == 'company',
                            focusNode: _focusNodes['company'],
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) => _appUser.companyName = value.trim(),
                            validator: ValidationRules.validateCompanyName,
                            isRequired: true,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Phone Field with modern design
                          _buildModernInputField(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            isFocused: _focusedField == 'phone',
                            focusNode: _focusNodes['phone'],
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp('[+0-9]'))
                            ],
                            onChanged: (value) => _appUser.phone = value.trim(),
                            validator: ValidationRules.validatePhone,
                            isRequired: true,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Email Field (Read-only) with modern design
                          _buildModernInputField(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            hint: '',
                            initialValue: _appUser.email,
                            enabled: false,
                            isFocused: false,
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Required fields note
                          Row(
                            children: [
                              Text(
                                '* ',
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Required fields',
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Complete Profile Button with gradient
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(
                                    red: theme.colorScheme.primary.r * 0.8,
                                    green: theme.colorScheme.primary.g * 0.8,
                                    blue: theme.colorScheme.primary.b * 0.8,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _completeProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Complete Profile',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sign Out Option
                  TextButton(
                    onPressed: _isLoading ? null : _handleSignOut,
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Generate unique device ID for this device
  Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId = '';
    String deviceName = '';
    
    try {
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = '${iosInfo.name} (${iosInfo.model})';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id ?? 'android_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Unknown Device';
      }
    } catch (e) {
      if (kDebugMode) print('Error generating device ID: $e');
      deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      deviceName = 'Unknown Device';
    }
    
    if (kDebugMode) {
      print('Generated Device ID: $deviceId');
      print('Device Name: $deviceName');
    }
    
    return deviceId;
  }
  
  /// Complete profile creation - OFFLINE FIRST
  Future<void> _completeProfile() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Get Firebase user
      final uid = _firebaseUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }
      
      // STEP 1: Generate device ID for this device (PRD 4.3.1 step 4)
      final deviceId = await _generateDeviceId();
      
      // STEP 2: Set default values for profile
      _appUser.dateFormat = 'dd-MM-yyyy';
      _appUser.listOfALLColleagues = [];
      _appUser.mapOfSitePaths = {};
      _appUser.signature = '';
      _appUser.postcodeOrArea = _appUser.postcodeOrArea ?? '';
      
      // STEP 3: SAVE TO LOCAL DATABASE FIRST (offline-first)
      if (kDebugMode) {
        print('OFFLINE-FIRST: Saving profile to LOCAL database...');
      }
      
      final db = await AppDatabase.getInstance();
      final profileDao = db.profileDao;
      
      // Create database model from AppUser
      final now = DateTime.now();
      final dbProfile = models.AppUser(
        id: uid,
        name: _appUser.name,
        email: _appUser.email,
        phone: _appUser.phone,
        jobTitle: _appUser.jobTitle,
        companyName: _appUser.companyName,
        postcodeOrArea: _appUser.postcodeOrArea,
        dateFormat: _appUser.dateFormat,
        currentDeviceId: deviceId,
        lastLoginTime: now,
        createdAt: now,
        updatedAt: now,
        needsProfileSync: true,  // Mark for sync since it's new
        needsImageSync: false,
        needsSignatureSync: false,
      );
      
      // Save to local database with duplicate check
      final profileExists = await profileDao.profileExists(uid);
      if (profileExists) {
        // Update existing profile
        await profileDao.updateProfile(uid, dbProfile);
        if (kDebugMode) {
          print('OFFLINE-FIRST: Updated existing profile in LOCAL database');
        }
      } else {
        // Insert new profile
        await profileDao.insertProfile(dbProfile);
        if (kDebugMode) {
          print('OFFLINE-FIRST: Inserted new profile to LOCAL database');
        }
      }
      
      if (kDebugMode) {
        print('OFFLINE-FIRST: Profile saved to LOCAL database successfully');
        print('  Device ID: $deviceId');
        print('  Needs sync: true');
      }
      
      // STEP 4: Update provider with new user data
      if (mounted) {
        Provider.of<CP>(context, listen: false).setAppUser(_appUser);
      }
      
      // STEP 5: Initialize SyncService for automatic background sync
      try {
        final syncService = SyncService.instance;
        
        // Initialize sync service with user ID
        if (!syncService.isInitialized) {
          await syncService.initialize(uid);
          
          // Setup auto-sync for when network becomes available
          syncService.setupAutoSync();
          
          if (kDebugMode) {
            print('SYNC: SyncService initialized for automatic background sync');
          }
        }
        
        // Check internet and trigger immediate sync if online
        final hasInternet = await Provider.of<CP>(context, listen: false)
            .getNetworkStatus();
        
        if (hasInternet) {
          // Trigger sync now (non-blocking)
          syncService.syncNow().then((_) {
            if (kDebugMode) print('SYNC: Initial sync triggered successfully');
          }).catchError((e) {
            if (kDebugMode) print('SYNC: Initial sync will retry automatically: $e');
          });
          
          // Also do legacy Firebase sync for immediate registration
          _syncProfileToFirebase(uid, deviceId).then((_) {
            if (kDebugMode) print('Background sync completed');
          }).catchError((e) {
            if (kDebugMode) print('Background sync error (will retry later): $e');
          });
        } else {
          if (kDebugMode) {
            print('OFFLINE-FIRST: No internet, profile will sync automatically when online');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SYNC: Error initializing SyncService: $e');
          print('SYNC: App will continue offline, sync will be attempted later');
        }
      }
      
      // STEP 6: Navigate to main menu (user can start using app immediately)
      if (mounted) {
        if (kDebugMode) {
          print('OFFLINE-FIRST: Navigating to main menu - app works offline!');
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/mainMenu',
          (route) => false,
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error creating profile: $error');
        print('Error type: ${error.runtimeType}');
        if (error is FirebaseException) {
          print('Firebase error code: ${error.code}');
          print('Firebase error message: ${error.message}');
          print('Firebase error details: ${error.stackTrace}');
        }
        print('Stack trace: $stackTrace');
      }
      
      String errorMessage = 'Could not create your profile. ';
      if (error.toString().contains('already exists')) {
        errorMessage = 'Profile already exists. Please contact support.';
      } else if (error.toString().contains('permission')) {
        errorMessage = 'Permission denied. This might be due to security rules. Please try again.';
      } else if (error.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      _showErrorMessage(
        errorMessage + ' If this error persists, please contact us at developer@productiveapps.co.uk'
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sync profile to Firebase in background (PRD 4.3.1 step 6c)
  Future<void> _syncProfileToFirebase(String uid, String deviceId) async {
    try {
      if (kDebugMode) {
        print('BACKGROUND SYNC: Starting Firebase sync...');
      }
      
      // Create profile data for Firebase
      final profileData = _appUser.toJson();
      profileData['currentDeviceId'] = deviceId;
      profileData['LAST_UPDATED'] = FieldValue.serverTimestamp();
      
      // Save to Firebase
      await FirebaseFirestore.instance
          .collection('Profile')
          .doc(uid)
          .set(profileData);
      
      // Register device in Realtime Database (PRD 4.3.1 step 6c)
      await FirebaseDatabase.instance
          .ref('device_sessions/$uid/current_device')
          .set({
        'device_id': deviceId,
        'device_name': Platform.operatingSystem,
        'last_active': ServerValue.timestamp,
        'force_logout': false,
      });
      
      // Clear sync flag in local database
      final db = await AppDatabase.getInstance();
      await db.profileDao.clearSyncFlags(uid);
      
      if (kDebugMode) {
        print('BACKGROUND SYNC: Profile synced to Firebase successfully');
        print('BACKGROUND SYNC: Device registered in Realtime Database');
      }
    } catch (e) {
      if (kDebugMode) {
        print('BACKGROUND SYNC: Error syncing to Firebase: $e');
        print('BACKGROUND SYNC: Will retry later when online');
      }
      // Don't throw - this is background operation
    }
  }
  
  /// Handle sign out
  Future<void> _handleSignOut() async {
    try {
      // Try to sign out from Firebase if available
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        if (kDebugMode) {
          print('Firebase signOut skipped: $e');
        }
      }
      
      if (mounted) {
        Provider.of<CP>(context, listen: false).resetVariables();
      }
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error signing out: $error');
      }
      _showErrorMessage('Error signing out. Please try again.');
    }
  }

  /// Show error message using Flushbar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    Flushbar(
      message: message,
      duration: const Duration(seconds: 4),
      backgroundColor: Theme.of(context).colorScheme.error,
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.onError,
      ),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
    ).show(context);
  }
  
  /// Build modern input field with animations
  Widget _buildModernInputField({
    required IconData icon,
    required String label,
    required String hint,
    String? initialValue,
    bool enabled = true,
    bool isOptional = false,
    bool isRequired = false,
    required bool isFocused,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: enabled
            ? (isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : theme.colorScheme.surface)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? theme.colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isFocused ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: initialValue,
        enabled: enabled,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        validator: validator,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: enabled
                  ? (isFocused
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant)
                  : theme.colorScheme.outline,
              size: 24,
            ),
          ),
          label: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: GoogleFonts.inter(
                    color: isFocused
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isOptional)
                  TextSpan(
                    text: ' (Optional)',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          errorStyle: GoogleFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }

}