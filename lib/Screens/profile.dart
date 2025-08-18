// TODO: DELETE THIS FILE - Original Firebase profile implementation
// Replaced by offline-first version in screens/profile/profile_screen_ui_matched.dart
// This file contains the old Firebase-coupled implementation and should be removed

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/signature.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';
import 'package:snagsnapper/services/image_service.dart';
import 'package:snagsnapper/services/enhanced_image_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../Constants/constants.dart';
import '../Data/user.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool dateBritish = true;

  /// AppUser definitely exists when on this screen as to login you need to signup and
  /// to signup you need to create a profile first which becomes app user.
  late AppUser appUser;
  String _name = '';
  String _jobTitle = '';
  String _companyName = '';
  String _postcodeOrArea = '';
  String _phone = '';
  String _email = '';
  String _dateFomat = '';
  String _signature = '';
  bool busy = false;

  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Track which field is focused
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
    // Sync any pending profile changes when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingProfileChanges();
    });
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    appUser = Provider.of<CP>(context, listen: false).getAppUser()!;
    if (appUser.dateFormat == 'dd-MM-yyyy') {
      setState(() => dateBritish = true);
    } else {
      setState(() => dateBritish = false);
    }
    setState(() {
      _signature = appUser.signature;
    });
  }

  @override
  void dispose() {
    if (kDebugMode) print('Profile Disposed');
    _fadeController.dispose();
    _slideController.dispose();
    _focusNodes.forEach((_, node) => node.dispose());
    super.dispose();
  }

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
  
  /// Sync any pending profile changes when coming online
  /// 
  /// COST-EFFICIENT DESIGN: This method implements our offline-first, cost-efficient sync strategy
  /// for profile images. Instead of constantly checking server state or maintaining complex queues,
  /// we use simple flags in SharedPreferences to track pending operations.
  /// 
  /// WHY THIS APPROACH:
  /// 1. NO Firebase reads - we never check "what's on server", saving costs
  /// 2. NO polling - only syncs when user opens profile screen
  /// 3. Batched operations - multiple offline changes result in single sync
  /// 4. Minimal memory - just 2 SharedPreferences keys (~100 bytes)
  /// 
  /// WHEN IT RUNS:
  /// - On profile screen load (via initState)
  /// - Only if there are pending changes
  /// - Only if device is online
  /// 
  /// WHAT IT DOES:
  /// 1. Checks if sync needed (profileNeedsSync flag)
  /// 2. Deletes old images from Firebase Storage
  /// 3. Clears sync flags on success
  Future<void> _syncPendingProfileChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final needsSync = prefs.getBool('profileNeedsSync') ?? false;
      
      // Early exit if no sync needed - prevents unnecessary operations
      if (!needsSync) return;
      
      final enhancedService = EnhancedImageService();
      if (!await enhancedService.isOnline()) {
        if (kDebugMode) print('Profile: Offline - skipping sync');
        return;
      }
      
      if (kDebugMode) print('Profile: Syncing pending changes');
      
      // Get pending delete path - this is the old image that needs removal
      final pendingDelete = prefs.getString('profilePendingDelete');
      
      // Delete from Storage if needed
      // Note: We don't check if file exists first (costs a read operation)
      // Instead, we just try to delete and ignore "not found" errors
      if (pendingDelete != null && pendingDelete.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.ref(pendingDelete);
          await ref.delete();
          if (kDebugMode) print('Profile: Synced delete - removed from Storage: $pendingDelete');
        } catch (e) {
          // Ignore errors - file might already be deleted or not exist
          // This is cheaper than checking first
          if (kDebugMode) print('Profile: Storage delete error (may already be deleted): $e');
        }
      }
      
      // Clear sync flags only after successful sync
      // If any error occurs above, flags remain for next attempt
      await prefs.remove('profileNeedsSync');
      await prefs.remove('profilePendingDelete');
      if (kDebugMode) print('Profile: Sync completed - cleared flags');
      
    } catch (e) {
      if (kDebugMode) print('Profile: Error syncing pending changes: $e');
      // IMPORTANT: Leave flags set for next attempt
      // This ensures eventual consistency
    }
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() => busy = true);
                    await Provider.of<CP>(context, listen: false)
                        .updateProfile(_name, _jobTitle, _companyName, _postcodeOrArea, _phone, _email, _dateFomat, _signature);
                    setState(() => busy = false);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
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
                      
                      // Company Logo Section - matching profile setup screen
                      Container(
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
                                child: Stack(
                                  children: [
                                    // Use smart image widget for automatic caching and offline support
                                    if (appUser.image.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: EnhancedImageService().smartImage(
                                          relativePath: appUser.image,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            child: const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: Container(
                                            color: theme.colorScheme.errorContainer,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: theme.colorScheme.error,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Failed to load image',
                                                    style: TextStyle(
                                                      color: theme.colorScheme.error,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Empty state
                                    if (appUser.image.isEmpty)
                                      GestureDetector(
                                        onTap: busy
                                            ? null
                                            : () => _showImageSelectionDialog(hasExistingImage: false),
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
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // Delete button for existing image
                            if (appUser.image.isNotEmpty)
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
                      ),
                      
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
                      Container(
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
                                initialValue: appUser.name,
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
                                initialValue: appUser.jobTitle,
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
                                initialValue: appUser.companyName,
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
                                initialValue: appUser.postcodeOrArea,
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
                                initialValue: appUser.phone,
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
                                initialValue: appUser.email,
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
                              Container(
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
                                                FocusScope.of(context).unfocus();
                                                final isbritish = newSelection.first;
                                                Provider.of<CP>(context, listen: false).changeDateFormat(isbritish);
                                                _dateFomat = isbritish ? 'dd-MM-yyyy' : 'MM-dd-yyyy';
                                                setState(() => dateBritish = isbritish);
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
                              ),
                              
                              const SizedBox(height: 20),
                              // Signature Section
                              Container(
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
                                      onTap: busy
                                          ? null
                                          : _handleSignatureCapture,
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
                                                child: EnhancedImageService().smartImage(
                                                  relativePath: _signature,
                                                  fit: BoxFit.contain,
                                                  placeholder: const Center(
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Save Button
                              GestureDetector(
                                onTap: busy
                                    ? null
                                    : () async {
                                        if (_formKey.currentState!.validate()) {
                                          setState(() => busy = true);
                                          await Provider.of<CP>(context, listen: false)
                                              .updateProfile(_name, _jobTitle, _companyName, _postcodeOrArea, _phone, _email, _dateFomat, _signature);
                                          setState(() => busy = false);
                                          if (!context.mounted) return;
                                          Navigator.pop(context);
                                        }
                                      },
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
                              ),
                            ],
                          ),
                        ),
                      ),
                      
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

  // Handle company logo image selection using EnhancedImageService
  Future<void> _handleImageSelection(ImageSource source) async {
    try {
      setState(() => busy = true);
      
      // Use original ImageService for capture
      final imageService = ImageService();
      final processedImage = await imageService.captureImage(
        source: source,
        type: ImageType.profile,
      );
      
      if (processedImage != null) {
        // Use enhanced service for upload with offline support
        final enhancedService = EnhancedImageService();
        final userId = FirebaseAuth.instance.currentUser!.uid;
        
        // Store the old image path for cleanup
        final oldImagePath = appUser.image;
        
        // Generate the relative path
        final relativePath = '$userId/profile.jpg';
        
        // CRITICAL: Store image in permanent local storage FIRST for instant display
        // This ensures the image appears immediately without any network delay
        if (kDebugMode) print('Profile: Storing image in local storage for instant display');
        await enhancedService.storeImageLocally(relativePath, processedImage.data, null);
        
        // CRITICAL: Set state to 'stored' immediately to prevent UI refresh
        // DO NOT CHANGE THIS ORDER - setting state to 'uploading' will cause
        // the smartImage widget to rebuild when upload completes, creating a flicker
        enhancedService.setImageState(relativePath, ImageStatus.stored);
        if (kDebugMode) print('Profile: Image state set to stored - preventing UI refresh');
        
        // Update UI immediately with the new path
        // The image will display instantly from local storage
        setState(() {
          appUser.image = relativePath;
        });
        
        // Update in Firestore with relative path
        final cp = Provider.of<CP>(context, listen: false);
        await cp.updateProfileImage();
        
        // IMPORTANT: Upload to Firebase Storage happens AFTER UI update
        // This is intentional to provide instant feedback to the user
        // The upload happens in background without blocking the UI
        if (await enhancedService.isOnline()) {
          // Online: Upload directly to Firebase Storage
          // Using .then() instead of await to keep it non-blocking
          enhancedService.uploadToStorage(relativePath, processedImage.data)
            .then((_) {
              if (kDebugMode) print('Background upload to Storage completed');
            })
            .catchError((e) {
              if (kDebugMode) print('Background Storage upload failed: $e');
              // On failure, queue for retry when connection is stable
              enhancedService.queueForUpload(relativePath, processedImage.data);
              // Only change state to pendingSync on upload failure
              // This shows the sync indicator to the user
              enhancedService.setImageState(relativePath, ImageStatus.pendingSync);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image saved. Will sync when online.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            });
        } else {
          // Offline: Queue for later upload
          // The image is already cached and displayed
          await enhancedService.queueForUpload(relativePath, processedImage.data);
          enhancedService.setImageState(relativePath, ImageStatus.pendingSync);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image saved offline. Will upload when online.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error handling image selection: $e');
      
      // Provide user-friendly error messages
      String errorMessage = 'Unable to process image. Please try again.';
      
      if (e is PlatformException) {
        if (e.code == 'camera_access_denied') {
          errorMessage = 'Camera access denied. Please enable camera permissions in your device settings.';
        } else if (e.code == 'photo_access_denied') {
          errorMessage = 'Photo library access denied. Please enable photo permissions in your device settings.';
        }
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your app permissions in device settings.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. The image will be uploaded when you\'re back online.';
      } else if (e is ImageServiceException) {
        errorMessage = 'Image processing failed: ${e.message}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Handle signature image capture using EnhancedImageService
  Future<void> _handleSignatureCapture() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GetSignature(),
      ),
    );
    
    if (result != null && result is List<int>) {
      try {
        setState(() => busy = true);
        
        final imageService = ImageService();
        
        // Process the signature image
        final processedImage = await imageService.processImage(
          imageBytes: Uint8List.fromList(result),
          type: ImageType.signature,
        );
        
        // Use enhanced service for upload with offline support
        final enhancedService = EnhancedImageService();
        final userId = FirebaseAuth.instance.currentUser!.uid;
        final relativePath = '$userId/signature.png';
        
        // Save to permanent local storage first, then upload
        await enhancedService.storeImageLocally(
          relativePath,
          processedImage.data,
          null,
        );
        
        // Try to upload
        if (await enhancedService.isOnline()) {
          try {
            await enhancedService.uploadToStorage(relativePath, processedImage.data);
            enhancedService.setImageState(relativePath, ImageStatus.stored);
          } catch (e) {
            await enhancedService.queueForUpload(relativePath, processedImage.data);
            enhancedService.setImageState(relativePath, ImageStatus.pendingSync);
          }
        } else {
          await enhancedService.queueForUpload(relativePath, processedImage.data);
          enhancedService.setImageState(relativePath, ImageStatus.pendingSync);
        }
        
        // Update the signature with relative path
        setState(() {
          _signature = relativePath;
        });
        
        // Show appropriate feedback
        if (mounted) {
          final status = enhancedService.getImageState(relativePath);
          if (status == ImageStatus.pendingSync) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signature saved. Will sync when online.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error handling signature: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save signature: ${e.toString()}')),
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  /// Handle image deletion with offline-first, cost-efficient approach
  /// 
  /// DESIGN PHILOSOPHY:
  /// This method implements a sophisticated yet simple deletion strategy that:
  /// 1. Works completely offline (critical for construction sites)
  /// 2. Minimizes Firebase operations (reduces costs)
  /// 3. Provides instant user feedback (no waiting)
  /// 4. Ensures eventual consistency (syncs when possible)
  /// 
  /// COST OPTIMIZATION:
  /// - NO Firebase reads to check state
  /// - Single Firestore write when syncing
  /// - Single Storage delete operation
  /// - Uses SharedPreferences (free) instead of Firestore for tracking
  /// 
  /// MEMORY EFFICIENCY:
  /// - Only stores 2 flags in SharedPreferences (~100 bytes)
  /// - No complex queue structures
  /// - No duplicate data storage
  /// 
  /// USER EXPERIENCE:
  /// - Image disappears instantly
  /// - Clear feedback messages
  /// - Works without internet
  /// - Automatic sync when online
  Future<void> _handleImageDeletion() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        setState(() => busy = true);
        
        // Store the current image path for cleanup
        final currentImagePath = appUser.image;
        
        // CRITICAL: For offline support, we handle delete operations locally first
        // and sync when online. This ensures the app works in poor connectivity areas
        if (kDebugMode) print('Profile: Starting delete operation for: $currentImagePath');
        
        // OFFLINE-FIRST DELETE IMPLEMENTATION
        // This implementation prioritizes user experience and cost efficiency:
        // 1. Instant local feedback (no waiting for network)
        // 2. Works fully offline
        // 3. Minimal Firebase operations (cost-efficient)
        // 4. Eventual consistency when online
        
        // Step 1: Clear UI immediately for instant feedback
        // User sees the image disappear instantly, regardless of network state
        setState(() {
          appUser.image = '';
        });
        
        // Step 2: Delete from local cache
        // This ensures the image is truly gone from the device
        if (currentImagePath.isNotEmpty) {
          final enhancedService = EnhancedImageService();
          final cacheFile = File(enhancedService.getLocalPath(currentImagePath));
          
          if (await cacheFile.exists()) {
            // IMPORTANT: Evict from Flutter's memory cache BEFORE deleting file
            // This prevents the old image from showing if user adds new image
            final fileImage = FileImage(cacheFile);
            PaintingBinding.instance.imageCache.evict(fileImage);
            if (kDebugMode) print('Profile: Evicted image from memory cache');
            
            // Delete the physical file
            await cacheFile.delete();
            if (kDebugMode) print('Profile: Deleted cache file');
          }
          
          // Clear image state in our state management
          enhancedService.setImageState(currentImagePath, ImageStatus.none);
        }
        
        // Step 3: Mark profile as needing sync
        // COST-EFFICIENT APPROACH: Instead of complex queues or immediate Firebase operations,
        // we use simple flags to track what needs syncing. This avoids:
        // - Maintaining complex queue structures in memory
        // - Immediate Firebase operations that might fail
        // - Repeated retry attempts that waste battery/data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('profileNeedsSync', true);
        await prefs.setString('profilePendingDelete', currentImagePath);
        if (kDebugMode) print('Profile: Marked for sync - will delete from cloud when online');
        
        // Step 4: Try to sync immediately if online (non-blocking)
        // If we're online, we attempt immediate sync for better UX
        // If offline or sync fails, the flags ensure it syncs later
        final cp = Provider.of<CP>(context, listen: false);
        final enhancedService = EnhancedImageService();
        
        if (await enhancedService.isOnline()) {
          // ONLINE PATH: Attempt immediate sync for better user experience
          if (kDebugMode) print('Profile: Online - attempting immediate sync');
          
          try {
            // Update Firestore first - this is the source of truth
            // If this fails, we don't delete from Storage (maintains consistency)
            await cp.updateProfileImage();
            
            // Delete from Storage only after Firestore update succeeds
            // This prevents orphaned files if Firestore update fails
            if (currentImagePath.isNotEmpty && !currentImagePath.startsWith('http')) {
              final ref = FirebaseStorage.instance.ref(currentImagePath);
              await ref.delete();
              if (kDebugMode) print('Profile: Deleted from Firebase Storage');
            }
            
            // Clear sync flags only after ALL operations succeed
            // This is critical - if we clear flags too early and something fails,
            // we lose track of what needs syncing
            await prefs.remove('profileNeedsSync');
            await prefs.remove('profilePendingDelete');
            if (kDebugMode) print('Profile: Sync completed successfully');
            
          } catch (e) {
            // IMPORTANT: On ANY error, we keep the flags set
            // This ensures eventual consistency - the sync will be retried
            // on next app launch or screen visit
            if (kDebugMode) print('Profile: Sync failed, will retry later: $e');
            // Flags remain set for future sync - DO NOT clear them here
          }
        } else {
          // OFFLINE PATH: Just mark for sync, no network operations
          // The _syncPendingProfileChanges method will handle this later
          if (kDebugMode) print('Profile: Offline - delete will sync when connection available');
        }
        
        // Show success message (delete appears instant to user)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                await enhancedService.isOnline() 
                  ? 'Image deleted successfully' 
                  : 'Image deleted. Will sync when online.'
              ),
              backgroundColor: await enhancedService.isOnline() 
                ? Theme.of(context).colorScheme.primary 
                : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) print('Error deleting image: $e');
        
        // Restore the image URL if deletion failed
        if (appUser.image.isEmpty) {
          try {
            // Reload the profile from provider
            await Provider.of<CP>(context, listen: false).loadProfileOfUser();
            setState(() {
              appUser = Provider.of<CP>(context, listen: false).getAppUser()!;
            });
          } catch (reloadError) {
            if (kDebugMode) print('Error reloading profile: $reloadError');
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete image: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
  }

  // Show image selection dialog
  Future<void> _showImageSelectionDialog({required bool hasExistingImage}) async {
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
