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
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'signature_capture_screen.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'components/sync_status_indicator.dart';

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
  bool _isLoading = true;
  bool busy = false;
  bool _isDirty = false;
  String? _errorMessage;

  // Sync related state
  late SyncService _syncService;
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<SyncError>? _errorSubscription;
  SyncStatus _currentSyncStatus = SyncStatus.idle;
  double _syncProgress = 0.0;
  bool _showProgressOverlay = false;

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
    _initializeSyncService();
    _loadProfile();
  }

  Future<void> _initializeSyncService() async {
    _syncService = SyncService.instance;
    
    // Initialize sync service if not already done
    if (!_syncService.isInitialized) {
      await _syncService.initialize(widget.userId);
    }
    
    // Set up stream subscriptions
    _statusSubscription = _syncService.statusStream.listen(_onSyncStatusChange);
    _progressSubscription = _syncService.progressStream.listen(_onProgressUpdate);
    _errorSubscription = _syncService.errorStream.listen(_onSyncError);
    
    // Set up auto-sync
    _syncService.setupAutoSync();
  }

  void _onSyncStatusChange(SyncStatus status) {
    if (mounted) {
      setState(() {
        _currentSyncStatus = status;
        _showProgressOverlay = status == SyncStatus.syncing;
      });
    }
  }

  void _onProgressUpdate(double progress) {
    if (mounted) {
      setState(() {
        _syncProgress = progress;
      });
    }
  }

  void _onSyncError(SyncError error) {
    if (mounted) {
      _showErrorDialog(error);
    }
  }

  Future<void> _showErrorDialog(SyncError error) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Error'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (error.isRecoverable)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _triggerManualSync();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
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
      final hasChanges = _currentUser!.needsProfileSync || 
                        _currentUser!.needsImageSync || 
                        _currentUser!.needsSignatureSync;
      
      if (hasChanges && !widget.isOffline) {
        await _syncService.onAppForeground();
      }
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
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // First try to load from local database
      var user = await widget.database.profileDao.getProfile(widget.userId);
      
      // If no local profile exists and we're online, try to download from Firebase
      if (user == null && !widget.isOffline) {
        if (kDebugMode) {
          print('No local profile found, attempting to download from Firebase...');
        }
        
        // Trigger sync to download profile from Firebase
        final syncResult = await _syncService.syncProfile(widget.userId);
        if (syncResult) {
          // Try loading from local database again after sync
          user = await widget.database.profileDao.getProfile(widget.userId);
        }
      }
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
          
          if (user != null) {
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
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              _emailController.text = currentUser.email ?? '';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading profile: ${e.toString()}';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if anything actually changed
    final textFieldsChanged = _hasTextFieldChanges();
    final imageChanged = _currentUser?.imageLocalPath != _profileImagePath;
    final signatureChanged = _currentUser?.signatureLocalPath != _signaturePath;
    
    if (!textFieldsChanged && !imageChanged && !signatureChanged) {
      // Nothing changed, don't save
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      busy = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
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
        signatureLocalPath: _signaturePath,
        needsProfileSync: textFieldsChanged || (_currentUser?.needsProfileSync ?? false), // Only if text changed
        needsImageSync: imageChanged || (_currentUser?.needsImageSync ?? false), // Only if image changed
        needsSignatureSync: signatureChanged || (_currentUser?.needsSignatureSync ?? false), // Only if signature changed
        createdAt: _currentUser?.createdAt ?? now,
        updatedAt: now,
        localVersion: (_currentUser?.localVersion ?? 0) + 1,
        firebaseVersion: _currentUser?.firebaseVersion ?? 0,
      );

      bool success;
      bool isNewProfile = _currentUser == null;
      if (isNewProfile) {
        success = await widget.database.profileDao.insertProfile(user);
      } else {
        success = await widget.database.profileDao.updateProfile(widget.userId, user);
      }

      if (success && mounted) {
        setState(() {
          _currentUser = user;
          busy = false;
          _isDirty = false;
        });
        
        // Trigger auto-sync if online
        if (!widget.isOffline) {
          _syncService.syncNow().then((result) {
            if (result.success && mounted) {
              // Reload profile to get updated sync flags
              _loadProfile();
            }
          });
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isOffline 
                ? 'Saved locally - will sync when online'
                : 'Profile saved successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate after successful save
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
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          _errorMessage = 'Failed to save profile: ${e.toString()}';
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

  Future<void> _triggerManualSync() async {
    if (_currentSyncStatus == SyncStatus.syncing || widget.isOffline) {
      return;
    }
    
    final result = await _syncService.syncNow();
    
    if (mounted) {
      if (result.success) {
        // Reload profile to get updated data
        await _loadProfile();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSelectionDialog() {
    // Show bottom sheet with options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'Take Photo',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Use camera to capture logo',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Select existing image',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            // Remove option if image exists
            if (_profileImagePath != null && _profileImagePath!.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: Text(
                  'Remove Logo',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Delete current image',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showImageDeletionDialog();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Pick image from camera or gallery and process it
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    
    try {
      setState(() => busy = true);
      
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
      
      // Update state
      setState(() {
        _profileImagePath = localPath;
        _isDirty = true;
        busy = false;
      });
      
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
      
      // Mark for sync if profile exists
      if (_currentUser != null) {
        await widget.database.profileDao.setNeedsImageSync(widget.userId);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Company Logo?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will permanently delete your company logo from the profile.',
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
      
      // Update state
      setState(() {
        _profileImagePath = null;
        _isDirty = true;
      });
      
      // Mark for sync to remove from Firebase
      if (_currentUser != null) {
        await widget.database.profileDao.setNeedsImageSync(widget.userId);
        
        if (kDebugMode) {
          print('ProfileScreen: Marked image for deletion sync');
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
      if (path.startsWith('/')) {
        // Absolute path - use directly
        return File(path);
      } else {
        // Relative path - construct full path
        final appDir = await getApplicationDocumentsDirectory();
        final fullPath = '${appDir.path}/$path';
        
        if (kDebugMode) {
          print('ProfileScreen: Converting relative path to absolute');
          print('  Relative: $path');
          print('  Absolute: $fullPath');
        }
        
        return File(fullPath);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProfileScreen: Error getting image file: $e');
      }
      rethrow;
    }
  }

  Future<File?> _getSignatureFile() async {
    if (_signaturePath == null) return null;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(directory.path, _signaturePath!));
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error getting signature file: $e');
    }
    return null;
  }

  void _handleSignatureTap() async {
    debugPrint('ProfileScreen: Opening signature capture');
    
    // Show full-screen signature capture
    final signaturePath = await SignatureCaptureScreen.show(
      context,
      widget.userId,
    );
    
    if (signaturePath != null) {
      debugPrint('ProfileScreen: Signature saved at $signaturePath');
      setState(() {
        _signaturePath = signaturePath;
        _isDirty = true;
      });
      
      // Mark for sync
      await widget.database.profileDao.setNeedsSignatureSync(widget.userId);
    } else {
      debugPrint('ProfileScreen: Signature capture cancelled');
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
      
      setState(() {
        _signaturePath = null;
        _isDirty = true;
      });
      
      // Mark for sync (deletion)
      await widget.database.profileDao.setNeedsSignatureSync(widget.userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
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
          // Sync status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SyncStatusIndicator(
              userId: widget.userId,
              database: widget.database,
              syncService: _syncService,
            ),
          ),
          // Manual sync button when there are pending changes
          if (_currentUser != null && 
              (_currentUser!.needsProfileSync || 
               _currentUser!.needsImageSync || 
               _currentUser!.needsSignatureSync) &&
              !widget.isOffline &&
              _currentSyncStatus != SyncStatus.syncing)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _triggerManualSync,
              tooltip: 'Sync now',
            ),
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
          
          // Sync Progress Overlay
          if (_showProgressOverlay)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(
                      minWidth: 200,
                      maxWidth: 300,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Syncing...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_syncProgress * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _syncProgress,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
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
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative border
          Container(
            width: double.infinity,
            height: 200,
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
          // Inner white container
          Container(
            width: double.infinity,
            height: 188,
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
          // Image container - Using ProfileImagePicker adapted for rectangular shape
          Container(
            width: double.infinity,
            height: 180,
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
      onTap: busy ? null : () => _showImageSelectionDialog(),
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
    return FutureBuilder<File>(
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
          }
          
          // Display the actual image with proper error handling
          return Stack(
            fit: StackFit.expand,
            children: [
              // Image with rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
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
              
              // Delete button overlay (only visible when not busy)
              if (!busy)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _showImageDeletionDialog,
                      tooltip: 'Remove company logo',
                    ),
                  ),
                ),
            ],
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
                            future: _getSignatureFile(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return GestureDetector(
                                  onTap: _handleSignatureTap,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.file(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              } else {
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