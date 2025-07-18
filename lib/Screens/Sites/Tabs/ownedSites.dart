

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteInfo.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteStatus.dart';
import 'package:snagsnapper/Widgets/siteGridView.dart';


class OwnedSites extends StatelessWidget {
  const OwnedSites({super.key});

  showProUserAlert(context){
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
              style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer), // TODO - Try something else, description too bold
              // style: kSendButtonTextStyle,
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
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary),
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
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      ],
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    bool isPro = Provider.of<CP>(context).getPro();
    return Scaffold(
      floatingActionButton: Container(
        margin: const EdgeInsets.only(right: 10.0, bottom: 10.0),
        child:SizedBox(
          height: 60.0,
          width: 60.0,
          child: FittedBox(
            child:FloatingActionButton(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(100),
                      bottomLeft: Radius.circular(100),
                      bottomRight: Radius.circular(100),
                      topLeft: Radius.circular(20))
              ),
              backgroundColor: isPro? Theme.of(context).colorScheme.primary: Colors.grey[500],
              onPressed: ()=> isPro
                  ? Navigator.push(context, MaterialPageRoute(builder: (context)=>const SiteInfo(null)))
                  .then((value) {
                    if (value!=null) Navigator.push(context, MaterialPageRoute(builder: (context)=>SiteStatus(site:value)));
                  })
                  : showProUserAlert(context),
              child: Icon(isPro? Icons.add: Icons.lock,size: 40.0, color: isPro? activePageIcon: Colors.white,),
            ),
          ),
        ),
      ),
      body: GridView.builder(
        itemCount: Provider.of<CP>(context).getMapOfOwnedSites().length,
        scrollDirection: Axis.vertical,
        itemBuilder: (context,position){
          return GestureDetector(
            onLongPress: (){ },//TODO - DELETE SITE,
              onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (context)=>SiteStatus(
                  site:Provider.of<CP>(context).getMapOfOwnedSites().values.elementAt(position)
              ))),
              child: SiteGridView(Provider.of<CP>(context).getMapOfOwnedSites().values.elementAt(position)));
        },
        gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width>420? MediaQuery.of(context).size.width>550? 4 : 3 : 2),
      ),
    );
  }
}