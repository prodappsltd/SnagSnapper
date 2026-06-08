import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/models/priority_level.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'signature_capture_screen.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

/// Modern Profile Screen with tabbed interface
/// Tab 1: Profile information (name, email, etc.)
/// Tab 2: Priority settings (customizable priority codes)
class ProfileScreenV2 extends StatefulWidget {
  final AppDatabase database;
  final String userId;
  final ImageStorageService imageStorageService;
  final bool isOffline;

  ProfileScreenV2({
    super.key,
    required this.database,
    required this.userId,
    ImageStorageService? imageStorageService,
    this.isOffline = false,
  }) : imageStorageService = imageStorageService ?? ImageStorageService.instance;

  @override
  State<ProfileScreenV2> createState() => _ProfileScreenV2State();
}

class _ProfileScreenV2State extends State<ProfileScreenV2>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Tab controller
  late TabController _tabController;

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _jobTitleController;
  late TextEditingController _companyNameController;
  late TextEditingController _postcodeController;

  // Priority controllers (5 pairs of code + description)
  final List<TextEditingController> _priorityCodeControllers = [];
  final List<TextEditingController> _priorityDescControllers = [];

  // Focus nodes for keyboard navigation
  late FocusNode _nameFocusNode;
  late FocusNode _jobTitleFocusNode;
  late FocusNode _companyNameFocusNode;
  late FocusNode _postcodeFocusNode;
  late FocusNode _phoneFocusNode;

  // State variables
  AppUser? _currentUser;
  bool dateBritish = true;
  String? _profileImagePath;
  String? _signaturePath;
  // Colleague feature removed - site sharing uses email-based sharedWith map
  int _imageVersion = 0;
  int _signatureVersion = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isInitializing = true;  // Prevents false dirty state during load

  // Animation controllers
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _initializePriorityControllers();
    _setupAnimations();

    // Pre-populate email from Firebase Auth (email is read-only, comes from auth)
    final authEmail = FirebaseAuth.instance.currentUser?.email;
    if (authEmail != null) {
      _emailController.text = authEmail;
    }

    _loadProfile();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _jobTitleController = TextEditingController();
    _companyNameController = TextEditingController();
    _postcodeController = TextEditingController();

    // Initialize focus nodes for keyboard navigation
    _nameFocusNode = FocusNode();
    _jobTitleFocusNode = FocusNode();
    _companyNameFocusNode = FocusNode();
    _postcodeFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();

    // Add listeners for dirty tracking
    for (var controller in [
      _nameController,
      _emailController,
      _phoneController,
      _jobTitleController,
      _companyNameController,
      _postcodeController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  void _initializePriorityControllers() {
    // Initialize 5 pairs of controllers for priority codes/descriptions
    for (int i = 0; i < 5; i++) {
      final codeController = TextEditingController();
      final descController = TextEditingController();
      codeController.addListener(_markDirty);
      descController.addListener(_markDirty);
      _priorityCodeControllers.add(codeController);
      _priorityDescControllers.add(descController);
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController.forward();
  }

  void _markDirty() {
    if (_isInitializing) return;  // Skip during initialization
    if (!_isDirty && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await widget.database.profileDao.getProfile(widget.userId);
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _nameController.text = user.name;
          _emailController.text = user.email;
          _phoneController.text = user.phone;
          _jobTitleController.text = user.jobTitle;
          _companyNameController.text = user.companyName;
          _postcodeController.text = user.postcodeOrArea ?? '';
          dateBritish = user.dateFormat == 'dd-MM-yyyy';
          _profileImagePath = user.imageLocalPath;
          _signaturePath = user.signatureLocalPath;

          // Load priorities into controllers
          final priorities = user.priorities.isNotEmpty
              ? user.priorities
              : PriorityLevel.defaults;
          for (int i = 0; i < 5 && i < priorities.length; i++) {
            _priorityCodeControllers[i].text = priorities[i].code;
            _priorityDescControllers[i].text = priorities[i].description;
          }

          _isLoading = false;
          _isInitializing = false;  // Enable dirty tracking
          _isDirty = false;  // Explicitly reset
        });
      } else {
        // New user - load defaults
        setState(() {
          for (int i = 0; i < PriorityLevel.defaults.length; i++) {
            _priorityCodeControllers[i].text = PriorityLevel.defaults[i].code;
            _priorityDescControllers[i].text =
                PriorityLevel.defaults[i].description;
          }
          _isLoading = false;
          _isInitializing = false;  // Enable dirty tracking
          _isDirty = false;  // Explicitly reset
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
        _isInitializing = false;  // Enable dirty tracking even on error
      });
    }
  }

  List<PriorityLevel> _getPrioritiesFromControllers() {
    final priorities = <PriorityLevel>[];
    for (int i = 0; i < 5; i++) {
      priorities.add(PriorityLevel(
        code: _priorityCodeControllers[i].text.trim(),
        description: _priorityDescControllers[i].text.trim(),
      ));
    }
    return priorities;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final priorities = _getPrioritiesFromControllers();

      AppUser userToSave;

      if (_currentUser != null) {
        // Update existing user
        userToSave = _currentUser!.copyWith(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          jobTitle: _jobTitleController.text.trim(),
          companyName: _companyNameController.text.trim(),
          postcodeOrArea: () => _postcodeController.text.trim().isEmpty
              ? null
              : _postcodeController.text.trim(),
          dateFormat: dateBritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy',
          priorities: priorities,
          needsProfileSync: true,
        );

        await widget.database.profileDao.updateProfile(widget.userId, userToSave);
      } else {
        // Create NEW user profile
        final now = DateTime.now();
        userToSave = AppUser(
          id: widget.userId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          jobTitle: _jobTitleController.text.trim(),
          companyName: _companyNameController.text.trim(),
          postcodeOrArea: _postcodeController.text.trim().isEmpty
              ? null
              : _postcodeController.text.trim(),
          dateFormat: dateBritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy',
          priorities: priorities,
          imageLocalPath: _profileImagePath,
          signatureLocalPath: _signaturePath,
          needsProfileSync: true,
          needsImageSync: _profileImagePath != null,
          needsSignatureSync: _signaturePath != null,
          createdAt: now,
          updatedAt: now,
        );

        await widget.database.profileDao.insertProfile(userToSave);
        if (kDebugMode) print('Created new profile for user: ${widget.userId}');
      }

      // Update ContentProvider
      if (mounted) {
        final cp = Provider.of<CP>(context, listen: false);
        cp.setAppUser(userToSave);
      }

      setState(() {
        _currentUser = userToSave;
        _isDirty = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Profile saved successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Navigate to main menu after save
        Navigator.pushReplacementNamed(context, '/mainMenu');
      }
    } catch (e) {
      if (kDebugMode) print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetPrioritiesToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Priorities'),
        content: Text('Reset all priorities to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              for (int i = 0; i < PriorityLevel.defaults.length; i++) {
                _priorityCodeControllers[i].text = PriorityLevel.defaults[i].code;
                _priorityDescControllers[i].text =
                    PriorityLevel.defaults[i].description;
              }
              Navigator.pop(context);
              _markDirty();
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _companyNameController.dispose();
    _postcodeController.dispose();
    // Dispose focus nodes
    _nameFocusNode.dispose();
    _jobTitleFocusNode.dispose();
    _companyNameFocusNode.dispose();
    _postcodeFocusNode.dispose();
    _phoneFocusNode.dispose();
    for (var c in _priorityCodeControllers) {
      c.dispose();
    }
    for (var c in _priorityDescControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // For iOS
      ),
      child: Scaffold(
      body: _isLoading
          ? _buildLoadingState(colorScheme)
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.05),
                    colorScheme.secondary.withValues(alpha: 0.05),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: FadeTransition(
                opacity: _fadeController,
                child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      _buildSliverAppBar(colorScheme, size),
                    ],
                    body: Form(
                      key: _formKey,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildProfileTab(colorScheme),
                          _buildPrioritiesTab(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      floatingActionButton: _isDirty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            )
          : null,
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: GoogleFonts.inter(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ColorScheme colorScheme, Size size) {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (_isDirty) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Unsaved Changes'),
                    content: Text('You have unsaved changes. Discard them?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text('Discard'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildProfileHeader(colorScheme, size),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Profile'),
              Tab(text: 'Priorities'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme, Size size) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _CirclePatternPainter(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Company logo - large rounded rectangle filling most of the header
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, // Below status bar
            bottom: 56, // Above tab bar
            left: 24,
            right: 24,
            child: GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildProfileImage(),
                    ),
                  ),
                  // Camera button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Label overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Company Logo',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
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
    );
  }

  Widget _buildProfileImage() {
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      return FutureBuilder<String>(
        // Use both path and version to force rebuild when image changes
        key: ValueKey('profile_${_profileImagePath}_$_imageVersion'),
        future: _getFullImagePath(_profileImagePath!),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final file = File(snapshot.data!);
            if (file.existsSync()) {
              return Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: false,
              );
            }
          }
          return _buildDefaultLogo();
        },
      );
    }
    return _buildDefaultLogo();
  }

  Widget _buildDefaultLogo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            size: 56,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add logo',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getFullImagePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => _buildImageSourceSheet(),
    );

    if (source == null) return;

    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (pickedFile != null && mounted) {
        // Save using ImageStorageService
        final savedPath = await widget.imageStorageService.saveProfileImage(
          File(pickedFile.path),
          widget.userId,
        );

        // Clear Flutter's image cache to ensure new image is shown
        imageCache.clear();
        imageCache.clearLiveImages();

        // Update user in database FIRST
        if (_currentUser != null) {
          final updatedUser = _currentUser!.copyWith(
            imageLocalPath: () => savedPath,
            needsImageSync: true,
          );
          await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
          _currentUser = updatedUser;
        }

        // Then update UI state to trigger rebuild
        if (mounted) {
          setState(() {
            _profileImagePath = savedPath;
            _imageVersion++;
          });
        }

        if (kDebugMode) {
          print('Profile image updated: $savedPath (version: $_imageVersion)');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageSourceSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose Image Source',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _buildSourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== PROFILE TAB ==============

  Widget _buildProfileTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Personal Information Card
        _buildSectionCard(
          title: 'Personal Information',
          icon: Icons.person_outline_rounded,
          colorScheme: colorScheme,
          children: [
            _buildModernTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.badge_outlined,
              validator: ValidationRules.validateName,
              focusNode: _nameFocusNode,
              nextFocusNode: _jobTitleFocusNode,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _jobTitleController,
              label: 'Job Title',
              icon: Icons.work_outline_rounded,
              focusNode: _jobTitleFocusNode,
              nextFocusNode: _companyNameFocusNode,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Company Information Card
        _buildSectionCard(
          title: 'Company Information',
          icon: Icons.business_outlined,
          colorScheme: colorScheme,
          children: [
            _buildModernTextField(
              controller: _companyNameController,
              label: 'Company Name',
              icon: Icons.apartment_rounded,
              validator: ValidationRules.validateCompanyName,
              focusNode: _companyNameFocusNode,
              nextFocusNode: _postcodeFocusNode,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _postcodeController,
              label: 'Postcode / Area',
              icon: Icons.location_on_outlined,
              focusNode: _postcodeFocusNode,
              nextFocusNode: _phoneFocusNode,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Contact Information Card
        _buildSectionCard(
          title: 'Contact Information',
          icon: Icons.contact_phone_outlined,
          colorScheme: colorScheme,
          children: [
            _buildModernTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Email is from Firebase Auth, not editable
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: ValidationRules.validatePhone,
              focusNode: _phoneFocusNode,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Date Format Card
        _buildSectionCard(
          title: 'Preferences',
          icon: Icons.settings_outlined,
          colorScheme: colorScheme,
          children: [
            _buildDateFormatSelector(colorScheme),
          ],
        ),
        const SizedBox(height: 20),

        // Signature Card
        _buildSectionCard(
          title: 'Signature',
          icon: Icons.draw_outlined,
          colorScheme: colorScheme,
          children: [
            _buildSignatureSection(colorScheme),
          ],
        ),
        const SizedBox(height: 100), // Space for FAB
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required ColorScheme colorScheme,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      focusNode: focusNode,
      textInputAction: textInputAction ?? (nextFocusNode != null ? TextInputAction.next : TextInputAction.done),
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: enabled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateFormatSelector(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildFormatOption(
            label: 'DD-MM-YYYY',
            subtitle: 'British',
            selected: dateBritish,
            onTap: () {
              setState(() => dateBritish = true);
              _markDirty();
            },
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFormatOption(
            label: 'MM-DD-YYYY',
            subtitle: 'American',
            selected: !dateBritish,
            onTap: () {
              setState(() => dateBritish = false);
              _markDirty();
            },
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatOption({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _captureSignature,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: _signaturePath != null && _signaturePath!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: FutureBuilder<String>(
                  key: ValueKey('sig_$_signatureVersion'),
                  future: _getFullImagePath(_signaturePath!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final file = File(snapshot.data!);
                      if (file.existsSync()) {
                        // Evict cached image to ensure fresh load after signature update
                        final imageProvider = FileImage(file);
                        imageProvider.evict();
                        return Stack(
                          children: [
                            Center(
                              child: Image.file(
                                file,
                                fit: BoxFit.contain,
                                cacheWidth: null, // Disable resize caching
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    }
                    return _buildEmptySignature(colorScheme);
                  },
                ),
              )
            : _buildEmptySignature(colorScheme),
      ),
    );
  }

  Widget _buildEmptySignature(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.draw_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add signature',
            style: GoogleFonts.inter(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureSignature() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureCaptureScreen(userId: widget.userId),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _signaturePath = result;
        _signatureVersion++;
      });

      // Update user in database (instant save like profile image)
      if (_currentUser != null) {
        final updatedUser = _currentUser!.copyWith(
          signatureLocalPath: () => result,
          needsSignatureSync: true,
        );
        await widget.database.profileDao.updateProfile(widget.userId, updatedUser);
        _currentUser = updatedUser;
      }
      // Note: No _markDirty() - signature saves instantly like profile image
    }
  }

  // ============== PRIORITIES TAB ==============

  Widget _buildPrioritiesTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Customize priority codes and descriptions for your snags. These apply to all your sites.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Priority cards
        for (int i = 0; i < 5; i++) ...[
          _buildPriorityCard(i, colorScheme),
          if (i < 4) const SizedBox(height: 12),
        ],

        const SizedBox(height: 24),

        // Reset button
        OutlinedButton.icon(
          onPressed: _resetPrioritiesToDefaults,
          icon: Icon(Icons.restore_rounded),
          label: Text('Reset to Defaults'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        const SizedBox(height: 100), // Space for FAB
      ],
    );
  }

  Widget _buildPriorityCard(int index, ColorScheme colorScheme) {
    // Colors for each priority level (increasing severity)
    final colors = [
      Colors.green,      // OK
      Colors.blue,       // OBS
      Colors.orange,     // CAT3
      Colors.deepOrange, // CAT2
      Colors.red,        // CAT1
    ];

    final color = colors[index];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with priority level indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Priority Level ${index + 1}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.flag_rounded,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ),
          // Code and description fields
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code field (small)
                // SYNC: Firebase rules enforce max 4 chars. Update firestore.rules if changed.
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _priorityCodeControllers[index],
                    maxLength: 4,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Code',
                      labelStyle: GoogleFonts.inter(fontSize: 12),
                      counterText: '',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Description field (larger)
                // SYNC: Firebase rules enforce max 300 chars. Update firestore.rules if changed.
                Expanded(
                  child: TextFormField(
                    controller: _priorityDescControllers[index],
                    maxLength: 300,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: GoogleFonts.inter(fontSize: 12),
                      counterText: '',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
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

// Custom painter for background pattern
class _CirclePatternPainter extends CustomPainter {
  final Color color;

  _CirclePatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw decorative circles
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.2),
      80,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.8),
      60,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.7),
      40,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
