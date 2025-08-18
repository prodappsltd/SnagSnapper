import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Image processing result with status and metadata
class ImageProcessingResult {
  final Uint8List data;
  final ImageProcessingStatus status;
  final String message;
  final int finalQuality;

  ImageProcessingResult({
    required this.data,
    required this.status,
    required this.message,
    required this.finalQuality,
  });
}

/// Status of image processing
enum ImageProcessingStatus {
  optimal,     // < 600KB
  acceptable,  // 600KB - 1MB
  rejected,    // > 1MB
}

/// Custom exceptions for image processing
class ImageTooLargeException implements Exception {
  final String message;
  ImageTooLargeException(this.message);
}

class InvalidImageException implements Exception {
  final String message;
  InvalidImageException(this.message);
}

/// Service for compressing images with two-tier validation
class ImageCompressionService {
  static ImageCompressionService? _instance;
  
  // Two-tier size validation constants
  static const int OPTIMAL_SIZE = 600 * 1024;     // 600KB
  static const int MAX_SIZE = 1024 * 1024;        // 1MB
  static const int TARGET_DIMENSION = 1024;       // Fixed 1024x1024
  
  // Quality compression constants
  static const int START_QUALITY = 90;            // Starting quality (updated per PRD)
  static const int MIN_QUALITY = 30;              // Minimum quality
  static const int QUALITY_STEP = 10;             // Quality reduction step
  
  ImageCompressionService._();
  
  ImageCompressionService();
  
  static ImageCompressionService get instance {
    _instance ??= ImageCompressionService._();
    return _instance!;
  }

  /// Process profile image with two-tier validation
  /// Returns processed image data with status information
  Future<ImageProcessingResult> processProfileImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Validate image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        throw InvalidImageException('Invalid image file');
      }
      
      // Step 1: Resize to fixed dimensions (1024x1024)
      final resized = img.copyResize(
        image,
        width: TARGET_DIMENSION,
        height: TARGET_DIMENSION,
        interpolation: img.Interpolation.linear,
      );
      
      // Step 2: Progressive quality compression
      int currentQuality = START_QUALITY;
      Uint8List? compressed;
      
      while (currentQuality >= MIN_QUALITY) {
        compressed = Uint8List.fromList(
          img.encodeJpg(resized, quality: currentQuality),
        );
        
        // Check if we achieved optimal size
        if (compressed.length <= OPTIMAL_SIZE) {
          return ImageProcessingResult(
            data: compressed,
            status: ImageProcessingStatus.optimal,
            message: '✅ Image optimized successfully (${compressed.length ~/ 1024}KB)',
            finalQuality: currentQuality,
          );
        }
        
        // If we're at minimum quality, decide based on size
        if (currentQuality == MIN_QUALITY) {
          if (compressed.length <= MAX_SIZE) {
            // Accept if under 1MB
            return ImageProcessingResult(
              data: compressed,
              status: ImageProcessingStatus.acceptable,
              message: '⚠️ Image compressed to ${compressed.length ~/ 1024}KB (larger than optimal)',
              finalQuality: currentQuality,
            );
          } else {
            // Reject if over 1MB at minimum quality
            break;
          }
        }
        
        currentQuality -= QUALITY_STEP;
      }
      
      // Step 3: Reject if still too large
      if (compressed!.length > MAX_SIZE) {
        throw ImageTooLargeException(
          '❌ Image too complex. Please choose a simpler image',
        );
      }
      
      // Should not reach here, but return acceptable as fallback
      return ImageProcessingResult(
        data: compressed,
        status: ImageProcessingStatus.acceptable,
        message: '⚠️ Image compressed to ${compressed.length ~/ 1024}KB',
        finalQuality: MIN_QUALITY,
      );
    } catch (e) {
      if (e is ImageTooLargeException || e is InvalidImageException) {
        rethrow;
      }
      throw InvalidImageException('Failed to process image: $e');
    }
  }

  /// Compress image in an isolate (legacy method, kept for compatibility)
  Future<File> compressImage(File imageFile, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 90,  // Updated to 90% per PRD
  }) async {
    // Use compute to run compression in isolate
    return await compute(
      _compressImageInIsolate,
      _CompressionParams(
        imageFile: imageFile,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      ),
    );
  }

  /// Compress image bytes in an isolate
  Future<Uint8List> compressImageBytes(Uint8List bytes, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 90,  // Updated to 90% per PRD
  }) async {
    return await compute(
      _compressBytesInIsolate,
      _ByteCompressionParams(
        bytes: bytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      ),
    );
  }

  /// Static function to run in isolate for file compression
  static Future<File> _compressImageInIsolate(_CompressionParams params) async {
    try {
      // Read image bytes
      final bytes = await params.imageFile.readAsBytes();
      
      // Decode image
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        return params.imageFile;
      }
      
      // Calculate new dimensions if needed
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > params.maxWidth || image.height > params.maxHeight) {
        final aspectRatio = image.width / image.height;
        
        if (aspectRatio > 1) {
          // Landscape
          if (image.width > params.maxWidth) {
            newWidth = params.maxWidth;
            newHeight = (params.maxWidth / aspectRatio).round();
          }
        } else {
          // Portrait or square
          if (image.height > params.maxHeight) {
            newHeight = params.maxHeight;
            newWidth = (params.maxHeight * aspectRatio).round();
          }
        }
        
        // Resize image
        image = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Compress as JPEG
      final compressedBytes = img.encodeJpg(image, quality: params.quality);
      
      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File(p.join(tempDir.path, 'compressed_$timestamp.jpg'));
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      if (kDebugMode) {
        print('Error compressing image in isolate: $e');
      }
      return params.imageFile;
    }
  }

  /// Static function to run in isolate for byte compression
  static Uint8List _compressBytesInIsolate(_ByteCompressionParams params) {
    try {
      // Decode image
      img.Image? image = img.decodeImage(params.bytes);
      
      if (image == null) {
        return params.bytes;
      }
      
      // Calculate new dimensions if needed
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > params.maxWidth || image.height > params.maxHeight) {
        final aspectRatio = image.width / image.height;
        
        if (aspectRatio > 1) {
          // Landscape
          if (image.width > params.maxWidth) {
            newWidth = params.maxWidth;
            newHeight = (params.maxWidth / aspectRatio).round();
          }
        } else {
          // Portrait or square
          if (image.height > params.maxHeight) {
            newHeight = params.maxHeight;
            newWidth = (params.maxHeight * aspectRatio).round();
          }
        }
        
        // Resize image
        image = img.copyResize(image, width: newWidth, height: newHeight);
      }
      
      // Compress as JPEG
      return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
    } catch (e) {
      if (kDebugMode) {
        print('Error compressing bytes in isolate: $e');
      }
      return params.bytes;
    }
  }
}

/// Parameters for image compression
class _CompressionParams {
  final File imageFile;
  final int maxWidth;
  final int maxHeight;
  final int quality;

  _CompressionParams({
    required this.imageFile,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });
}

/// Parameters for byte compression
class _ByteCompressionParams {
  final Uint8List bytes;
  final int maxWidth;
  final int maxHeight;
  final int quality;

  _ByteCompressionParams({
    required this.bytes,
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
  });
}