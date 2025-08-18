import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:io' show Platform;

// Database and models
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';

/// Profile Setup Screen with Database Integration
/// 
/// Implements PRD Section 4 (Profile Module Requirements):
/// - Saves to local database immediately (offline-first)
/// - Sets sync flags for background Firebase sync
/// - Generates unique device ID for single-device enforcement
/// - Validates all fields per PRD 4.5.1
/// 
/// User Flow (PRD 4.3.1):
/// 1. New user logs in → No local profile found
/// 2. Shows this screen to collect required info
/// 3. Saves to local database with sync flags
/// 4. Navigates to main app
/// 5. Background sync happens when online
class ProfileSetupScreen extends StatefulWidget {
  final AppDatabase? database; // Optional for testing
  final FirebaseAuth? auth; // Optional for testing
  
  const ProfileSetupScreen({
    super.key,
    this.database,
    this.auth,
  });

  @override
  ProfileSetupScreenState createState() => ProfileSetupScreenState();
}

class ProfileSetupScreenState extends State<ProfileSetupScreen> 
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Form field values
  String _name = '';
  String _jobTitle = '';
  String _companyName = '';
  String _phone = '';
  String _email = ''; // From Firebase Auth
  String _userId = ''; // Firebase UID
  String? _errorMessage;
  
  // Dependencies
  late AppDatabase _database;
  late FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
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

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('ProfileSetupScreen: Initializing with database integration');
    }
    
    // Initialize dependencies (use injected ones for testing)
    _database = widget.database ?? AppDatabase.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;
    
    _setupAnimations();
    _setupFocusListeners();
    _initializeUserData();
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
      curve: Curves.elasticOut,
    ));
    
    _fadeController.forward();
    _scaleController.forward();
  }

  void _setupFocusListeners() {
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        if (mounted) {
          setState(() {
            _focusedField = node.hasFocus ? key : _focusedField;
          });
        }
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

  /// Initialize user data from authentication
  /// Implements PRD 4.3.1: Check local database for existing profile
  Future<void> _initializeUserData() async {
    try {
      // Get authenticated user
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('ProfileSetupScreen: No authenticated user found');
        }
        // Should not happen, but handle gracefully
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }
      
      // Set user data from auth
      setState(() {
        _userId = user.uid;
        _email = user.email ?? '';
      });
      
      if (kDebugMode) {
        print('ProfileSetupScreen: User ID: $_userId, Email: $_email');
      }
      
      // Check if profile already exists in local database
      final existingProfile = await _database.profileDao.getProfile(_userId);
      
      if (existingProfile != null) {
        if (kDebugMode) {
          print('ProfileSetupScreen: Existing profile found, navigating to main app');
        }
        // Profile exists, navigate to main app
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );
        }
      }
      // Else stay on this screen for profile setup
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ProfileSetupScreen: Error initializing user data - $e');
      }
      // Log to Crashlytics in production (skip in tests)
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Failed to initialize profile setup',
          fatal: false,
        );
      }
    }
  }
  
  /// Generate unique device ID per PRD 4.3.1c
  Future<String> _generateDeviceId() async {
    try {
      String deviceId = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id; // Android ID
        if (kDebugMode) {
          print('ProfileSetupScreen: Android device ID: $deviceId');
        }
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? ''; // iOS vendor ID
        if (kDebugMode) {
          print('ProfileSetupScreen: iOS device ID: $deviceId');
        }
      }
      
      // Fallback to timestamp-based ID if platform-specific ID fails
      if (deviceId.isEmpty) {
        deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
        if (kDebugMode) {
          print('ProfileSetupScreen: Generated fallback device ID: $deviceId');
        }
      }
      
      return deviceId;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSetupScreen: Error generating device ID - $e');
      }
      // Return timestamp-based ID as fallback
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Save profile to database
  /// Implements PRD 4.3.1c: Save to local database with sync flags
  Future<void> _saveProfile() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) {
        print('ProfileSetupScreen: Form validation failed');
      }
      return;
    }
    
    // Save form state to get latest values
    _formKey.currentState!.save();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Log breadcrumb for debugging (skip in tests)
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await FirebaseCrashlytics.instance.log('Starting profile save');
      }
      
      // Generate device ID per PRD 4.3.1c
      final deviceId = await _generateDeviceId();
      
      // Create AppUser model with all PRD required fields
      final now = DateTime.now();
      final user = AppUser(
        id: _userId, // Firebase UID as primary key (PRD 4.2.2)
        name: _name.trim(),
        email: _email.trim(),
        phone: _phone.trim(),
        jobTitle: _jobTitle.trim(),
        companyName: _companyName.trim(),
        postcodeOrArea: null, // Optional in setup
        dateFormat: 'dd-MM-yyyy', // Default per PRD 4.2.1
        
        // Image paths - null for new profile
        imageLocalPath: null,
        imageFirebaseUrl: null,
        signatureLocalPath: null,
        signatureFirebaseUrl: null,
        
        // Sync flags - PRD 4.3.1c: "Mark needs_sync = true"
        needsProfileSync: true, // CRITICAL: Must sync to Firebase
        needsImageSync: false, // No image yet
        needsSignatureSync: false, // No signature yet
        lastSyncTime: null, // Never synced
        
        // Device management - PRD 4.3.1c
        currentDeviceId: deviceId,
        lastLoginTime: now,
        
        // Timestamps
        createdAt: now,
        updatedAt: now,
        
        // Versioning
        localVersion: 1,
        firebaseVersion: 0, // Not synced yet
      );
      
      if (kDebugMode) {
        print('ProfileSetupScreen: Saving profile for user $_userId');
        print('ProfileSetupScreen: Device ID: $deviceId');
        print('ProfileSetupScreen: Sync flag: ${user.needsProfileSync}');
      }
      
      // Save to local database (offline-first per PRD 1.2)
      final success = await _database.profileDao.insertProfile(user);
      
      if (success) {
        if (kDebugMode) {
          print('ProfileSetupScreen: Profile saved successfully to local database');
        }
        
        // Log success breadcrumb (skip in tests)
        if (!Platform.environment.containsKey('FLUTTER_TEST')) {
          await FirebaseCrashlytics.instance.log('Profile saved successfully');
        }
        
        // Navigate to main app - PRD 4.3.1c: "Navigate to main app"
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );
        }
        
        // Background sync will happen automatically when online
        // via sync service (Phase 3)
      } else {
        throw Exception('Failed to save profile to database');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ProfileSetupScreen: Error saving profile - $e');
      }
      
      // Log error to Crashlytics (skip in tests)
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await FirebaseCrashlytics.instance.recordError(
          e,
          stackTrace,
          reason: 'Failed to save profile during setup',
          fatal: false,
        );
      }
      
      // Show error to user
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save profile. Please try again.';
      });
      
      // Show snackbar with error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _saveProfile,
              textColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        );
      }
    } finally {
      if (mounted && _errorMessage == null) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Build modern input field with animations
  Widget _buildModernInputField({
    required IconData icon,
    required String label,
    required String hint,
    required FocusNode focusNode,
    required Function(String?) onSaved,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = true,
  }) {
    final theme = Theme.of(context);
    final isFocused = _focusedField == focusNode.debugLabel;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isFocused 
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: isFocused ? 2 : 1,
        ),
      ),
      child: TextFormField(
        focusNode: focusNode,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              icon,
              color: isFocused 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          labelText: label + (isRequired ? ' *' : ''),
          hintText: hint,
          labelStyle: GoogleFonts.inter(
            color: isFocused
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          errorStyle: GoogleFonts.inter(
            color: theme.colorScheme.error,
            fontSize: 12,
          ),
        ),
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background gradient
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
              width: 250,
              height: 250,
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
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo or App Icon
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(bottom: 32),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.construction_rounded,
                              size: 50,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          
                          // Welcome text
                          Text(
                            'Complete Your Profile',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tell us about yourself to get started',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_email.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _email,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                          
                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.9),
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
                                  // Name field
                                  _buildModernInputField(
                                    icon: Icons.person_outline,
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    focusNode: _focusNodes['name']!,
                                    keyboardType: TextInputType.name,
                                    textCapitalization: TextCapitalization.words,
                                    onSaved: (value) => _name = value?.trim() ?? '',
                                    validator: ValidationRules.validateName,
                                  ),
                                  
                                  // Job Title field
                                  _buildModernInputField(
                                    icon: Icons.work_outline,
                                    label: 'Job Title',
                                    hint: 'e.g. Site Manager, Inspector',
                                    focusNode: _focusNodes['job']!,
                                    textCapitalization: TextCapitalization.words,
                                    onSaved: (value) => _jobTitle = value?.trim() ?? '',
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Job title is required';
                                      }
                                      return ValidationRules.validateJobTitle(value);
                                    },
                                  ),
                                  
                                  // Company field
                                  _buildModernInputField(
                                    icon: Icons.business_outlined,
                                    label: 'Company Name',
                                    hint: 'Enter your company name',
                                    focusNode: _focusNodes['company']!,
                                    textCapitalization: TextCapitalization.words,
                                    onSaved: (value) => _companyName = value?.trim() ?? '',
                                    validator: ValidationRules.validateCompanyName,
                                  ),
                                  
                                  // Phone field
                                  _buildModernInputField(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone Number',
                                    hint: 'Enter your phone number',
                                    focusNode: _focusNodes['phone']!,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp('[+0-9]')),
                                    ],
                                    onSaved: (value) => _phone = value?.trim() ?? '',
                                    validator: ValidationRules.validatePhone,
                                  ),
                                  
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: theme.colorScheme.onErrorContainer,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: theme.colorScheme.onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  
                                  // Submit button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  theme.colorScheme.onPrimary,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              'Complete Setup',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}