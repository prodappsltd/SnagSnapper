// TODO: DELETE THIS FILE - Replaced by profile_screen_ui_matched.dart
// This was the first attempt at new profile screen with wrong UI
// Keep profile_screen_ui_matched.dart which has the correct UI matching the old design

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/utils/validators.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'components/profile_image.dart';
import 'components/signature_pad.dart';
import 'components/sync_status_indicator.dart';

/// Profile Screen with offline-first database integration
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

class _ProfileScreenState extends State<ProfileScreen> {
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
  String _selectedDateFormat = 'dd-MM-yyyy';
  String? _profileImagePath;
  String? _signaturePath;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadProfile();
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

      final user = await widget.database.profileDao.getProfile(widget.userId);
      
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
            _selectedDateFormat = user.dateFormat;
            _profileImagePath = user.imageLocalPath;
            _signaturePath = user.signatureLocalPath;
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
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
        dateFormat: _selectedDateFormat,
        imageLocalPath: _profileImagePath,
        signatureLocalPath: _signaturePath,
        needsProfileSync: widget.isOffline || (_currentUser?.needsProfileSync ?? false),
        needsImageSync: _currentUser?.needsImageSync ?? false,
        needsSignatureSync: _currentUser?.needsSignatureSync ?? false,
        createdAt: _currentUser?.createdAt ?? now,
        updatedAt: now,
        localVersion: (_currentUser?.localVersion ?? 0) + 1,
        firebaseVersion: _currentUser?.firebaseVersion ?? 0,
      );

      bool success;
      if (_currentUser == null) {
        success = await widget.database.profileDao.insertProfile(user);
      } else {
        success = await widget.database.profileDao.updateProfile(widget.userId, user);
      }

      if (success && mounted) {
        setState(() {
          _currentUser = user;
          _isSaving = false;
          _isDirty = false;
        });
        
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save profile: ${e.toString()}';
        });
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _companyNameController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading profile...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading profile'),
              const SizedBox(height: 8),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isDirty) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep Editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return shouldDiscard ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentUser == null ? 'Create Your Profile' : 'Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_isDirty) {
                final shouldDiscard = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Unsaved Changes'),
                    content: const Text('You have unsaved changes. Do you want to discard them?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Keep Editing'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                );
                if (shouldDiscard == true) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Sync status indicator
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SyncStatusIndicator(
                userId: widget.userId,
                database: widget.database,
                syncService: SyncService.instance,
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Profile Image
              Center(
                child: ProfileImagePicker(
                  userId: widget.userId,
                  currentImagePath: _profileImagePath,
                  imageStorageService: widget.imageStorageService,
                  onImageChanged: (path) {
                    setState(() {
                      _profileImagePath = path;
                      _isDirty = true;
                    });
                    if (path != null) {
                      widget.database.profileDao.setNeedsImageSync(widget.userId);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Name Field
              TextFormField(
                key: const Key('name_field'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: Validators.validateName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              // Email Field
              TextFormField(
                key: const Key('email_field'),
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: Validators.validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                key: const Key('phone_field'),
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: Validators.validatePhone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              // Job Title Field
              TextFormField(
                key: const Key('job_title_field'),
                controller: _jobTitleController,
                decoration: const InputDecoration(
                  labelText: 'Job Title *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                validator: Validators.validateJobTitle,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              // Company Name Field
              TextFormField(
                key: const Key('company_name_field'),
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: Validators.validateCompanyName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              
              // Postcode/Area Field
              TextFormField(
                key: const Key('postcode_field'),
                controller: _postcodeController,
                decoration: const InputDecoration(
                  labelText: 'Postcode/Area (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: Validators.validatePostcode,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              
              // Date Format Dropdown
              DropdownButtonFormField<String>(
                key: const Key('date_format_dropdown'),
                value: _selectedDateFormat,
                decoration: const InputDecoration(
                  labelText: 'Date Format',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: const [
                  DropdownMenuItem(value: 'dd-MM-yyyy', child: Text('dd-MM-yyyy')),
                  DropdownMenuItem(value: 'MM-dd-yyyy', child: Text('MM-dd-yyyy')),
                  DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDateFormat = value!;
                    _isDirty = true;
                  });
                },
              ),
              if (_selectedDateFormat.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Date Format: $_selectedDateFormat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 24),
              
              // Signature Pad
              SignaturePad(
                userId: widget.userId,
                currentSignaturePath: _signaturePath,
                imageStorageService: widget.imageStorageService,
                onSignatureChanged: (path) {
                  setState(() {
                    _signaturePath = path;
                    _isDirty = true;
                  });
                  if (path != null) {
                    widget.database.profileDao.setNeedsSignatureSync(widget.userId);
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                key: const Key('save_button'),
                onPressed: (_isSaving || !_isDirty) ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Save Profile'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}