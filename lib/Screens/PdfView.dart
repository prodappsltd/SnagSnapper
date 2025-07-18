
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../Data/ArgsViewPDF.dart';
//

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});

  @override
  _PdfViewerState createState() => _PdfViewerState();
}


class _PdfViewerState extends State<PdfViewer> {

  @override
  Widget build(BuildContext context) {

    final ArgsVIEWPDF args =
    ModalRoute.of(context)!.settings.arguments as ArgsVIEWPDF;
    final String path = args.path;
    final String uID = args.siteUID;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('View Report'),
          elevation: 5.0,
          actions: <Widget>[
            Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    // return; // TODO - REMOVE IN PRODUCTION
                     Navigator.pushReplacementNamed(context, '/shareScreen', arguments: args);
                  },
                )),
          ],
        ),
      ),
      body: SfPdfViewer.file(File(path)),
    );
  }
}
