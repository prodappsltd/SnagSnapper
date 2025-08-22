import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Signature Pad Widget
/// Allows users to draw signatures and save them as images
class SignaturePad extends StatefulWidget {
  final String userId;
  final String? currentSignaturePath;
  final ImageStorageService imageStorageService;
  final ProfileDao? profileDao;
  final Function(String?) onSignatureChanged;
  final Function(String)? onError;
  final bool readOnly;

  const SignaturePad({
    super.key,
    required this.userId,
    required this.currentSignaturePath,
    required this.imageStorageService,
    required this.onSignatureChanged,
    this.profileDao,
    this.onError,
    this.readOnly = false,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final GlobalKey _signatureKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  String? _displaySignaturePath;
  bool _isDrawing = false;
  bool _isSaving = false;
  bool _hasError = false;
  bool _showSignature = false;

  @override
  void initState() {
    super.initState();
    _displaySignaturePath = widget.currentSignaturePath;
    _showSignature = _displaySignaturePath != null && _displaySignaturePath!.isNotEmpty;
    _loadSignatureIfNeeded();
  }

  Future<void> _loadSignatureIfNeeded() async {
    if (widget.currentSignaturePath != null && widget.currentSignaturePath!.isNotEmpty) {
      // Convert relative path to absolute if needed
      if (!widget.currentSignaturePath!.startsWith('/')) {
        final absolutePath = await widget.imageStorageService.relativeToAbsolute(widget.currentSignaturePath!);
        setState(() {
          _displaySignaturePath = absolutePath;
        });
      }
    }
  }

  void _startDrawing(Offset point) {
    if (widget.readOnly) return;
    
    setState(() {
      _isDrawing = true;
      _currentStroke = [point];
      _showSignature = false;
    });
  }

  void _updateDrawing(Offset point) {
    if (!_isDrawing || widget.readOnly) return;
    
    setState(() {
      _currentStroke.add(point);
    });
  }

  void _endDrawing() {
    if (!_isDrawing || widget.readOnly) return;
    
    setState(() {
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
      }
      _currentStroke = [];
      _isDrawing = false;
    });
    
    // Notify parent of change
    widget.onSignatureChanged(null);
  }

  void _clearSignature() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
      _isDrawing = false;
      _showSignature = false;
    });
  }

  void _undoStroke() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  Future<void> _saveSignature() async {
    if (_strokes.isEmpty && _currentStroke.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first')),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _hasError = false;
      });

      // Capture the signature as image
      final boundary = _signatureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to capture signature');
      }

      // First capture as PNG (Flutter limitation)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert signature to image');
      }

      // Convert PNG to JPEG with 95% quality (per PRD)
      final pngBytes = byteData.buffer.asUint8List();
      final img.Image? decodedImage = img.decodeImage(pngBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image for JPEG conversion');
      }
      
      // Encode as JPEG with 95% quality
      final jpegBytes = img.encodeJpg(decodedImage, quality: 95);

      // Save to temporary file as JPEG
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'signature_temp_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      await tempFile.writeAsBytes(jpegBytes);

      // Delete old signature if exists
      if (widget.currentSignaturePath != null) {
        await widget.imageStorageService.deleteSignatureImage(widget.userId);
      }

      // Save new signature
      final relativePath = await widget.imageStorageService.saveSignatureImage(tempFile, widget.userId);
      final absolutePath = await widget.imageStorageService.relativeToAbsolute(relativePath);

      // Clean up temp file
      await tempFile.delete();

      setState(() {
        _displaySignaturePath = absolutePath;
        _showSignature = true;
        _isSaving = false;
        _strokes.clear();
        _currentStroke.clear();
      });

      // Notify parent
      widget.onSignatureChanged(relativePath);

      // Set sync flag if DAO provided
      if (widget.profileDao != null) {
        await widget.profileDao!.setNeedsSignatureSync(widget.userId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature saved successfully')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _hasError = true;
      });
      
      if (widget.onError != null) {
        widget.onError!(e.toString());
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save signature'),
          backgroundColor: Colors.red,
        ),
      );
      
      if (kDebugMode) {
        print('Error saving signature: $e');
      }
    }
  }

  void _redrawSignature() {
    setState(() {
      _showSignature = false;
      _strokes.clear();
      _currentStroke.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Signature',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!widget.readOnly && !_showSignature)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed: _strokes.isEmpty ? null : _undoStroke,
                        tooltip: 'Undo',
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: (_strokes.isEmpty && _currentStroke.isEmpty) ? null : _clearSignature,
                        tooltip: 'Clear',
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _isSaving || (_strokes.isEmpty && _currentStroke.isEmpty) 
                            ? null 
                            : _saveSignature,
                        tooltip: 'Save',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildSignatureContent(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSignatureContent() {
    if (_isSaving) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError && !_showSignature) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 40, color: Colors.red),
          const SizedBox(height: 8),
          const Text('Signature not found'),
        ],
      );
    }

    if (_showSignature && _displaySignaturePath != null) {
      final file = File(_displaySignaturePath!);
      if (file.existsSync()) {
        return Stack(
          children: [
            Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 40, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Failed to load signature'),
                  ],
                );
              },
            ),
            if (!widget.readOnly)
              Positioned(
                bottom: 8,
                right: 8,
                child: TextButton.icon(
                  onPressed: _redrawSignature,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Tap to redraw'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
          ],
        );
      }
    }

    // Drawing pad
    return GestureDetector(
      onPanStart: (details) => _startDrawing(details.localPosition),
      onPanUpdate: (details) => _updateDrawing(details.localPosition),
      onPanEnd: (_) => _endDrawing(),
      child: RepaintBoundary(
        key: _signatureKey,
        child: CustomPaint(
          painter: SignaturePainter(
            strokes: _strokes,
            currentStroke: _currentStroke,
          ),
          child: Container(
            color: Colors.transparent,
            child: _strokes.isEmpty && _currentStroke.isEmpty
                ? const Center(
                    child: Text(
                      'Sign above',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for signature drawing
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  SignaturePainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.length == 1) {
        // Draw a point for single tap
        canvas.drawCircle(stroke[0], 1.0, paint);
      }
    }

    // Draw current stroke
    if (currentStroke.length > 1) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    } else if (currentStroke.length == 1) {
      canvas.drawCircle(currentStroke[0], 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return true;
  }
}