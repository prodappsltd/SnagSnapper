/// SharedSites tab - displays sites shared with current user from local SQLite database
///
/// Feature 1.35: Uses NEW Site model from lib/Data/models/site.dart
/// - Loads from SiteDao (local SQLite)
/// - Supports grid/list view toggle
/// - Memory efficient using builder widgets
/// - "Sync" button to fetch shared sites from Firebase

import 'dart:async';

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

  /// Track if sites exist (for conditional FAB display)
  bool _hasSites = false;

  /// Cooldown UI state (reads from service, timer for display updates)
  final SharedSiteService _syncService = SharedSiteService();
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _initSitesStream();
    _initCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Initialize cooldown timer if service has active cooldown
  void _initCooldownTimer() {
    if (_syncService.cooldownRemaining > 0) {
      _startCooldownTimer();
    }
  }

  /// Start timer to update UI countdown (reads from service)
  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final remaining = _syncService.cooldownRemaining;
        if (remaining <= 0) {
          timer.cancel();
        }
        setState(() {}); // Trigger rebuild to update UI
      } else {
        timer.cancel();
      }
    });
    setState(() {}); // Initial rebuild
  }

  /// Record sync and start cooldown timer
  void _recordSyncAndStartCooldown() {
    _syncService.recordSyncTime();
    _startCooldownTimer();
  }

  /// Check if sync is allowed (not downloading and service allows)
  bool get _canSync => !_isDownloading && _syncService.canSync;

  /// Check and download shared sites from Firebase
  Future<void> _checkAndDownload() async {
    if (!_canSync) return;

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
        _recordSyncAndStartCooldown();

        // Show bottom sheet for empty result, snackbar for success/errors
        if (result.isEmpty && !result.hasErrors) {
          _showNoNewSitesSheet();
        } else {
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
                  : Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = '';
        });
        _recordSyncAndStartCooldown();

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

  void _showNoNewSitesSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'No New Shared Sites',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'We checked and there are no new sites shared with you at this time.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 24,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Expecting a shared site? Ask the Site Owner to remove and re-add you, then try again in a few minutes.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.colorScheme.onSecondaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
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
    // Only show FAB when sites exist (not in empty state)
    if (!_hasSites) return null;

    final inCooldown = _syncService.cooldownRemaining > 0;
    final isDisabled = !_canSync;

    return FloatingActionButton.extended(
      onPressed: isDisabled ? null : _checkAndDownload,
      backgroundColor: isDisabled
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.primary,
      foregroundColor: isDisabled
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onPrimary,
      elevation: isDisabled ? 0 : 4,
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
          : const Icon(Icons.sync_rounded),
      label: Text(
        _isDownloading
            ? _downloadStatus
            : inCooldown
                ? 'Sync in ${_syncService.cooldownRemaining}s'
                : 'Sync',
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

        // Update _hasSites state for FAB visibility
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hasSites != sites.isNotEmpty) {
            setState(() => _hasSites = sites.isNotEmpty);
          }
        });

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSyncButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(ThemeData theme) {
    final inCooldown = _syncService.cooldownRemaining > 0;
    final isDisabled = !_canSync;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _checkAndDownload,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primary,
          foregroundColor: isDisabled
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isDisabled ? 0 : 3,
        ),
        icon: _isDownloading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : Icon(Icons.sync_rounded, size: 26, color: isDisabled
                ? theme.colorScheme.onSurfaceVariant
                : null),
        label: Text(
          _isDownloading
              ? _downloadStatus
              : inCooldown
                  ? 'Sync in ${_syncService.cooldownRemaining}s'
                  : 'Sync',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
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