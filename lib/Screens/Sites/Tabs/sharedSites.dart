

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteStatus.dart';
import 'package:snagsnapper/Widgets/siteGridView.dart';


class SharedSites extends StatelessWidget {
  const SharedSites({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // backgroundColor: Provider.of<UserData>(context).getSecondryColor(),
      body: GridView.builder(
        itemCount: Provider.of<CP>(context).getMapOfSharedSites().length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context,position){
          return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context)=>SiteStatus(
                  site:Provider.of<CP>(context).getMapOfSharedSites().values.elementAt(position))
              ),
              ),
              child: SiteGridView(Provider.of<CP>(context).getMapOfSharedSites().values.elementAt(position)));
        },
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width>420? MediaQuery.of(context).size.width>550? 4 : 3 : 2),
      ),
    );
  }
}