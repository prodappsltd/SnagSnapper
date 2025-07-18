import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/site.dart';

class SiteGridView extends StatelessWidget {
  final Site site;
  const SiteGridView(this.site, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.grey[500]!,
            offset: const Offset(0.0, 0.0),
            blurRadius: 5.0,
            spreadRadius: 0.0,
          )
        ],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(00.0), topRight: Radius.elliptical(50.0, 50.0)),
        image: DecorationImage(
            image: site.image.isNotEmpty ? MemoryImage(base64Decode(site.image)) : const AssetImage('images/1024LowPoly.png') as ImageProvider,
            fit: BoxFit.cover),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Provider.of<CP>(context).getMapOfSharedSites().containsKey(site.uID)
              ? CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(
                    Icons.group,
                    color: Colors.white,
                  ),
                )
              : const Text(''),
          kDebugMode
              ? Center(
                  child: Text(site.uID.substring(0,5)),
                )
              : const Text(''),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8.0),
                width: double.infinity,
                color: const Color(0xAAFFFFFF),
                child: Column(
                  children: <Widget>[
                    Text(
                      site.name,
                      style: GoogleFonts.montserrat(textStyle: const TextStyle(fontSize: 13 )),
                    ),
                    Text(
                      '${Provider.of<CP>(context).getListOfSnags(site.uID).length.toString()} snags',
                      style: const TextStyle(fontFamily: "Roboto-Bold.ttf"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
