/// OwnedSites tab - displays sites owned by current user from local SQLite database
///
/// Feature 1.35: Uses NEW Site model from lib/Data/models/site.dart
/// - Loads from SiteDao (local SQLite)
/// - Supports grid/list view toggle
/// - Memory efficient using builder widgets

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteInfo.dart';
// import 'package:snagsnapper/Screens/Sites/SiteInfo/siteStatus.dart'; // BACKUP - legacy UI
import 'package:snagsnapper/Screens/Sites/SiteInfo/site_status_v2.dart';
import 'package:snagsnapper/Widgets/site_grid_tile.dart';
import 'package:snagsnapper/Widgets/site_list_tile.dart';

class OwnedSites extends StatefulWidget {
  final bool isGridView;

  const OwnedSites({
    super.key,
    required this.isGridView,
  });

  @override
  State<OwnedSites> createState() => _OwnedSitesState();
}

class _OwnedSitesState extends State<OwnedSites> {
  /// Stream of owned sites from local database
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

      // Use watchAllSites and filter for owned sites
      _sitesStream = database.siteDao.watchAllSites(_userEmail!).map(
        (sites) => sites.where((site) => site.isOwnedBy(_userEmail!)).toList()
      );

      if (kDebugMode) {
        print('OwnedSites: Initialized stream for user $_userEmail');
      }
    }
  }

  void _showProUserAlert(BuildContext context) {
    Alert(
      context: context,
      style: kWelcomeAlertStyle(context),
      image: Image.asset(
        "images/worker.png",
        height: 75,
      ),
      title: "PRO USER",
      content: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 20.0, right: 8.0, left: 8.0, bottom: 20.0),
            child: Text(
              'This is PRO user feature.\nPRO users can create their own sites and share it with their nonPro and Pro colleagues and can produce PDF reports to share with others.',
              textAlign: TextAlign.center,
              style: kSendButtonTextStyle.copyWith(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          )
        ],
      ),
      buttons: [
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () {
            Navigator.pushNamed(context, '/upgradeScreen');
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "Show more",
            style: kSendButtonTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "OK",
            style: kSendButtonTextStyle.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    ).show();
  }

  void _onSiteTap(Site site) {
    if (kDebugMode) {
      print('OwnedSites: Tapped site ${site.id} - ${site.name}');
    }

    // Navigate to SiteStatusV2 to view snags (edit via site header tap)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SiteStatusV2(site: site)),
    );
  }

  void _onSiteLongPress(Site site) {
    // TODO: Implement site deletion
    if (kDebugMode) {
      print('OwnedSites: Long pressed site ${site.id} - ${site.name}');
    }
  }

  void _onCreateSite() {
    // Navigate to SiteInfo for creating a new site
    // SiteInfo(null) creates a new site
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SiteInfo(null)),
    ).then((value) {
      // TODO: Handle return value when SiteStatus is updated
      if (value != null && kDebugMode) {
        print('OwnedSites: Site created, returned value: $value');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isPro = Provider.of<CP>(context).getPro();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 10.0, bottom: 10.0),
        child: SizedBox(
          height: 60.0,
          width: 60.0,
          child: FittedBox(
            child: FloatingActionButton(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(100),
                  bottomLeft: Radius.circular(100),
                  bottomRight: Radius.circular(100),
                  topLeft: Radius.circular(20),
                ),
              ),
              backgroundColor: isPro
                  ? theme.colorScheme.primary
                  : Colors.grey[500],
              onPressed: () => isPro
                  ? _onCreateSite()
                  : _showProUserAlert(context),
              child: Icon(
                isPro ? Icons.add : Icons.lock,
                size: 40.0,
                color: isPro ? activePageIcon : Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_sitesStream == null) {
      return Center(
        child: Text(
          'Please sign in to view your sites',
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
            print('OwnedSites: Error loading sites: ${snapshot.error}');
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
            Icons.domain_add_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No sites yet',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first site',
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
          isShared: false,
          onTap: () => _onSiteTap(site),
          onLongPress: () => _onSiteLongPress(site),
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
          isShared: false,
          onTap: () => _onSiteTap(site),
          onLongPress: () => _onSiteLongPress(site),
        );
      },
    );
  }
}