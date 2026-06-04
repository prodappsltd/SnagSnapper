import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/Data/models/site.dart';

/// List tile widget for displaying a Site from the local database
///
/// Adaptive UI design that adjusts to different screen sizes
/// Image extends to top, left, and bottom edges of the tile
/// Shows site name, company, and snag counts
class SiteListTile extends StatelessWidget {
  final Site site;
  final bool isShared;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SiteListTile({
    super.key,
    required this.site,
    this.isShared = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Adaptive sizing based on screen width
    final tileHeight = (screenWidth * 0.25).clamp(95.0, 130.0);
    final imageWidth = tileHeight; // Square image matching tile height

    // Adaptive font sizes
    final titleFontSize = (screenWidth * 0.04).clamp(14.0, 18.0);
    final subtitleFontSize = (screenWidth * 0.032).clamp(11.0, 14.0);
    final chipFontSize = (screenWidth * 0.028).clamp(10.0, 12.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: tileHeight,
          child: Row(
            children: [
              // Image - fills full height of tile
              SizedBox(
                width: imageWidth,
                height: tileHeight,
                child: _SiteImageThumbnail(imageLocalPath: site.imageLocalPath),
              ),

              // Site details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Site name with shared badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              site.name,
                              style: GoogleFonts.montserrat(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isShared)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.group,
                                size: titleFontSize,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),

                      // Company name or debug ID
                      if (site.companyName != null && site.companyName!.isNotEmpty)
                        Text(
                          site.companyName!,
                          style: GoogleFonts.inter(
                            fontSize: subtitleFontSize,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (kDebugMode)
                        Text(
                          'ID: ${site.id.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: chipFontSize,
                            color: theme.colorScheme.outline,
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      // Snag counts
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _SnagCountChip(
                            count: site.totalSnags,
                            label: 'Total',
                            color: theme.colorScheme.secondary,
                            fontSize: chipFontSize,
                          ),
                          _SnagCountChip(
                            count: site.openSnags,
                            label: 'Open',
                            color: Colors.orange,
                            fontSize: chipFontSize,
                          ),
                          _SnagCountChip(
                            count: site.closedSnags,
                            label: 'Closed',
                            color: Colors.green,
                            fontSize: chipFontSize,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: titleFontSize + 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small chip showing snag count
class _SnagCountChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final double fontSize;

  const _SnagCountChip({
    required this.count,
    required this.label,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

/// Internal widget for loading site image thumbnail from local file path
class _SiteImageThumbnail extends StatelessWidget {
  final String? imageLocalPath;

  const _SiteImageThumbnail({this.imageLocalPath});

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
        width: double.infinity,
        height: double.infinity,
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
              width: double.infinity,
              height: double.infinity,
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
      width: double.infinity,
      height: double.infinity,
    );
  }
}
