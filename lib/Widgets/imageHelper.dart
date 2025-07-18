import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:snagsnapper/Constants/constants.dart';

class ImageHelper extends StatelessWidget {
  final String b64Image;
  final VoidCallback callBackFunction;
  final String text;
  final double height;
  final double iconSize;

  const ImageHelper({super.key, this.iconSize=50.0, required this.b64Image, required this.callBackFunction, this.height = 100.0, this.text = 'Click to add\nyour company logo'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: callBackFunction,
      child: Container(
        height: height,
//        margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        //width: double.infinity,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.tertiaryContainer,
        ),
        child: b64Image.isNotEmpty
            ? Image.memory(base64Decode(b64Image.toString()),fit: BoxFit.cover,)
            : Column( mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.camera_alt,size: iconSize,color: Theme.of(context).colorScheme.onTertiaryContainer,),
                  Text(text,textAlign: TextAlign.center , style: Theme.of(context).textTheme.labelMedium!.copyWith(color:Theme.of(context).colorScheme.onTertiaryContainer),),
          ],
        ),
      ),
    );
  }
}