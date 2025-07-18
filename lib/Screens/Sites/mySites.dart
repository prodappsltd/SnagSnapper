
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/sharedSites.dart';

import 'package:snagsnapper/Screens/Sites/Tabs/allSites.dart';
import 'package:snagsnapper/Screens/Sites/Tabs/ownedSites.dart';

class MySites extends StatelessWidget {
  const MySites({super.key});


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT_WITH_OPTIONS),
          child: AppBar(
            title: Text('MY SITES', style: GoogleFonts.montserrat(textStyle: (TextStyle(color: Theme.of(context).colorScheme.onBackground))),),
            //backgroundColor: Theme.of(context).colorScheme.primary,
            leading: IconButton(icon: const Icon(Icons.arrow_back), color: Theme.of(context).colorScheme.onBackground, onPressed: () { Navigator.pop(context); },),
            bottom: TabBar(
                unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
                labelColor: Theme.of(context).colorScheme.primary,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const <Widget>[
                  Tab(
                    icon: Icon(Icons.person_pin),
                    text: 'OWNER',
                  ),
                  Tab(
                    icon: Icon(Icons.all_inclusive), // Was threesixty before
                    text: 'ALL',
                  ),
                  Tab(
                    icon: Icon(Icons.group),
                    text: 'SHARED',
                  )
                ]
            ),
          ),
        ),
        backgroundColor: Colors.white,//mainYellow,
        body: TabBarView(
          children: <Widget>[
            const OwnedSites(),
            AllSites(),
            const SharedSites(),
          ],
        ),
      ),
    );
  }
}




