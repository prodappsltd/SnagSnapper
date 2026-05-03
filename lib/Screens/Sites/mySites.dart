
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/sharedSites.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/ownedSites.dart';
// import 'package:snagsnapper/Screens/Sites/Tabs/allSites.dart'; // Removed - not needed

class MySites extends StatelessWidget {
  const MySites({super.key});


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
                  )
                ]
            ),
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: TabBarView(
          children: <Widget>[
            const OwnedSites(),
            const SharedSites(),
          ],
        ),
      ),
    );
  }
}




