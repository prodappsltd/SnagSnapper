/// SharedSites tab - displays sites shared with current user from local SQLite database
///
/// Feature 1.35: Uses NEW Site model from lib/Data/models/site.dart
/// - Loads from SiteDao (local SQLite)
/// - Supports grid/list view toggle
/// - Memory efficient using builder widgets

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Widgets/site_grid_tile.dart';
import 'package:snagsnapper/Widgets/site_list_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _initSitesStream();
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
    // TODO: Update SiteStatus to accept new Site model (Phase 5)
    // For now, show a message that this feature is being updated
    if (kDebugMode) {
      print('SharedSites: Tapped site ${site.id} - ${site.name}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${site.name}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    // TODO: Navigate to SiteStatus when it's updated to use new model
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (context) => SiteStatus(site: site),
    // ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _buildBody(theme),
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
        ],
      ),
    );
  }

  Widget _buildGridView(List<Site> sites, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sites.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 420
            ? MediaQuery.of(context).size.width > 550 ? 4 : 3
            : 2,
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