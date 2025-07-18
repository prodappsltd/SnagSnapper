

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Widgets/supportingSmallImagePlaceholders.dart';

class SmallImageSnags extends StatelessWidget {
  final String b64Image;
  final bool  showAnnotation;
  final VoidCallback callBackFunc;
  final VoidCallback callBackMarkupIcon;

  SmallImageSnags({super.key, required this.b64Image, required this.callBackFunc, required this.showAnnotation, required this.callBackMarkupIcon});

  @override
  Widget build(BuildContext context) {
    return                             Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        SmallImagePlaceholder(
            b64Image: b64Image,
            callBackFunction: callBackFunc
        ),
        showAnnotation
            ? Container(
            margin: const EdgeInsets.only(right: 0.0, bottom: 0.0),
            child: GestureDetector(
              onTap: callBackMarkupIcon,
              child: CircleAvatar(
                radius: 15.0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(
                  Icons.gesture,
                  color: Colors.white,
                  size: 25.0,
                ),
              ),
            ))
            : Container(),
      ],
    );
  }
}