import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Reusable image picker widget with consistent UI across the app
/// Shows a bottom sheet with camera, gallery, and optional remove options
class ReusableImagePicker {
  /// Shows the image selection bottom sheet
  /// 
  /// [context] - Build context for showing the modal
  /// [onImageSelected] - Callback when user selects camera or gallery
  /// [onImageRemoved] - Optional callback when user chooses to remove image
  /// [removeItemName] - Text to show after "Remove" (e.g., "Logo", "Photo", "Image")
  /// [removeItemDescription] - Subtitle text for remove option (e.g., "Delete company logo from profile")
  /// [hasExistingImage] - Whether to show the remove option
  static void show({
    required BuildContext context,
    required Function(ImageSource) onImageSelected,
    VoidCallback? onImageRemoved,
    String removeItemName = 'Image',
    String removeItemDescription = 'Delete image',
    bool hasExistingImage = false,
  }) {
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
                'Use camera to capture $removeItemName',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                onImageSelected(ImageSource.camera);
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
                onImageSelected(ImageSource.gallery);
              },
            ),
            // Remove option if image exists
            if (hasExistingImage && onImageRemoved != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                title: Text(
                  'Remove $removeItemName',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  removeItemDescription,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onImageRemoved();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Shows only the remove option bottom sheet (for tap on existing image)
  /// 
  /// [context] - Build context for showing the modal
  /// [onImageRemoved] - Callback when user chooses to remove image
  /// [removeItemName] - Text to show after "Remove" (e.g., "Logo", "Photo", "Image")
  /// [removeItemDescription] - Subtitle text for remove option
  static void showRemoveOnly({
    required BuildContext context,
    required VoidCallback onImageRemoved,
    String removeItemName = 'Image',
    String removeItemDescription = 'Delete image',
  }) {
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
            // Remove option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: Text(
                'Remove $removeItemName',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                removeItemDescription,
                style: GoogleFonts.inter(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                onImageRemoved();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}