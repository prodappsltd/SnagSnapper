import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'package:snagsnapper/widgets/signature_painter.dart';

/// Full-screen signature capture interface
class SignatureCaptureScreen extends StatefulWidget {
  final String userId;
  final SignatureService? signatureService;

  const SignatureCaptureScreen({
    Key? key,
    required this.userId,
    this.signatureService,
  }) : super(key: key);

  /// Show signature capture screen and return the saved path or null if cancelled
  static Future<String?> show(
    BuildContext context,
    String userId, {
    SignatureService? signatureService,
  }) async {
    // Lock to portrait orientation (PRD requirement)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SignatureCaptureScreen(
          userId: userId,
          signatureService: signatureService,
        ),
      ),
    );

    // Restore orientation preferences
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return result;
  }

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late SignatureService _signatureService;
  bool _isSaving = false;
  Size? _canvasSize;

  @override
  void initState() {
    super.initState();
    _signatureService = widget.signatureService ?? SignatureService();
    debugPrint('SignatureCaptureScreen: Initialized for user ${widget.userId}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Calculate canvas size based on screen dimensions (16:9 aspect ratio)
    final screenSize = MediaQuery.of(context).size;
    _canvasSize = _signatureService.calculateCanvasSize(screenSize.width, screenSize.height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF424242), // Dark grey background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Spacer to center the canvas and buttons vertically
            const Spacer(),
            
            // Canvas
            _buildCanvas(),
            
            // Buttons immediately below canvas
            _buildButtons(),
            
            // Spacer to balance the layout
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text(
        'Sign Here',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    if (_canvasSize == null) {
      return const CircularProgressIndicator();
    }

    return Container(
      width: _canvasSize!.width,
      height: _canvasSize!.height,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: Container(
            color: Colors.white,
            child: CustomPaint(
              size: _canvasSize!,
              painter: SignaturePainter(
                strokes: _signatureService.strokes,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Clear button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleClear,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6E00), // Construction orange
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Cancel and Use Signature buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Use Signature button
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6E00), // Construction orange
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Use Signature',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    if (_canvasSize == null) return;
    
    setState(() {
      _signatureService.startNewStroke();
      final localPosition = details.localPosition;
      _signatureService.addPointWithBounds(localPosition, _canvasSize!);
    });
    
    debugPrint('SignatureCaptureScreen: Started new stroke at ${details.localPosition}');
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_canvasSize == null) return;
    
    final localPosition = details.localPosition;
    _signatureService.addPointWithBounds(localPosition, _canvasSize!);
    
    // Force immediate repaint for better drawing visibility
    setState(() {});
  }

  void _handlePanEnd(DragEndDetails details) {
    debugPrint('SignatureCaptureScreen: Ended stroke');
  }

  void _handleClear() {
    setState(() {
      _signatureService.clear();
    });
    debugPrint('SignatureCaptureScreen: Cleared signature');
  }

  void _handleCancel() {
    debugPrint('SignatureCaptureScreen: Cancelled');
    Navigator.of(context).pop(null);
  }

  Future<void> _handleSave() async {
    // Check if there's content
    if (!_signatureService.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your signature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('SignatureCaptureScreen: Generating JPEG image');
      
      // Generate JPEG image with 95% quality
      final imageData = await _signatureService.generateJpegImage(_canvasSize!, 95);
      if (imageData == null) {
        throw Exception('Failed to generate image');
      }

      debugPrint('SignatureCaptureScreen: Saving signature to file system');
      
      // Save to file system
      final path = await _signatureService.saveSignature(widget.userId, imageData);
      if (path == null) {
        throw Exception('Failed to save signature');
      }

      debugPrint('SignatureCaptureScreen: Signature saved successfully at $path');
      
      // Return the path
      if (mounted) {
        Navigator.of(context).pop(path);
      }
    } catch (e) {
      debugPrint('SignatureCaptureScreen: Error saving signature: $e');
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save signature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Clear the signature service when disposing
    _signatureService.clear();
    super.dispose();
  }
}