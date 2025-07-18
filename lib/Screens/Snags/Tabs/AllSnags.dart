
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/Snags/CreateEditSnag.dart';

class AllSnags extends StatelessWidget {
  final String siteID;
  final String siteOwnersEmail;
  AllSnags({super.key, required this.siteID, required this.siteOwnersEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context)=> CreateSnag(snag: null,siteID: siteID, siteOwnersEmail: siteOwnersEmail,)));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add,size: 50.0,),
      ),
    );
  }
}