import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:snagsnapper/services/image_compression_service.dart';

/// Service for managing local image storage
/// Handles profile images and signatures with offline-first approach
class ImageStorageService {
  // Singleton instance
  static ImageStorageService? _instance;
  
  ImageStorageService._();
  
  // Public constructor for dependency injection in tests
  ImageStorageService();
  
  /// Get singleton instance
  static ImageStorageService get instance {
    _instance ??= ImageStorageService._();
    return _instance!;
  }

  /// Get the app documents directory
  Future<Directory> get _appDocumentsDirectory async {
    return await getApplicationDocumentsDirectory();
  }

  /// Create user directory structure if it doesn't exist
  Future<Directory> _ensureUserDirectory(String userId) async {
    final appDir = await _appDocumentsDirectory;
    final userDir = Directory(p.join(appDir.path, 'SnagSnapper', userId, 'Profile'));
    
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
      if (kDebugMode) {
        print('Created user directory: ${userDir.path}');
      }
    }
    
    return userDir;
  }

  /// Save profile image
  /// Returns relative path for database storage
  /// Uses fixed naming (profile.jpg) for auto-overwrite
  /// Implements two-tier validation (600KB optimal, 1MB max)
  Future<String> saveProfileImage(File imageFile, String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      const fileName = 'profile.jpg'; // Fixed name for auto-overwrite
      final destinationPath = p.join(userDir.path, fileName);
      
      // Use the new two-tier compression service
      final compressionService = ImageCompressionService.instance;
      final xFile = XFile(imageFile.path);
      final result = await compressionService.processProfileImage(xFile);
      
      // Save compressed image to local storage (overwrites if exists)
      final destinationFile = File(destinationPath);
      await destinationFile.writeAsBytes(result.data);
      
      // Return relative path for database
      final relativePath = 'SnagSnapper/$userId/Profile/$fileName';
      
      if (kDebugMode) {
        print('Saved profile image: $relativePath');
        print('Compression result: ${result.message}');
      }
      
      return relativePath;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving profile image: $e');
      }
      // Re-throw specific exceptions for better error handling
      if (e is ImageTooLargeException || e is InvalidImageException) {
        rethrow;
      }
      throw Exception('Failed to save profile image');
    }
  }

  /// Get profile image path
  /// Converts relative path to absolute for display
  Future<String?> getProfileImagePath(String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      final profileFile = File(p.join(userDir.path, 'profile.jpg'));
      
      if (await profileFile.exists()) {
        return profileFile.path;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting profile image path: $e');
      }
      return null;
    }
  }

  /// Delete profile image
  Future<bool> deleteProfileImage(String userId) async {
    try {
      final imagePath = await getProfileImagePath(userId);
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            print('Deleted profile image: $imagePath');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting profile image: $e');
      }
      return false;
    }
  }

  /// Save signature image
  /// Returns relative path for database storage
  /// Uses fixed naming (signature.jpg) for auto-overwrite
  Future<String> saveSignatureImage(File imageFile, String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      const fileName = 'signature.jpg'; // Fixed name for auto-overwrite, using .jpg for consistency
      final destinationPath = p.join(userDir.path, fileName);
      
      // Save signature (already processed from canvas)
      // Convert to JPEG if needed for consistency
      await imageFile.copy(destinationPath);
      
      // Return relative path for database
      final relativePath = 'SnagSnapper/$userId/Profile/$fileName';
      
      if (kDebugMode) {
        print('Saved signature image: $relativePath');
      }
      
      return relativePath;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving signature image: $e');
      }
      throw Exception('Failed to save signature image');
    }
  }

  /// Get signature image path
  /// Converts relative path to absolute for display
  Future<String?> getSignatureImagePath(String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      final signatureFile = File(p.join(userDir.path, 'signature.jpg'));
      
      if (await signatureFile.exists()) {
        return signatureFile.path;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting signature image path: $e');
      }
      return null;
    }
  }

  /// Delete signature image
  Future<bool> deleteSignatureImage(String userId) async {
    try {
      final imagePath = await getSignatureImagePath(userId);
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            print('Deleted signature image: $imagePath');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting signature image: $e');
      }
      return false;
    }
  }

  /// Convert relative path to absolute path
  Future<String> relativeToAbsolute(String relativePath) async {
    final appDir = await _appDocumentsDirectory;
    return p.join(appDir.path, relativePath);
  }

  /// Convert absolute path to relative path
  String absoluteToRelative(String absolutePath) {
    // Extract the relative part starting from 'SnagSnapper/'
    final snagSnapperIndex = absolutePath.indexOf('SnagSnapper/');
    if (snagSnapperIndex != -1) {
      return absolutePath.substring(snagSnapperIndex);
    }
    return absolutePath;
  }

  /// Get image file from path
  /// Handles both relative and absolute paths
  Future<File> getImageFile(String imagePath) async {
    // Check if it's already an absolute path
    if (imagePath.startsWith('/')) {
      return File(imagePath);
    }
    
    // Convert relative path to absolute
    final absolutePath = await relativeToAbsolute(imagePath);
    return File(absolutePath);
  }

  /// Process image (resize and compress)
  Future<File> _processImage(File imageFile) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        return imageFile;
      }
      
      // Resize if needed (max 1024x1024)
      if (image.width > 1024 || image.height > 1024) {
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          newWidth = 1024;
          newHeight = (1024 / aspectRatio).round();
        } else {
          newHeight = 1024;
          newWidth = (1024 * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Compress and save as JPEG
      final compressedBytes = img.encodeJpg(image, quality: 90); // Updated to 90% per PRD
      
      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'temp_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image: $e');
      }
      return imageFile;
    }
  }

  /// Clean up orphaned files and migrate from timestamped to fixed names
  Future<void> cleanupOrphanedFiles(String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      final profileDir = Directory(userDir.path);
      
      if (await profileDir.exists()) {
        final files = profileDir.listSync();
        
        // Find and migrate old timestamped files
        File? newestProfileImage;
        File? newestSignature;
        DateTime? newestProfileTime;
        DateTime? newestSignatureTime;
        
        for (final file in files) {
          if (file is File) {
            final fileName = p.basename(file.path);
            final stat = await file.stat();
            
            // Find newest timestamped profile image
            if (fileName.startsWith('profile_') && fileName.contains(RegExp(r'\d+\.jpg'))) {
              if (newestProfileTime == null || stat.modified.isAfter(newestProfileTime)) {
                newestProfileImage = file;
                newestProfileTime = stat.modified;
              }
            }
            
            // Find newest timestamped signature
            if (fileName.startsWith('signature_') && fileName.contains(RegExp(r'\d+\.(png|jpg)'))) {
              if (newestSignatureTime == null || stat.modified.isAfter(newestSignatureTime)) {
                newestSignature = file;
                newestSignatureTime = stat.modified;
              }
            }
          }
        }
        
        // Migrate newest profile image to fixed name
        if (newestProfileImage != null) {
          final newPath = p.join(userDir.path, 'profile.jpg');
          await newestProfileImage.copy(newPath);
          
          // Delete all old timestamped profile images
          for (final file in files) {
            if (file is File) {
              final fileName = p.basename(file.path);
              if (fileName.startsWith('profile_') && fileName.contains(RegExp(r'\d+\.jpg'))) {
                await file.delete();
                if (kDebugMode) {
                  print('Deleted old timestamped file: ${file.path}');
                }
              }
            }
          }
        }
        
        // Migrate newest signature to fixed name
        if (newestSignature != null) {
          final newPath = p.join(userDir.path, 'signature.jpg');
          await newestSignature.copy(newPath);
          
          // Delete all old timestamped signatures
          for (final file in files) {
            if (file is File) {
              final fileName = p.basename(file.path);
              if (fileName.startsWith('signature_') && fileName.contains(RegExp(r'\d+\.(png|jpg)'))) {
                await file.delete();
                if (kDebugMode) {
                  print('Deleted old timestamped file: ${file.path}');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up orphaned files: $e');
      }
    }
  }

  /// Get storage size for user
  Future<int> getUserStorageSize(String userId) async {
    try {
      final userDir = await _ensureUserDirectory(userId);
      final profileDir = Directory(userDir.path);
      
      if (await profileDir.exists()) {
        int totalSize = 0;
        final files = profileDir.listSync();
        
        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
        
        return totalSize;
      }
      
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user storage size: $e');
      }
      return 0;
    }
  }
}