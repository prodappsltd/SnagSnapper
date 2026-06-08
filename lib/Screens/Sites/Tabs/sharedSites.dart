/// SharedSites tab - displays sites shared with current user from local SQLite database
///
/// Feature 1.35: Uses NEW Site model from lib/Data/models/site.dart
/// - Loads from SiteDao (local SQLite)
/// - Supports grid/list view toggle
/// - Memory efficient using builder widgets
/// - "Check & Download" button to fetch shared sites from Firebase

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/site_status_v2.dart';
import 'package:snagsnapper/Widgets/site_grid_tile.dart';
import 'package:snagsnapper/Widgets/site_list_tile.dart';
import 'package:snagsnapper/services/shared_site_service.dart';

class SharedSites extends StatefulWidget {
  final bool isGridView;

  const SharedSites({
    super.key,
    required this.isGridView,
  });

  @override
  State<SharedSites> createState() => _SharedSitesState();
}

class _SharedSitesState extends State<SharedSites> {
  /// Stream of shared sites from local database
  Stream<List<Site>>? _sitesStream;
  String? _userEmail;

  /// Download state
  bool _isDownloading = false;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _initSitesStream();
  }

  /// Check and download shared sites from Firebase
  Future<void> _checkAndDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadStatus = 'Checking...';
    });

    try {
      final result = await SharedSiteService().checkAndDownloadSharedSites(
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _downloadStatus = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = '';
        });

        // Show result snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(result.summary)),
              ],
            ),
            backgroundColor: result.hasErrors
                ? Colors.orange.shade700
                : (result.isEmpty ? Colors.grey.shade700 : Colors.green.shade700),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _initSitesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _userEmail = user.email;
      final database = AppDatabase.instance;

      // Use watchAllSites and filter for shared sites (not owned by user)
      _sitesStream = database.siteDao.watchAllSites(_userEmail!).map(
        (sites) => sites.where((site) => !site.isOwnedBy(_userEmail!)).toList()
      );

      if (kDebugMode) {
        print('SharedSites: Initialized stream for user $_userEmail');
      }
    }
  }

  void _onSiteTap(Site site) {
    if (kDebugMode) {
      print('SharedSites: Tapped site ${site.id} - ${site.name}');
    }

    // Navigate to SiteStatusV2 to view shared site snags
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SiteStatusV2(site: site)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _buildBody(theme),
      floatingActionButton: _buildFAB(theme),
    );
  }

  Widget? _buildFAB(ThemeData theme) {
    // Only show FAB when not in empty state
    return FloatingActionButton.extended(
      onPressed: _isDownloading ? null : _checkAndDownload,
      backgroundColor: _isDownloading
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primary,
      foregroundColor: _isDownloading
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onPrimary,
      elevation: _isDownloading ? 0 : 4,
      icon: _isDownloading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          : const Icon(Icons.cloud_download_rounded),
      label: Text(
        _isDownloading ? _downloadStatus : 'Check & Download',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_sitesStream == null) {
      return Center(
        child: Text(
          'Please sign in to view shared sites',
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return StreamBuilder<List<Site>>(
      stream: _sitesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          if (kDebugMode) {
            print('SharedSites: Error loading sites: ${snapshot.error}');
          }
          return Center(
            child: Text(
              'Error loading sites',
              style: GoogleFonts.inter(
                color: theme.colorScheme.error,
              ),
            ),
          );
        }

        final sites = snapshot.data ?? [];

        if (sites.isEmpty) {
          return _buildEmptyState(theme);
        }

        return widget.isGridView
            ? _buildGridView(sites, theme)
            : _buildListView(sites, theme);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No shared sites',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sites shared with you will appear here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildCheckAndDownloadButton(theme),
        ],
      ),
    );
  }

  Widget _buildCheckAndDownloadButton(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: _isDownloading ? null : _checkAndDownload,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isDownloading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.onPrimary,
                  ),
                ),
              )
            : const Icon(Icons.cloud_download_rounded),
        label: Text(
          _isDownloading ? _downloadStatus : 'Check & Download',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(List<Site> sites, ThemeData theme) {
    // Responsive grid columns:
    // - Phones (< 600): 2 columns
    // - iPad portrait (600-1000): 3 columns
    // - iPad landscape (> 1000): 4 columns
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1000 ? 4 : (screenWidth > 600 ? 3 : 2);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sites.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
      ),
      itemBuilder: (context, index) {
        final site = sites[index];
        return SiteGridTile(
          site: site,
          isShared: true,
          onTap: () => _onSiteTap(site),
        );
      },
    );
  }

  Widget _buildListView(List<Site> sites, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sites.length,
      itemBuilder: (context, index) {
        final site = sites[index];
        return SiteListTile(
          site: site,
          isShared: true,
          onTap: () => _onSiteTap(site),
        );
      },
    );
  }
}