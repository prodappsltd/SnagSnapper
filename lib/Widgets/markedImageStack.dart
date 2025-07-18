

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Screens/showFullScreenImage.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';

class MarkImageStack extends StatelessWidget {
  const MarkImageStack(this.b64Image, this.callBackImageFunction, this.callBackMarkedImageFunction, this.showAnnotation,
      this.textPlaceholder, {super.key});
  final String b64Image;
  final VoidCallback callBackImageFunction;
  final Function callBackMarkedImageFunction;
  final bool showAnnotation;
  final String textPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        ImageHelper(
            b64Image: b64Image,
            height: getProportionalHeightForTopImage(context, FRACTION),
            text: textPlaceholder,
            callBackFunction: callBackImageFunction),
            showAnnotation
            ? Container(
            margin: const EdgeInsets.only(right: 10.0, bottom: 10.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                    context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(b64Image)));

//                Navigator.push(context, MaterialPageRoute(builder: (context) => Markup(b64Image)))
//                    .then((onValue) => callBackMarkedImageFunction);
              },
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(
                  Icons.gesture,
                  color: Colors.white,
                ),
              ),
            ))
            : Container(),
      ],
    );
  }
}
