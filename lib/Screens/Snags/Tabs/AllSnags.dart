
import 'package:flutter/material.dart';
import 'package:snagsnapper/Screens/Snags/create_snag_v2.dart';

class AllSnags extends StatelessWidget {
  final String siteID;
  final String siteOwnersEmail;
  final String siteOwnerUID;
  const AllSnags({
    super.key,
    required this.siteID,
    required this.siteOwnersEmail,
    required this.siteOwnerUID,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context)=> CreateSnagV2(
            snag: null,
            siteID: siteID,
            siteOwnersEmail: siteOwnersEmail,
            siteOwnerUID: siteOwnerUID,
          )));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, size: 50.0),
      ),
    );
  }
}
