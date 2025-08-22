import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'signature_capture_screen.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'package:snagsnapper/Widgets/reusable_image_picker.dart';
import 'components/colleagues_section.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:snagsnapper/services/sync/device_manager.dart';

/// Profile Screen with offline-first database integration
/// UI matches the original profile_cleaned.dart design
/// Implements PRD Section 4 requirements
class ProfileScreen extends StatefulWidget {
  final AppDatabase database;
  final String userId;
  final ImageStorageService imageStorageService;
  final bool isOffline;

  ProfileScreen({
    super.key,
    required this.database,
    required this.userId,
    ImageStorageService? imageStorageService,
    this.isOffline = false,
  }) : imageStorageService = imageStorageService ?? ImageStorageService.instance;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _jobTitleController;
  late TextEditingController _companyNameController;
  late TextEditingController _postcodeController;
  
  // State variables
  AppUser? _currentUser;
  bool dateBritish = true;
  String? _profileImagePath;
  String? _signaturePath;
  List<Colleague> _colleagues = []; // List of colleagues
  int _imageVersion = 0; // Counter to force image widget rebuilds
  int _signatureVersion = 0; // Counter to force signature widget rebuilds
  bool _isLoading = true;
  bool busy = false;
  bool _isDirty = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Track which field is focused for UI effects
  final Map<String, FocusNode> _focusNodes = {
    'name': FocusNode(),
    'job': FocusNode(),
    'company': FocusNode(),
    'postcode': FocusNode(),
    'phone': FocusNode(),
    'email': FocusNode(),
  };
  String _focusedField = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeControllers();
    _setupAnimations();
    _setupFocusListeners();
    _loadProfile();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger sync check when app comes to foreground
      _checkAndSyncIfNeeded();
    }
  }

  Future<void> _checkAndSyncIfNeeded() async {
    if (_currentUser != null) {
      // No longer trigger sync from profile screen
      // MainMenu handles all sync operations
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupFocusListeners() {
    _focusNodes.forEach((key, node) {
      node.addListener(() {
        setState(() {
          if (node.hasFocus) {
            _focusedField = key;
          } else if (_focusedField == key) {
            _focusedField = '';
          }
        });
      });
    });
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _jobTitleController = TextEditingController();
    _companyNameController = TextEditingController();
    _postcodeController = TextEditingController();
    
    // Add listeners to track dirty state
    _nameController.addListener(_markDirty);
    _emailController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _jobTitleController.addListener(_markDirty);
    _companyNameController.addListener(_markDirty);
    _postcodeController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_isDirty && mounted) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  Future<void> _loadProfile() async {
    if (kDebugMode) {
      print('🔍 ProfileScreen: Loading profile for user ${widget.userId}');
    }
    
    try {
      setState(() {
        _isLoading = true;
      });

      // First try to load from local database
      var user = await widget.database.profileDao.getProfile(widget.userId);
      
      if (kDebugMode) {
        print('🔍 ProfileScreen: Local profile found: ${user != null}');
      }
      
      // If no local profile exists, don't try to sync - just show the empty form
      // This is for NEW users who need to create their profile
      if (user == null) {
        if (kDebugMode) {
          print('🔍 ProfileScreen: No local profile exists - showing empty form for new user');
        }
        // Don't try to sync - let the user create their profile first
      }
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          // CRITICAL: Create a NEW list copy to avoid modifying the original
          // Without this copy, adding to _colleagues would modify _currentUser.listOfALLColleagues
          // causing _hasColleaguesChanged() to always return false (Bug #018)
          _colleagues = user?.listOfALLColleagues != null 
              ? List<Colleague>.from(user!.listOfALLColleagues!)
              : [];
          _isLoading = false;
          
          if (kDebugMode) {
            print('ProfileScreen._loadProfile: Loaded ${_colleagues.length} colleagues from database');
            for (var colleague in _colleagues) {
              print('  - ${colleague.name} (${colleague.email})');
            }
          }
          
          if (user != null) {
            if (kDebugMode) {
              print('🔍 ProfileScreen: Populating form with existing profile data');
            }
            _nameController.text = user.name;
            _emailController.text = user.email;
            _phoneController.text = user.phone ?? '';
            _jobTitleController.text = user.jobTitle ?? '';
            _companyNameController.text = user.companyName;
            _postcodeController.text = user.postcodeOrArea ?? '';
            dateBritish = user.dateFormat == 'dd-MM-yyyy';
            _profileImagePath = user.imageLocalPath;
            _signaturePath = user.signatureLocalPath;
          } else {
            // For new users, populate email from Firebase Auth
            if (kDebugMode) {
              print('🔍 ProfileScreen: NEW USER - No profile exists, showing setup form');
            }
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              _emailController.text = currentUser.email ?? '';
              if (kDebugMode) {
                print('🔍 ProfileScreen: Pre-filled email: ${currentUser.email}');
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Error handled by debug print above
        });
      }
      if (kDebugMode) {
        print('Error loading profile: $e');
      }
    }
  }

  bool _hasTextFieldChanges() {
    if (_currentUser == null) return true; // New profile always needs sync
    
    // Check if any text field has changed from original
    return _currentUser!.name != _nameController.text.trim() ||
           _currentUser!.email != _emailController.text.trim() ||
           _currentUser!.phone != _phoneController.text.trim() ||
           _currentUser!.jobTitle != _jobTitleController.text.trim() ||
           _currentUser!.companyName != _companyNameController.text.trim() ||
           (_currentUser!.postcodeOrArea ?? '') != _postcodeController.text.trim() ||
           _currentUser!.dateFormat != (dateBritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy');
  }
  
  bool _hasColleaguesChanged() {
    if (_currentUser == null) return _colleagues.isNotEmpty;
    
    final currentColleagues = _currentUser!.listOfALLColleagues ?? [];
    
    if (kDebugMode) {
      print('🔍 ProfileScreen._hasColleaguesChanged:');
      print('  - Current colleagues from DB: ${currentColleagues.length}');
      print('  - Updated colleagues in memory: ${_colleagues.length}');
    }
    
    // Check if length is different
    if (currentColleagues.length != _colleagues.length) {
      if (kDebugMode) {
        print('  - Result: true (length different)');
      }
      return true;
    }
    
    // Check if any colleague is different
    for (int i = 0; i < _colleagues.length; i++) {
      if (i >= currentColleagues.length) return true;
      
      final current = currentColleagues[i];
      final updated = _colleagues[i];
      
      if (current.name != updated.name ||
          current.email != updated.email ||
          current.phone != updated.phone ||
          current.uniqueID != updated.uniqueID) {
        return true;
      }
    }
    
    if (kDebugMode) {
      print('  - Result: false (no changes)');
    }
    return false;
  }

  /// Generate unique device ID for this device (PRD 4.3.1 step 4)
  /// Uses DeviceManager to ensure consistency across the app
  Future<String> _generateDeviceId() async {
    final deviceManager = DeviceManager();
    return await deviceManager.getDeviceId();
  }

  /// Register device session in Realtime Database (PRD 4.3.1 step 6c)
  Future<void> _registerDeviceSession(String userId, String deviceId) async {
    try {
      String deviceName = 'Unknown Device';
      
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      }
      
      // Use the correct database URL for Europe region
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://snagsnapperpro-default-rtdb.europe-west1.firebasedatabase.app',
      );
      
      final ref = database.ref('device_sessions/$userId/current_device');
      
      await ref.set({
        'device_id': deviceId,
        'device_name': deviceName,
        'last_active': ServerValue.timestamp,
        'force_logout': false,
      });
      
      if (kDebugMode) {
        print('🔍 ProfileScreen: Device session registered: $deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔍 ProfileScreen: Error registering device session: $e');
      }
      // Non-critical error, don't block profile creation
    }
  }

  Future<void> _saveProfile() async {
    if (kDebugMode) {
      print('🔍 ProfileScreen: Save profile requested');
      print('🔍 ProfileScreen: Form values:');
      print('  - Name: ${_nameController.text}');
      print('  - Email: ${_emailController.text}');
      print('  - Phone: ${_phoneController.text}');
      print('  - Job Title: ${_jobTitleController.text}');
      print('  - Company: ${_companyNameController.text}');
      print('  - Postcode: ${_postcodeController.text}');
    }
    
    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) {
        print('🔍 ProfileScreen: Form validation failed');
      }
      return;
    }

    // Check if anything actually changed
    final textFieldsChanged = _hasTextFieldChanges();
    final imageChanged = _currentUser?.imageLocalPath != _profileImagePath;
    final signatureChanged = _currentUser?.signatureLocalPath != _signaturePath;
    final colleaguesChanged = _hasColleaguesChanged();
    
    final isNewProfile = _currentUser == null;
    if (kDebugMode) {
      print('🔍 ProfileScreen: Is new profile: $isNewProfile');
      print('🔍 ProfileScreen: Text changed: $textFieldsChanged');
      print('🔍 ProfileScreen: Image changed: $imageChanged');
      print('🔍 ProfileScreen: Signature changed: $signatureChanged');
      print('🔍 ProfileScreen: Colleagues changed: $colleaguesChanged');
    }
    
    if (!isNewProfile && !textFieldsChanged && !imageChanged && !signatureChanged && !colleaguesChanged) {
      // Nothing changed - just navigate back
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final now = DateTime.now();
      
      // Generate device ID for new profiles (PRD 4.3.1 step 4)
      String? deviceId = _currentUser?.currentDeviceId;
      if (deviceId == null) {
        deviceId = await _generateDeviceId();
        if (kDebugMode) {
          print('🔍 ProfileScreen: Generated device ID for new profile: $deviceId');
        }
      }
      
      final user = AppUser(
        id: widget.userId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        companyName: _companyNameController.text.trim(),
        postcodeOrArea: _postcodeController.text.trim().isEmpty ? null : _postcodeController.text.trim(),
        dateFormat: dateBritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy',
        imageLocalPath: _profileImagePath,
        imageFirebasePath: _profileImagePath != null ? 'users/${widget.userId}/profile.jpg' : _currentUser?.imageFirebasePath,
        signatureLocalPath: _signaturePath,
        signatureFirebasePath: _signaturePath != null ? 'users/${widget.userId}/signature.jpg' : _currentUser?.signatureFirebasePath,
        listOfALLColleagues: _colleagues.isNotEmpty ? _colleagues : null, // Save colleagues list
        currentDeviceId: deviceId,  // PRD requirement: Set device_id
        lastLoginTime: now,
        needsProfileSync: textFieldsChanged || colleaguesChanged || (_currentUser?.needsProfileSync ?? false), // If text or colleagues changed
        needsImageSync: imageChanged || (_currentUser?.needsImageSync ?? false), // Only if image changed
        needsSignatureSync: signatureChanged || (_currentUser?.needsSignatureSync ?? false), // Only if signature changed
        createdAt: _currentUser?.createdAt ?? now,
        updatedAt: now,
        localVersion: (_currentUser?.localVersion ?? 0) + 1,
        firebaseVersion: _currentUser?.firebaseVersion ?? 0,
      );

      bool success;
      final isNewProfileSave = _currentUser == null;
      if (isNewProfileSave) {
        if (kDebugMode) {
          print('🔍 ProfileScreen: Creating NEW profile in database');
        }
        success = await widget.database.profileDao.insertProfile(user);
        
        // Register device session for new profiles (PRD 4.3.1 step 6c)
        if (success) {
          await _registerDeviceSession(widget.userId, deviceId);
        }
      } else {
        if (kDebugMode) {
          print('🔍 ProfileScreen: Updating existing profile in database');
        }
        success = await widget.database.profileDao.updateProfile(widget.userId, user);
      }
      
      if (kDebugMode) {
        print('🔍 ProfileScreen: Save ${success ? "successful" : "failed"}');
      }

      if (success && mounted) {
        setState(() {
          _currentUser = user;
          busy = false;
          _isDirty = false;
        });
        
        // Show simple success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate immediately after successful save
        if (mounted) {
          // Small delay to let the user see the success message
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              if (isNewProfile) {
                // New profiles go to main menu (no going back)
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/mainMenu',
                  (route) => false,
                );
              } else {
                // Existing profiles return to previous screen
                Navigator.of(context).pop();
              }
            }
          });
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔍 ProfileScreen: SAVE ERROR CAUGHT:');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');
        print('  Stack trace: $stackTrace');
      }
      
      if (mounted) {
        setState(() {
          busy = false;
          // Error shown in snackbar above
        });
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  void _showImageSelectionDialog({bool showRemoveOption = true}) {
    // Use the reusable image picker widget
    // Only show remove option if we have an image AND showRemoveOption is true
    final hasImage = _profileImagePath != null && _profileImagePath!.isNotEmpty;
    ReusableImagePicker.show(
      context: context,
      onImageSelected: _pickImage,
      onImageRemoved: hasImage && showRemoveOption ? _showImageDeletionDialog : null,
      removeItemName: 'Logo',
      removeItemDescription: 'Delete company logo from profile',
      hasExistingImage: hasImage && showRemoveOption,
    );
  }

  /// Pick image from camera or gallery and process it
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    
    try {
      setState(() {
        busy = true;
      });
      
      // Clear image cache to prevent showing old cached images
      if (_profileImagePath != null) {
        final oldImageFile = await _getImageFile(_profileImagePath!);
        if (oldImageFile.existsSync()) {
          // Evict the old image from memory cache
          final imageProvider = FileImage(oldImageFile);
          await imageProvider.evict();
          if (kDebugMode) {
            print('ProfileScreen: Evicted old image from cache');
          }
        }
      }
      
      // Clear the entire image cache to be thorough
      imageCache.clear();
      imageCache.clearLiveImages();
      if (kDebugMode) {
        print('ProfileScreen: Cleared image cache completely');
      }
      
      // Pick image with high quality for processing
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      
      if (image == null) {
        setState(() => busy = false);
        return;
      }
      
      // Show processing message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Processing image...', style: GoogleFonts.inter()),
              ],
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      
      // Process with compression service
      final compressionService = ImageCompressionService.instance;
      final result = await compressionService.processProfileImage(image);
      
      // Check validation result
      if (result.status == ImageProcessingStatus.rejected) {
        throw ImageTooLargeException(result.message);
      }
      
      // Save processed image to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(result.data);
      
      // Save to permanent storage
      final localPath = await widget.imageStorageService.saveProfileImage(
        tempFile,
        widget.userId,
      );
      
      // Clean up temp file
      await tempFile.delete();
      
      if (kDebugMode) {
        print('ProfileScreen: New image saved to: $localPath');
        // Verify the file exists
        final newFile = await _getImageFile(localPath);
        print('ProfileScreen: New file exists: ${newFile.existsSync()}');
        print('ProfileScreen: New file size: ${newFile.existsSync() ? newFile.lengthSync() : 0} bytes');
      }
      
      // Clear cache before updating state to ensure fresh image display
      imageCache.clear();
      imageCache.clearLiveImages();
      
      // Update state with incremented version to force rebuild
      setState(() {
        _profileImagePath = localPath;
        _imageVersion++; // Increment version to force widget rebuild
        _isDirty = true;
        busy = false;
      });
      
      if (kDebugMode) {
        print('ProfileScreen: Image version incremented to: $_imageVersion');
        print('ProfileScreen: New image path set to: $localPath');
      }
      
      // IMPORTANT: Only update database immediately for EXISTING profiles
      // For NEW profiles, wait for Save button to create the profile first
      if (_currentUser != null) {
        // DEBUG: Log current state before update
        if (kDebugMode) {
          print('🔍 ProfileScreen._pickImage: BEFORE update:');
          print('  - Current imageMarkedForDeletion: ${_currentUser!.imageMarkedForDeletion}');
          print('  - Current imageLocalPath: ${_currentUser!.imageLocalPath}');
          print('  - Current imageFirebasePath: ${_currentUser!.imageFirebasePath}');
          print('  - New localPath being set: $localPath');
        }
        
        // CRITICAL FIX: When adding a new image, we must CLEAR the deletion flag
        // Otherwise, the sync handler will delete the new image thinking it's part of a deletion
        // ROBUST: Set Firebase path immediately so Firestore always has complete data
        final updatedUser = _currentUser!.copyWith(
          imageLocalPath: () => localPath,
          imageFirebasePath: () => 'users/${widget.userId}/profile.jpg',  // Set path immediately!
          needsImageSync: true,
          needsProfileSync: true,  // Ensure profile syncs with the new path
          imageMarkedForDeletion: false,  // CRITICAL: Clear deletion flag when adding new image
        );
        
        // DEBUG: Log what we're about to save
        if (kDebugMode) {
          print('🔍 ProfileScreen._pickImage: AFTER update (about to save):');
          print('  - New imageMarkedForDeletion: ${updatedUser.imageMarkedForDeletion}');
          print('  - New imageLocalPath: ${updatedUser.imageLocalPath}');
          print('  - New needsImageSync: ${updatedUser.needsImageSync}');
        }
        
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        
        if (kDebugMode) {
          print('ProfileScreen: EXISTING profile - Updated database with new image path immediately');
          print('  ✅ Cleared imageMarkedForDeletion flag to prevent accidental deletion');
        }
        
        // Update current user reference and reload profile image path
        _currentUser = updatedUser;
        
        // Force UI to use the updated path from the database
        if (mounted) {
          setState(() {
            _profileImagePath = updatedUser.imageLocalPath;
          });
        }
        
        // Sync will be handled by MainMenu when user navigates back
      } else {
        // New profile - just update UI state, database will be created on Save
        if (kDebugMode) {
          print('ProfileScreen: NEW profile - Image path stored in memory, will save to database on Save button');
        }
      }
      
      // Clear previous snackbar and show result
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      
      // Show appropriate message based on compression result
      final Color messageColor;
      final IconData messageIcon;
      
      if (result.status == ImageProcessingStatus.optimal) {
        messageColor = Colors.green;
        messageIcon = Icons.check_circle;
      } else {
        messageColor = Colors.orange;
        messageIcon = Icons.warning;
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(messageIcon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(result.message, style: GoogleFonts.inter())),
            ],
          ),
          backgroundColor: messageColor,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Mark for sync if profile exists and clear deletion flag
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          imageLocalPath: () => localPath,
          needsImageSync: true,
          imageMarkedForDeletion: false, // Clear deletion flag when adding new image
        );
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        
        // Sync will be handled by MainMenu when user navigates back
      }
      
    } catch (e) {
      setState(() => busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      
      String errorMessage;
      if (e is ImageTooLargeException) {
        errorMessage = e.message;
      } else if (e is InvalidImageException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'Failed to process image';
        if (kDebugMode) {
          print('Image processing error: $e');
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage, style: GoogleFonts.inter())),
            ],
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Try Again',
            textColor: Colors.white,
            onPressed: () => _showImageSelectionDialog(),
          ),
        ),
      );
    }
  }

  /// Show confirmation dialog before deleting image
  void _showImageDeletionDialog() {
    // Use the reusable image picker widget for remove-only option
    ReusableImagePicker.showRemoveOnly(
      context: context,
      onImageRemoved: _confirmImageDeletion,
      removeItemName: 'Logo',
      removeItemDescription: 'Delete company logo from profile',
    );
  }
  
  void _confirmImageDeletion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Company Logo?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will permanently delete your company logo.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleImageDeletion();
            },
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Handle image deletion with file cleanup and sync flag update
  void _handleImageDeletion() async {
    try {
      // Delete physical file if it exists
      if (_profileImagePath != null) {
        try {
          final file = await _getImageFile(_profileImagePath!);
          if (await file.exists()) {
            // Clear from cache before deleting
            final imageProvider = FileImage(file);
            await imageProvider.evict();
            imageCache.clear();
            
            await file.delete();
            
            if (kDebugMode) {
              print('ProfileScreen: Deleted image file at: ${file.path}');
            }
          }
        } catch (e) {
          // Log error but don't stop the deletion process
          if (kDebugMode) {
            print('ProfileScreen: Error deleting image file: $e');
          }
        }
      }
      
      // Update state with incremented version
      setState(() {
        _profileImagePath = null;
        _imageVersion++; // Increment to ensure UI updates
        _isDirty = true;
      });
      
      // IMPORTANT: Only update database immediately for EXISTING profiles
      // For NEW profiles, just clear the UI state
      if (_currentUser != null) {
        // Existing profile - update database immediately to prevent sync race condition
        // Keep Firebase path but mark for deletion
        final updatedUser = _currentUser!.copyWith(
          imageLocalPath: () => null,
          imageMarkedForDeletion: true,
          needsImageSync: true,
          needsProfileSync: true,  // Ensure Firestore gets updated with null imagePath
          // Note: imageFirebasePath is kept for reference during deletion
        );
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        
        if (kDebugMode) {
          print('ProfileScreen: EXISTING profile - Marked image for deletion in database immediately');
        }
        
        // Update current user reference
        _currentUser = updatedUser;
        
        // Trigger sync if online and needed
        if (!widget.isOffline && updatedUser.needsImageSync) {
          if (kDebugMode) {
            print('ProfileScreen: Image deletion saved to database');
          }
          // Sync will be handled by MainMenu when user navigates back
        }
      } else {
        // New profile - just clear UI state, no database entry exists yet
        if (kDebugMode) {
          print('ProfileScreen: NEW profile - Image cleared from memory only');
        }
      }
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Company logo removed'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProfileScreen: Error in image deletion: $e');
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove logo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Helper method to get image file from path
  /// Handles both absolute and relative paths for cross-platform compatibility
  Future<File> _getImageFile(String path) async {
    try {
      File imageFile;
      
      if (path.startsWith('/')) {
        // Absolute path - use directly
        imageFile = File(path);
      } else {
        // Relative path - construct full path
        final appDir = await getApplicationDocumentsDirectory();
        final fullPath = '${appDir.path}/$path';
        imageFile = File(fullPath);
        
        if (kDebugMode) {
          print('ProfileScreen: Converting relative path to absolute');
          print('  Relative: $path');
          print('  Absolute: $fullPath');
        }
      }
      
      // Log file details for debugging
      if (kDebugMode) {
        final exists = imageFile.existsSync();
        print('ProfileScreen._getImageFile: File check');
        print('  Path: ${imageFile.path}');
        print('  Exists: $exists');
        if (exists) {
          final stats = imageFile.statSync();
          print('  Size: ${imageFile.lengthSync()} bytes');
          print('  Modified: ${stats.modified}');
        }
      }
      
      return imageFile;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileScreen: Error getting image file: $e');
      }
      rethrow;
    }
  }

  Future<File?> _getSignatureFile() async {
    if (_signaturePath == null || _signaturePath!.isEmpty) return null;
    
    try {
      File file;
      if (_signaturePath!.startsWith('/')) {
        // Absolute path
        file = File(_signaturePath!);
      } else {
        // Relative path - convert to absolute
        final directory = await getApplicationDocumentsDirectory();
        file = File(path.join(directory.path, _signaturePath!));
      }
      
      if (await file.exists()) {
        if (kDebugMode) {
          print('ProfileScreen: Signature file found at: ${file.path}');
        }
        return file;
      } else {
        if (kDebugMode) {
          print('ProfileScreen: Signature file not found at: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error getting signature file: $e');
    }
    return null;
  }

  void _handleSignatureTap() async {
    debugPrint('ProfileScreen: Opening signature capture');
    
    // CRITICAL: Clear signature cache BEFORE capturing new signature to prevent showing old cached signatures
    if (_signaturePath != null) {
      try {
        final oldSignatureFile = await _getSignatureFile();
        if (oldSignatureFile != null && oldSignatureFile.existsSync()) {
          // Evict the old signature from memory cache
          final imageProvider = FileImage(oldSignatureFile);
          await imageProvider.evict();
          if (kDebugMode) {
            print('ProfileScreen: Evicted old signature from cache');
          }
        }
      } catch (e) {
        debugPrint('ProfileScreen: Error evicting old signature from cache: $e');
      }
    }
    
    // Clear the entire image cache to be thorough (matching image implementation)
    imageCache.clear();
    imageCache.clearLiveImages();
    if (kDebugMode) {
      print('ProfileScreen: Cleared image cache completely before signature capture');
    }
    
    // Show full-screen signature capture
    final signaturePath = await SignatureCaptureScreen.show(
      context,
      widget.userId,
    );
    
    if (signaturePath != null) {
      debugPrint('ProfileScreen: Signature saved at $signaturePath');
      
      // Increment version FIRST to force immediate UI update
      setState(() {
        _signatureVersion++; // Increment version to force widget rebuild
        _signaturePath = signaturePath;
        _isDirty = true;
      });
      
      if (kDebugMode) {
        print('ProfileScreen: Signature version incremented to: $_signatureVersion');
      }
      
      // Mark for sync and clear deletion flag if it was set
      // ROBUST: Set Firebase path immediately so Firestore always has complete data
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          signatureLocalPath: () => signaturePath,
          signatureFirebasePath: () => 'users/${widget.userId}/signature.jpg',  // Set path immediately!
          needsSignatureSync: true,
          needsProfileSync: true,  // Ensure profile syncs with the new path
          signatureMarkedForDeletion: false, // Clear deletion flag when adding new signature
        );
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        
        // Update current user reference
        _currentUser = updatedUser;
        
        // Force UI to use the updated path from the database (matching image implementation)
        if (mounted) {
          setState(() {
            _signaturePath = updatedUser.signatureLocalPath;
          });
        }
        
        // Sync will be handled by MainMenu when user navigates back
        // Signature sync flag is already set in database
      } else {
        // For new profiles, just set the sync flag
        await widget.database.profileDao.setNeedsSignatureSync(widget.userId);
      }
    } else {
      debugPrint('ProfileScreen: Signature capture cancelled');
    }
  }
  
  void _handleAddColleague(Colleague colleague) async {
    setState(() {
      _colleagues.add(colleague);
      _isDirty = true;
    });
    
    if (kDebugMode) {
      print('ProfileScreen: Added colleague: ${colleague.name} (${colleague.email})');
    }
    
    // For now, just keep the colleagues in memory until Save is pressed
    // The immediate save was causing issues, so we'll rely on the Save button
    if (kDebugMode) {
      print('ProfileScreen: Colleague added to list (will save when Save button is pressed)');
    }
  }
  
  void _handleRemoveColleague(int index) {
    if (index >= 0 && index < _colleagues.length) {
      final removed = _colleagues[index];
      setState(() {
        _colleagues.removeAt(index);
        _isDirty = true;
      });
      
      if (kDebugMode) {
        print('ProfileScreen: Removed colleague: ${removed.name} (${removed.email})');
      }
    }
  }
  
  void _handleSignatureDelete() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Signature'),
        content: const Text('Are you sure you want to delete your signature?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      debugPrint('ProfileScreen: Deleting signature');
      
      // Delete the signature file
      final signatureService = SignatureService();
      await signatureService.deleteSignature(widget.userId);
      
      // Clear signature from image cache if it was displayed
      if (_signaturePath != null) {
        try {
          final sigFile = await _getSignatureFile();
          if (sigFile != null) {
            final imageProvider = FileImage(sigFile);
            await imageProvider.evict();
            imageCache.clear(); // Force clear all cache
            if (kDebugMode) {
              print('ProfileScreen: Cleared signature from image cache');
            }
          }
        } catch (e) {
          debugPrint('ProfileScreen: Error clearing signature cache: $e');
        }
      }
      
      setState(() {
        _signaturePath = null;
        _signatureVersion++; // Increment to ensure UI updates
        _isDirty = true;
      });
      
      if (kDebugMode) {
        print('ProfileScreen: Signature cleared, version: $_signatureVersion');
      }
      
      // Mark for deletion and sync
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          signatureLocalPath: () => null,
          signatureMarkedForDeletion: true,  // Set deletion flag for sync
          needsSignatureSync: true,
          needsProfileSync: true,  // Ensure Firestore gets updated
          // Note: signatureFirebasePath is kept for reference during deletion
        );
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        
        // Sync will be handled by MainMenu when user navigates back
        // Signature sync flag is already set in database
      } else {
        // For new profiles (shouldn't happen), just set the sync flag
        await widget.database.profileDao.setNeedsSignatureSync(widget.userId);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signature removed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _companyNameController.dispose();
    _postcodeController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _focusNodes.forEach((key, node) => node.dispose());
    super.dispose();
  }

  Widget _buildModernInputField({
    required IconData icon,
    required String label,
    required String hint,
    required String initialValue,
    bool isRequired = false,
    bool isOptional = false,
    bool isFocused = false,
    bool enabled = true,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    TextEditingController? controller,
  }) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
        controller: controller,
        focusNode: focusNode,
        enabled: enabled && !busy,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 16,
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
          labelText: label + (isRequired ? ' *' : '') + (isOptional ? ' (Optional)' : ''),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: GoogleFonts.inter(
            color: theme.colorScheme.error,
            fontSize: 12,
          ),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentUser != null 
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        automaticallyImplyLeading: false,
        actions: [
          if (!busy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _isDirty ? _saveProfile : null,
                icon: Icon(
                  Icons.check_rounded,
                  color: _isDirty ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: _isDirty ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                  theme.colorScheme.secondary.withValues(alpha: 0.03),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Header
                      Text(
                        'My Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your personal information',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Company Logo Section
                      _buildCompanyLogoSection(),

                      const SizedBox(height: 12),

                      // Optional text below logo
                      Center(
                        child: Text(
                          'Company Logo (Optional)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Profile Form
                      _buildProfileForm(),

                      const SizedBox(height: 32),
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

  /// Build company logo section matching old UI
  Widget _buildCompanyLogoSection() {
    final theme = Theme.of(context);
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative border - using full width but increased height
            Container(
              width: double.infinity,
              height: 320,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
            // Inner white container - square format
            Container(
              width: 308,
              height: 308,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            // Image container - Large square format for company logo
            Container(
              width: 300,
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _profileImagePath == null || _profileImagePath!.isEmpty
                    ? _buildEmptyImageState()
                    : _buildImageDisplay(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            _buildModernInputField(
              icon: Icons.person_outline,
              label: 'Full Name',
              hint: 'Enter your full name',
              initialValue: _nameController.text,
              controller: _nameController,
              isFocused: _focusedField == 'name',
              focusNode: _focusNodes['name'],
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: ValidationRules.validateName,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Job Title Field
            _buildModernInputField(
              icon: Icons.work_outline,
              label: 'Job Title',
              hint: 'e.g. Site Manager, Inspector',
              initialValue: _jobTitleController.text,
              controller: _jobTitleController,
              isRequired: true,
              isFocused: _focusedField == 'job',
              focusNode: _focusNodes['job'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Job title is required';
                }
                return ValidationRules.validateJobTitle(value);
              },
            ),

            const SizedBox(height: 20),

            // Company Name Field
            _buildModernInputField(
              icon: Icons.business_outlined,
              label: 'Company Name',
              hint: 'Enter your company name',
              initialValue: _companyNameController.text,
              controller: _companyNameController,
              isFocused: _focusedField == 'company',
              focusNode: _focusNodes['company'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              validator: ValidationRules.validateCompanyName,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Postcode/Area Field
            _buildModernInputField(
              icon: Icons.location_on_outlined,
              label: 'Postcode or Area',
              hint: 'Enter postcode or area',
              initialValue: _postcodeController.text,
              controller: _postcodeController,
              isOptional: true,
              isFocused: _focusedField == 'postcode',
              focusNode: _focusNodes['postcode'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 -]'))],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null; // Optional field
                }
                final trimmed = value.trim();
                if (trimmed.length > 20) {
                  return 'Postcode must be less than 20 characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9\s\-]+$').hasMatch(trimmed)) {
                  return 'Invalid characters in postcode';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Phone Field
            _buildModernInputField(
              icon: Icons.phone_outlined,
              label: 'Phone',
              hint: 'Enter phone number',
              initialValue: _phoneController.text,
              controller: _phoneController,
              isFocused: _focusedField == 'phone',
              focusNode: _focusNodes['phone'],
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[+0-9]'))],
              validator: ValidationRules.validatePhone,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Email Field (Read-only)
            _buildModernInputField(
              icon: Icons.email_outlined,
              label: 'Email',
              hint: 'Email address',
              initialValue: _emailController.text,
              controller: _emailController,
              enabled: false,
              isFocused: _focusedField == 'email',
              focusNode: _focusNodes['email'],
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!ValidationRules.emailPattern.hasMatch(value.trim())) {
                  return 'Invalid email address';
                }
                return null;
              },
              isRequired: true,
            ),

            const SizedBox(height: 32),

            // Date Format Section
            _buildDateFormatSection(),

            const SizedBox(height: 20),

            // Signature Section
            _buildSignatureSection(),
            
            const SizedBox(height: 20),
            
            // Colleagues Section
            ColleaguesSection(
              colleagues: _colleagues,
              onAddColleague: _handleAddColleague,
              onRemoveColleague: _handleRemoveColleague,
              isEditable: !busy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFormatSection() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Date Format',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('DD-MM-YYYY'),
                  ),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('MM-DD-YYYY'),
                  ),
                ),
              ],
              selected: {dateBritish},
              showSelectedIcon: false,
              onSelectionChanged: busy
                  ? null
                  : (Set<bool> newSelection) {
                      setState(() {
                        dateBritish = newSelection.first;
                        _isDirty = true;
                      });
                    },
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyImageState() {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: busy ? null : () => _showImageSelectionDialog(showRemoveOption: false),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add Company Logo',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to upload',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build image display widget with proper offline-first implementation
  /// Shows actual image from local storage or empty state placeholder
  Widget _buildImageDisplay() {
    // Show placeholder if no image path
    if (_profileImagePath == null || _profileImagePath!.isEmpty) {
      return _buildEmptyImageState();
    }
    
    // Build image display with FutureBuilder for async file loading
    // Use image version as key to force rebuild when image changes
    return FutureBuilder<File>(
      key: ValueKey('image_display_$_imageVersion'),
      future: _getImageFile(_profileImagePath!),
      builder: (context, snapshot) {
        // Show loading indicator while fetching file
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        
        // Check if file exists and is valid
        if (snapshot.hasData && snapshot.data!.existsSync()) {
          final imageFile = snapshot.data!;
          
          if (kDebugMode) {
            print('ProfileScreen: Displaying image from: ${imageFile.path}');
            print('  File size: ${imageFile.lengthSync()} bytes');
            print('  Image version: $_imageVersion');
          }
          
          // Display the actual image with proper error handling
          // CRITICAL: Use a unique key that includes file modification time to force reload
          final fileKey = '${imageFile.path}_${imageFile.lastModifiedSync().millisecondsSinceEpoch}_v$_imageVersion';
          
          return GestureDetector(
            onTap: busy ? null : _showImageDeletionDialog,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                imageFile,
                key: ValueKey(fileKey),
                fit: BoxFit.cover,
                cacheWidth: null,
                cacheHeight: null,
                gaplessPlayback: false, // Don't show old image while loading new one
                errorBuilder: (context, error, stackTrace) {
                  // Log error and show placeholder if image fails to load
                  if (kDebugMode) {
                    print('ProfileScreen: Error loading image: $error');
                    print('  Stack trace: $stackTrace');
                  }
                  
                  // Clear invalid path and show empty state
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _profileImagePath = null;
                        _isDirty = true;
                      });
                    }
                  });
                  
                  return _buildEmptyImageState();
                },
              ),
            ),
          );
        }
        
        // File doesn't exist or error occurred
        if (snapshot.hasError) {
          if (kDebugMode) {
            print('ProfileScreen: Error accessing image file: ${snapshot.error}');
          }
        }
        
        // Default to empty state
        return _buildEmptyImageState();
      },
    );
  }

  Widget _buildSignatureSection() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.draw_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Signature',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              GestureDetector(
                onTap: _signaturePath == null ? _handleSignatureTap : null,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      style: _signaturePath == null ? BorderStyle.solid : BorderStyle.none,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _signaturePath == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Signature',
                                  style: GoogleFonts.inter(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : FutureBuilder<File?>(
                            // Use signature version as key to force rebuild when signature changes
                            key: ValueKey('signature_display_$_signatureVersion'),
                            future: _getSignatureFile(),
                            builder: (context, snapshot) {
                              // Show loading indicator while fetching file
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                );
                              }
                              
                              // Check if file exists and is valid
                              if (snapshot.hasData && snapshot.data != null) {
                                final signatureFile = snapshot.data!;
                                
                                if (kDebugMode) {
                                  print('ProfileScreen: Displaying signature from: ${signatureFile.path}');
                                  print('  File size: ${signatureFile.lengthSync()} bytes');
                                  print('  Signature version: $_signatureVersion');
                                }
                                
                                // CRITICAL: Use a unique key that includes file modification time to force reload
                                final fileKey = '${signatureFile.path}_${signatureFile.lastModifiedSync().millisecondsSinceEpoch}_v$_signatureVersion';
                                
                                return GestureDetector(
                                  onTap: _handleSignatureTap,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.file(
                                      signatureFile,
                                      key: ValueKey(fileKey),
                                      fit: BoxFit.contain,
                                      cacheWidth: null,
                                      cacheHeight: null,
                                      gaplessPlayback: false, // Don't show old signature while loading new one
                                      errorBuilder: (context, error, stackTrace) {
                                        // Log error and show placeholder if signature fails to load
                                        if (kDebugMode) {
                                          print('ProfileScreen: Error loading signature: $error');
                                        }
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                size: 48,
                                                color: theme.colorScheme.error,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Failed to load signature',
                                                style: GoogleFonts.inter(
                                                  color: theme.colorScheme.error,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                // No signature file found
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.gesture,
                                        size: 48,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Signature not found',
                                        style: GoogleFonts.inter(
                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                ),
              ),
              // Delete button (X) positioned at top-right
              if (_signaturePath != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _handleSignatureDelete,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}