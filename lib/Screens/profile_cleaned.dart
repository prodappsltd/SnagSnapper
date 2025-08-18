// TODO: DELETE THIS FILE - Was used as UI reference for profile_screen_ui_matched.dart
// The UI has been successfully matched in profile_screen_ui_matched.dart
// This cleaned version is no longer needed

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';

/// Profile Screen - Cleaned UI-only version
/// 
/// This is a cleaned version of the Profile screen with all implementation
/// removed, keeping only the UI structure. Ready for implementing the new
/// offline-first architecture as specified in the PRD.
/// 
/// TODO: Implement according to PRD Section 4 (Profile Module Requirements)
/// - Local database using Drift
/// - Sync flags management  
/// - Device management
/// - Offline-first image handling
class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool dateBritish = true;
  bool busy = false;

  // TODO: Replace with data from local database (Drift)
  String _name = '';
  String _jobTitle = '';
  String _companyName = '';
  String _postcodeOrArea = '';
  String _phone = '';
  String _email = '';
  String _dateFormat = 'dd-MM-yyyy';
  String _signature = '';
  String _profileImagePath = '';

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
    _setupAnimations();
    _setupFocusListeners();
    
    // TODO: Implement according to PRD 4.3.1
    // - Load profile from local database
    // - Check device session
    // - Setup sync listener
    _loadProfile();
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
    if (kDebugMode) print('Profile: Disposed');
    _fadeController.dispose();
    _slideController.dispose();
    _focusNodes.forEach((_, node) => node.dispose());
    super.dispose();
  }

  /// Load profile from local database
  /// TODO: Implement according to PRD 4.3.3
  Future<void> _loadProfile() async {
    // TODO: 
    // 1. Load from local Drift database (instant)
    // 2. Display immediately
    // 3. Check sync status
    // 4. If online and sync needed, sync in background
  }

  /// Save profile changes
  /// TODO: Implement according to PRD 4.3.3
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => busy = true);
    
    try {
      // TODO:
      // 1. Update local database immediately
      // 2. Set needs_profile_sync = true
      // 3. Update UI (instant feedback)
      // 4. IF online: Queue background sync
      // 5. IF offline: Keep flag, sync later
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) print('Profile: Error saving: $e');
      // TODO: Show error message
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Handle profile image selection
  /// TODO: Implement according to PRD 4.3.4
  Future<void> _handleImageSelection(ImageSource source) async {
    // TODO:
    // 1. Capture/select image
    // 2. Convert to JPEG, compress, resize
    // 3. Save to local storage: SnagSnapper/{userId}/Profile/profile.jpg
    // 4. Update database with relative path
    // 5. Set needs_image_sync = true
    // 6. Display from local (instant)
    // 7. If online: background upload
  }

  /// Handle profile image deletion
  Future<void> _handleImageDeletion() async {
    // TODO:
    // 1. Confirm with user
    // 2. Delete from local storage
    // 3. Clear database field
    // 4. Set needs_image_sync = true
    // 5. If online: sync deletion
  }

  /// Handle signature capture
  Future<void> _handleSignatureCapture() async {
    // TODO:
    // 1. Navigate to signature screen
    // 2. Save signature as JPEG
    // 3. Store in: SnagSnapper/{userId}/Profile/signature.jpg
    // 4. Update database
    // 5. Set needs_signature_sync = true
  }

  /// Build modern input field with animations
  Widget _buildModernInputField({
    required IconData icon,
    required String label,
    required String hint,
    String? initialValue,
    bool isOptional = false,
    bool isRequired = false,
    bool isFocused = false,
    bool enabled = true,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
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
        focusNode: focusNode,
        enabled: enabled && !busy,
        initialValue: initialValue,
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
        ),
        actions: [
          if (!busy)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: _saveProfile,
                icon: Icon(
                  Icons.check_rounded,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    color: theme.colorScheme.primary,
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
                      Text(
                        'Company Logo (Optional)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),

                      // Profile Form
                      _buildProfileForm(),

                      const SizedBox(height: 32),

                      // TODO: Add sync status indicator (PRD 4.4.2)
                      // Status bar showing "X changes pending sync" with SYNC NOW button
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

  /// Build company logo section
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
          // Image container
          Container(
            width: double.infinity,
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _profileImagePath.isEmpty
                  ? _buildEmptyImageState()
                  : _buildImageDisplay(),
            ),
          ),
          // Delete button for existing image
          if (_profileImagePath.isNotEmpty)
            Positioned(
              bottom: 8,
              right: 20,
              child: GestureDetector(
                onTap: busy ? null : _handleImageDeletion,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.delete,
                    size: 18,
                    color: theme.colorScheme.onError,
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

  Widget _buildImageDisplay() {
    // TODO: Load image from local storage using path_provider
    // Display placeholder for now
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.image, size: 48),
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
              initialValue: _name,
              isFocused: _focusedField == 'name',
              focusNode: _focusNodes['name'],
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) => _name = value.trim(),
              validator: ValidationRules.validateName,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Job Title Field
            _buildModernInputField(
              icon: Icons.work_outline,
              label: 'Job Title',
              hint: 'e.g. Site Manager, Inspector',
              initialValue: _jobTitle,
              isRequired: true,
              isFocused: _focusedField == 'job',
              focusNode: _focusNodes['job'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) => _jobTitle = value.trim(),
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
              initialValue: _companyName,
              isFocused: _focusedField == 'company',
              focusNode: _focusNodes['company'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) => _companyName = value.trim(),
              validator: ValidationRules.validateCompanyName,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Postcode/Area Field
            _buildModernInputField(
              icon: Icons.location_on_outlined,
              label: 'Postcode or Area',
              hint: 'Enter postcode or area',
              initialValue: _postcodeOrArea,
              isOptional: true,
              isFocused: _focusedField == 'postcode',
              focusNode: _focusNodes['postcode'],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9 -]'))],
              onChanged: (value) => _postcodeOrArea = value.trim(),
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
              initialValue: _phone,
              isFocused: _focusedField == 'phone',
              focusNode: _focusNodes['phone'],
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[+0-9]'))],
              onChanged: (value) => _phone = value.trim(),
              validator: ValidationRules.validatePhone,
              isRequired: true,
            ),

            const SizedBox(height: 20),

            // Email Field (Read-only)
            _buildModernInputField(
              icon: Icons.email_outlined,
              label: 'Email',
              hint: 'Email address',
              initialValue: _email,
              enabled: false,
              isFocused: _focusedField == 'email',
              focusNode: _focusNodes['email'],
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) => _email = value.trim(),
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

            const SizedBox(height: 32),

            // Save Button
            _buildSaveButton(),
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
                  label: Text('DD-MM-YYYY'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('MM-DD-YYYY'),
                ),
              ],
              selected: {dateBritish},
              showSelectedIcon: false,
              onSelectionChanged: busy
                  ? null
                  : (Set<bool> newSelection) {
                      setState(() {
                        dateBritish = newSelection.first;
                        _dateFormat = dateBritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy';
                      });
                    },
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  GoogleFonts.inter(
                    fontSize: 14,
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
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: busy ? null : _handleSignatureCapture,
            child: Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _signature.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          color: theme.colorScheme.primary,
                          size: 32,
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
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.draw, size: 32),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: busy ? null : _saveProfile,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: busy
              ? SpinKitThreeBounce(
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                )
              : Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // Show image selection dialog
  Future<void> _showImageSelectionDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  dense: false,
                  leading: const Icon(Icons.camera_alt_outlined, color: Colors.deepOrange, size: 40.0),
                  title: const Text('OPEN CAMERA', style: TextStyle(fontSize: 16.0)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageSelection(ImageSource.camera);
                  },
                ),
                const Divider(height: 10.0),
                ListTile(
                  dense: false,
                  leading: const Icon(Icons.collections, color: Colors.deepOrange, size: 40.0),
                  title: const Text('SELECT FROM GALLERY', style: TextStyle(fontSize: 16.0)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageSelection(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Image source enum for image picker
enum ImageSource { camera, gallery }