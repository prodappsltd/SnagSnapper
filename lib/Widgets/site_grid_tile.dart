import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/Data/models/site.dart';

/// Grid tile widget for displaying a Site from the local database
///
/// Uses file-based image loading (imageLocalPath) instead of base64
/// Falls back to placeholder image if no local image exists
class SiteGridTile extends StatelessWidget {
  final Site site;
  final bool isShared;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SiteGridTile({
    super.key,
    required this.site,
    this.isShared = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey[500]!,
              offset: const Offset(0.0, 0.0),
              blurRadius: 5.0,
              spreadRadius: 0.0,
            )
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0.0),
            topRight: Radius.elliptical(50.0, 50.0),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0.0),
            topRight: Radius.elliptical(50.0, 50.0),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              _SiteImage(imageLocalPath: site.imageLocalPath),

              // Content overlay
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // Shared indicator at top
                  if (isShared)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary,
                        radius: 16,
                        child: const Icon(
                          Icons.group,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                  // Flexible spacer with optional debug ID
                  Expanded(
                    child: kDebugMode
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              color: Colors.black54,
                              child: Text(
                                site.id.substring(0, 5),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Bottom info bar
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    width: double.infinity,
                    color: const Color(0xAAFFFFFF),
                    child: Column(
                      children: <Widget>[
                        Text(
                          site.name,
                          style: GoogleFonts.montserrat(
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${site.totalSnags} snags',
                          style: const TextStyle(fontFamily: "Roboto-Bold.ttf"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal widget for loading site image from local file path
class _SiteImage extends StatelessWidget {
  final String? imageLocalPath;

  const _SiteImage({this.imageLocalPath});

  @override
  Widget build(BuildContext context) {
    if (imageLocalPath == null || imageLocalPath!.isEmpty) {
      return _buildPlaceholder();
    }

    // If it's an absolute path, use directly
    if (imageLocalPath!.startsWith('/')) {
      final file = File(imageLocalPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // For relative paths, resolve from app documents directory
    return FutureBuilder<String>(
      future: _resolveRelativePath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final file = File(snapshot.data!);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            );
          }
        }
        return _buildPlaceholder();
      },
    );
  }

  Future<String> _resolveRelativePath() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return p.join(appDir.path, imageLocalPath!);
    } catch (e) {
      return '';
    }
  }

  Widget _buildPlaceholder() {
    return Image.asset(
      'images/1024LowPoly.png',
      fit: BoxFit.cover,
    );
  }
}
