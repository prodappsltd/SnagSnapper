import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class ShowFullScreenImage extends StatelessWidget {
  ShowFullScreenImage(this.b64Image, {super.key});
  final String b64Image;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
          child: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: const Text('IMAGE'),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.contain,
              image: MemoryImage(
                base64Decode(b64Image),
              ))),
        ));
  }
}
