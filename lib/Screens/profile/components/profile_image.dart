import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';

/// Profile Image Picker Widget
/// Handles image selection from camera/gallery with offline storage
class ProfileImagePicker extends StatefulWidget {
  final String userId;
  final String? currentImagePath;
  final ImageStorageService imageStorageService;
  final ProfileDao? profileDao;
  final ImagePicker? imagePicker;
  final Function(String?) onImageChanged;
  final Function(String)? onError;

  const ProfileImagePicker({
    super.key,
    required this.userId,
    required this.currentImagePath,
    required this.imageStorageService,
    required this.onImageChanged,
    this.profileDao,
    this.imagePicker,
    this.onError,
  });

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  late ImagePicker _imagePicker;
  String? _displayImagePath;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _displayImagePath = widget.currentImagePath;
    _loadImageIfNeeded();
  }

  Future<void> _loadImageIfNeeded() async {
    if (widget.currentImagePath != null && widget.currentImagePath!.isNotEmpty) {
      // Convert relative path to absolute if needed
      if (!widget.currentImagePath!.startsWith('/')) {
        final absolutePath = await widget.imageStorageService.relativeToAbsolute(widget.currentImagePath!);
        setState(() {
          _displayImagePath = absolutePath;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,  // Pick at higher res, we'll compress later
        maxHeight: 2048,
        imageQuality: 95,  // Higher quality initially
      );

      if (pickedFile != null) {
        // Show step 1: Resizing
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Resizing...'),
                ],
              ),
              duration: Duration(seconds: 10),
            ),
          );
        }
        
        // Small delay to show the resizing message
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Show step 2: Compressing
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Compressing...'),
                ],
              ),
              duration: Duration(seconds: 10),
            ),
          );
        }

        // Delete old image if exists
        if (widget.currentImagePath != null) {
          await widget.imageStorageService.deleteProfileImage(widget.userId);
        }

        // Show step 3: Saving
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text('Saving...'),
                ],
              ),
              duration: Duration(seconds: 10),
            ),
          );
        }
        
        // Save new image (compression happens in isolate)
        final file = File(pickedFile.path);
        final relativePath = await widget.imageStorageService.saveProfileImage(file, widget.userId);
        final absolutePath = await widget.imageStorageService.relativeToAbsolute(relativePath);

        setState(() {
          _displayImagePath = absolutePath;
          _isLoading = false;
        });

        // Clear processing message (silent save per PRD)
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        // Notify parent
        widget.onImageChanged(relativePath);

        // Set sync flag if DAO provided
        // NOTE: We do NOT clear imageMarkedForDeletion here - it persists
        // until sync completes (critical for offline delete-then-add scenario)
        if (widget.profileDao != null) {
          await widget.profileDao!.setNeedsImageSync(widget.userId);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      
      // Clear any processing message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      // Show specific error messages
      if (e is ImageTooLargeException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else if (e is InvalidImageException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid image format. Please choose a different image.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else if (widget.onError != null) {
        widget.onError!(e.toString());
      }
      
      if (kDebugMode) {
        print('Error picking image: $e');
      }
    }
  }

  Future<void> _removeImage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await widget.imageStorageService.deleteProfileImage(widget.userId);

      setState(() {
        _displayImagePath = null;
        _isLoading = false;
      });

      widget.onImageChanged(null);

      // Set deletion flag and sync flag if DAO provided
      if (widget.profileDao != null) {
        // Mark image for deletion (critical for offline sync)
        await widget.profileDao!.setImageMarkedForDeletion(widget.userId, true);
        // Also set sync flag
        await widget.profileDao!.setNeedsImageSync(widget.userId);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (widget.onError != null) {
        widget.onError!(e.toString());
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Choose Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_displayImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceDialog,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[400]!, width: 2),
            ),
            child: ClipOval(
              child: _buildImageContent(),
            ),
          ),
          if (!_isLoading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _displayImagePath != null ? Icons.edit : Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 40, color: Colors.red),
          const SizedBox(height: 4),
          Text(
            'Failed to load image',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_displayImagePath != null && _displayImagePath!.isNotEmpty) {
      final file = File(_displayImagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            setState(() {
              _hasError = true;
            });
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 40, color: Colors.red),
                const SizedBox(height: 4),
                Text(
                  'Failed to load image',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        );
      }
    }

    // Default placeholder
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person, size: 50, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          'Add Photo',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}