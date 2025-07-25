import 'package:another_flushbar/flushbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      _appUser.email = _firebaseUser!.email ?? '';
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
      body: Stack(
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
    );
  }

  /// Complete profile creation
  Future<void> _completeProfile() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Check internet connection
    final hasInternet = await Provider.of<CP>(context, listen: false)
        .getNetworkStatus();
    if (!hasInternet) {
      _showErrorMessage('No internet connection. Please check your connection and try again.');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Check if email is verified
      if (_firebaseUser?.emailVerified != true) {
        throw Exception('Email not verified. Please verify your email before creating a profile.');
      }
      
      // Set default values for profile
      _appUser.dateFormat = 'dd-MM-yyyy';
      _appUser.listOfALLColleagues = [];
      _appUser.mapOfSitePaths = {};
      _appUser.signature = '';
      _appUser.postcodeOrArea = '';
      
      // Create profile in Firestore
      final uid = _firebaseUser?.uid;
      if (uid == null) {
        throw Exception('No authenticated user found');
      }
      
      // Check if profile already exists
      if (kDebugMode) {
        print('Checking if profile exists for UID: $uid');
      }
      
      final profileDoc = await FirebaseFirestore.instance
          .collection('Profile')
          .doc(uid)
          .get();
          
      if (profileDoc.exists) {
        if (kDebugMode) {
          print('Profile already exists! Cannot create duplicate.');
        }
        throw Exception('Profile already exists for this user. Please check Firebase Console and delete the existing profile.');
      } else {
        if (kDebugMode) {
          print('No existing profile found. Proceeding with creation.');
        }
      }
      
      // Create the profile data with required fields
      final profileData = _appUser.toJson();
      
      // Add the LAST_UPDATED timestamp field required by Firebase rules
      profileData['LAST_UPDATED'] = FieldValue.serverTimestamp();
      
      if (kDebugMode) {
        print('Profile data being sent to Firebase:');
        profileData.forEach((key, value) {
          if (key != 'LAST_UPDATED') {
            print('  $key: ${value is String && value.length > 50 ? value.substring(0, 50) + '...' : value}');
          } else {
            print('  $key: [ServerTimestamp]');
          }
        });
        print('  Auth email: ${_firebaseUser?.email}');
        print('  Auth UID: ${_firebaseUser?.uid}');
        print('  Email verified: ${_firebaseUser?.emailVerified}');
      }
      
      await FirebaseFirestore.instance
          .collection('Profile')
          .doc(uid)
          .set(profileData);
      
      if (kDebugMode) {
        print('Profile created successfully for user: ${_firebaseUser!.uid}');
      }
      
      // Update provider with new user data
      if (mounted) {
        Provider.of<CP>(context, listen: false).setAppUser(_appUser);
      }
      
      // Navigate to main menu
      if (mounted) {
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