
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class ReportCardView extends StatelessWidget {
  final String path;
  final File file;

  ReportCardView({required this.path}) : file = File(path);

  String _getDate() => file.path.split('/').last.split('_')[0];
  String _getTime() => file.path.split('/').last.split('_')[1];


  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top:8.0),
            child: Text(_getDate()),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom:8.0),
            child: Text(_getTime()),
          ),
          Divider(color: Theme.of(context).colorScheme.primary,thickness: 1.0,),
        ],
      ),
    );
  }
}