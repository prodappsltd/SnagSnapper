

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';

class SmallImagePlaceholder extends StatelessWidget {
  final String b64Image;
  const SmallImagePlaceholder({super.key, required this.b64Image, required this.callBackFunction});
  final VoidCallback callBackFunction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80.0,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.all(Radius.circular(0.0))),
      child: ImageHelper(
        b64Image: b64Image,
        text: '',
        height: 80,
        iconSize: 35.0,
        callBackFunction: callBackFunction,
      ),
    );
  }
}

