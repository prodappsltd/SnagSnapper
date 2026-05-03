import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Widget for displaying images from file paths or base64 strings
/// Supports both relative paths (SnagSnapper/...) and absolute paths
/// Also supports legacy base64 images for backwards compatibility
class ImageHelper extends StatelessWidget {
  /// The file path to display (relative or absolute)
  /// Takes priority over b64Image if both are provided
  final String? filePath;

  /// Legacy base64 image string (for backwards compatibility with snags)
  final String? b64Image;

  final VoidCallback callBackFunction;
  final String text;
  final double height;
  final double iconSize;

  const ImageHelper({
    super.key,
    this.iconSize = 50.0,
    this.filePath,
    this.b64Image,
    required this.callBackFunction,
    this.height = 100.0,
    this.text = 'Click to add\nyour company logo',
  });

  /// Check if we have valid image data (either file path or base64)
  bool get _hasImage {
    return (filePath != null && filePath!.isNotEmpty) ||
           (b64Image != null && b64Image!.isNotEmpty);
  }

  /// Check if we're using file-based image (vs base64)
  bool get _isFileBased {
    return filePath != null && filePath!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: callBackFunction,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: _hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageWidget(theme),
              )
            : _buildPlaceholder(theme),
      ),
    );
  }

  Widget _buildImageWidget(ThemeData theme) {
    // Use file-based approach if filePath is provided
    if (_isFileBased) {
      return _buildFileImage(theme);
    }

    // Fall back to base64 for legacy support
    return _buildBase64Image(theme);
  }

  /// Build image from file path
  Widget _buildFileImage(ThemeData theme) {
    // If it's an absolute path, use directly
    if (filePath!.startsWith('/')) {
      return Image.file(
        File(filePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
      );
    }

    // For relative paths, we need to resolve them
    return FutureBuilder<String>(
      future: _resolveRelativePath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
          );
        }
        return _buildPlaceholder(theme);
      },
    );
  }

  /// Build image from base64 string (legacy support for snags)
  Widget _buildBase64Image(ThemeData theme) {
    try {
      return Image.memory(
        base64Decode(b64Image!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
      );
    } catch (e) {
      return _buildPlaceholder(theme);
    }
  }

  Future<String> _resolveRelativePath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, filePath!);
    } catch (e) {
      return '';
    }
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.add_a_photo_outlined,
            size: iconSize,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
