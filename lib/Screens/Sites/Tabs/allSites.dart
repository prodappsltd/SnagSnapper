import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteStatus.dart';
import 'package:snagsnapper/Widgets/siteGridView.dart';

class AllSites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Provider.of<UserData>(context).getSecondryColor(),
      body: GridView.builder(
        itemCount: Provider.of<CP>(context).getMapOfAllSites().length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, position) {
          return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SiteStatus(site:Provider.of<CP>(context).getMapOfAllSites().values.toList().elementAt(position)))),
              child: SiteGridView(Provider.of<CP>(context).getMapOfAllSites().values.toList().elementAt(position)));
        },
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width>420? MediaQuery.of(context).size.width>550? 4 : 3 : 2),
      ),
    );
  }
}

//TODO - PROVIDE OPTION TO ORGANISE BY DATE