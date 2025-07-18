
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class PDFReportFormat extends StatelessWidget {
  const PDFReportFormat({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: const Text(' Select format'),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        child: const Text('COMING SOON...'),
      ) ,
    );
  }
}
