import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

/// Service for managing signature capture, processing, and storage
class SignatureService {
  /// List of strokes, each stroke is a list of points
  final List<List<Offset>> _strokes = [];
  
  /// Current stroke being drawn
  List<Offset>? _currentStroke;

  /// Get all strokes
  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  /// Check if signature has content
  bool get hasContent => _strokes.isNotEmpty && 
      _strokes.any((stroke) => stroke.isNotEmpty);

  /// Start a new stroke
  void startNewStroke() {
    debugPrint('SignatureService: Starting new stroke');
    _currentStroke = [];
    _strokes.add(_currentStroke!);
  }

  /// Add a point to the current stroke
  void addPoint(Offset point) {
    if (_currentStroke != null) {
      debugPrint('SignatureService: Adding point $point to current stroke');
      _currentStroke!.add(point);
    } else {
      debugPrint('SignatureService: Cannot add point - no current stroke');
    }
  }

  /// Add a point with boundary validation
  void addPointWithBounds(Offset point, Size canvasSize) {
    if (isPointInBounds(point, canvasSize)) {
      addPoint(point);
    } else {
      debugPrint('SignatureService: Point $point is out of bounds for canvas $canvasSize');
    }
  }

  /// Check if a point is within canvas bounds
  bool isPointInBounds(Offset point, Size canvasSize) {
    return point.dx >= 0 && 
           point.dx <= canvasSize.width &&
           point.dy >= 0 && 
           point.dy <= canvasSize.height;
  }

  /// Clear all strokes
  void clear() {
    debugPrint('SignatureService: Clearing all strokes');
    _strokes.clear();
    _currentStroke = null;
  }

  /// Calculate the bounding box of the signature
  Rect? calculateSignatureBounds() {
    if (!hasContent) {
      debugPrint('SignatureService: No content for bounds calculation');
      return null;
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final stroke in _strokes) {
      for (final point in stroke) {
        minX = minX < point.dx ? minX : point.dx;
        minY = minY < point.dy ? minY : point.dy;
        maxX = maxX > point.dx ? maxX : point.dx;
        maxY = maxY > point.dy ? maxY : point.dy;
      }
    }

    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    debugPrint('SignatureService: Calculated bounds: $bounds');
    return bounds;
  }

  /// Generate image from strokes
  Future<Uint8List?> generateImage(Size canvasSize) async {
    if (!hasContent) {
      debugPrint('SignatureService: No content to generate image');
      return null;
    }

    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        backgroundPaint,
      );

      // Draw strokes
      _drawStrokes(canvas);

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );

      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('SignatureService: Failed to convert image to bytes');
        return null;
      }

      debugPrint('SignatureService: Generated image ${canvasSize.width}x${canvasSize.height}');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('SignatureService: Error generating image: $e');
      return null;
    }
  }

  /// Generate cropped image (removes whitespace)
  Future<Uint8List?> generateCroppedImage(Size canvasSize) async {
    if (!hasContent) {
      return null;
    }

    // Calculate signature bounds
    final bounds = calculateSignatureBounds();
    if (bounds == null) {
      return null;
    }

    try {
      // Add small padding (3px) to avoid cutting the signature
      const padding = 3.0;
      final paddedBounds = Rect.fromLTRB(
        (bounds.left - padding).clamp(0, canvasSize.width),
        (bounds.top - padding).clamp(0, canvasSize.height),
        (bounds.right + padding).clamp(0, canvasSize.width),
        (bounds.bottom + padding).clamp(0, canvasSize.height),
      );

      // Create a picture recorder with cropped size
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw white background
      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, paddedBounds.width, paddedBounds.height),
        backgroundPaint,
      );

      // Translate canvas to crop position
      canvas.translate(-paddedBounds.left, -paddedBounds.top);

      // Draw strokes
      _drawStrokes(canvas);

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        paddedBounds.width.toInt(),
        paddedBounds.height.toInt(),
      );

      // Convert to byte data
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }

      debugPrint('SignatureService: Generated cropped image ${paddedBounds.width}x${paddedBounds.height}');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('SignatureService: Error generating cropped image: $e');
      return null;
    }
  }

  /// Generate JPEG image with specified quality
  Future<Uint8List?> generateJpegImage(Size canvasSize, int quality) async {
    // First generate PNG image (cropped)
    final pngData = await generateCroppedImage(canvasSize);
    if (pngData == null) {
      return null;
    }

    try {
      // Decode PNG
      final image = img.decodeImage(pngData);
      if (image == null) {
        debugPrint('SignatureService: Failed to decode PNG for JPEG conversion');
        return null;
      }

      // Encode as JPEG with specified quality
      final jpegData = img.encodeJpg(image, quality: quality);
      
      debugPrint('SignatureService: Converted to JPEG with quality $quality');
      return Uint8List.fromList(jpegData);
    } catch (e) {
      debugPrint('SignatureService: Error converting to JPEG: $e');
      return null;
    }
  }

  /// Draw strokes on canvas
  void _drawStrokes(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      if (stroke.length < 2) {
        // Draw a dot for single-point strokes
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.5, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }

      // Draw path for multi-point strokes
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  /// Calculate canvas size based on screen width
  Size calculateCanvasSize(double screenWidth) {
    const double defaultWidth = 640;
    const double height = 360;
    
    // Use screen width if less than default, otherwise use default
    final width = screenWidth < defaultWidth ? screenWidth : defaultWidth;
    
    debugPrint('SignatureService: Canvas size calculated as ${width}x$height');
    return Size(width, height);
  }

  /// Generate signature file path
  String generateSignaturePath(String userId) {
    return 'SnagSnapper/$userId/Profile/signature.jpg';
  }

  /// Save signature to file system
  Future<String?> saveSignature(String userId, Uint8List imageData) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      
      // Create subdirectories if they don't exist
      final userDir = Directory(path.join(directory.path, 'SnagSnapper', userId, 'Profile'));
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
        debugPrint('SignatureService: Created directory ${userDir.path}');
      }

      // Delete existing signature if it exists
      await deleteSignature(userId);

      // Save new signature
      final file = File(path.join(userDir.path, 'signature.jpg'));
      await file.writeAsBytes(imageData);
      
      debugPrint('SignatureService: Saved signature to ${file.path}');
      
      // Return relative path for database storage
      return generateSignaturePath(userId);
    } catch (e) {
      debugPrint('SignatureService: Error saving signature: $e');
      return null;
    }
  }

  /// Delete existing signature file
  Future<bool> deleteSignature(String userId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(
        directory.path, 
        'SnagSnapper', 
        userId, 
        'Profile', 
        'signature.jpg'
      ));
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('SignatureService: Deleted existing signature');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('SignatureService: Error deleting signature: $e');
      return false;
    }
  }

  /// Check if signature exists
  Future<bool> signatureExists(String userId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(
        directory.path, 
        'SnagSnapper', 
        userId, 
        'Profile', 
        'signature.jpg'
      ));
      
      final exists = await file.exists();
      debugPrint('SignatureService: Signature exists for $userId: $exists');
      return exists;
    } catch (e) {
      debugPrint('SignatureService: Error checking signature existence: $e');
      return false;
    }
  }

  /// Get signature file
  Future<File?> getSignatureFile(String userId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(
        directory.path, 
        'SnagSnapper', 
        userId, 
        'Profile', 
        'signature.jpg'
      ));
      
      if (await file.exists()) {
        return file;
      }
      
      return null;
    } catch (e) {
      debugPrint('SignatureService: Error getting signature file: $e');
      return null;
    }
  }
}