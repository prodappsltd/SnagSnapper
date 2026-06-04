import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/sharedSites.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/ownedSites.dart';

/// MySites screen - displays owned and shared sites from local SQLite database
///
/// Feature 1.35: Updated to load from local DB (SiteDao) instead of ContentProvider
/// - Grid/List view toggle with IconButton in AppBar
/// - Memory efficient using builder widgets
/// - Uses NEW Site model from lib/Data/models/site.dart
class MySites extends StatefulWidget {
  const MySites({super.key});

  @override
  State<MySites> createState() => _MySitesState();
}

class _MySitesState extends State<MySites> {
  /// View mode: true = grid view, false = list view
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('MySites: Loading sites from local DB');
    }
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
    if (kDebugMode) {
      print('MySites: View switched to ${_isGridView ? "grid" : "list"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT_WITH_OPTIONS),
          child: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Sites',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Grid/List view toggle
              IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: _isGridView ? 'Switch to list view' : 'Switch to grid view',
                onPressed: _toggleViewMode,
              ),
            ],
            bottom: TabBar(
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: const <Widget>[
                Tab(
                  icon: Icon(Icons.person_pin),
                  text: 'My Sites',
                ),
                Tab(
                  icon: Icon(Icons.group),
                  text: 'Shared With Me',
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: TabBarView(
          children: <Widget>[
            OwnedSites(isGridView: _isGridView),
            SharedSites(isGridView: _isGridView),
          ],
        ),
      ),
    );
  }
}