
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Screens/Markup/markup.dart';

class ImagePainter extends CustomPainter {

  List<Offset> points;
  ui.Image image;

  ImagePainter (this.points, this.image);

  Paint brush = Paint()
    ..color=Colors.deepOrange
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 3.0;
  Paint brush2 = Paint()
    ..color=Colors.white
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 1.0;

  @override
  bool shouldRepaint(ImagePainter oldDelegate) => oldDelegate.points!=points;

  @override
  void paint(Canvas canvas, Size size) {
    printInformation(size, canvas);
//    if (image!=null) canvas.drawImage(image,Offset(offsetX,offsetY),brush);
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i]!=null && points[i+1]!=null) canvas.drawLine(points[i], points[i + 1], brush);
    }
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), brush2);
    canvas.drawLine(Offset(size.width,0.0), Offset(0.0, size.height), brush2);
    //canvas.drawCircle(Offset(canvasMiddleX, canvasMiddleY), 5.0, brush2);
  }

  void printInformation(Size size, Canvas canvas) async {

    if (image!=null) {
      canvasHeight = size.height; //global variables declared in markup
      canvasWidth = size.width;
      canvasMiddleX = size.width/2;
      canvasMiddleY = size.height/2;
      imageMiddleX = image.width/2;
      imageMiddleY = image.height/2;
      offsetX = canvasMiddleX-imageMiddleX;
      offsetY = canvasMiddleY-imageMiddleY;

      paintImage(image, Rect.fromLTRB(0.0,0.0,canvasWidth,canvasHeight), canvas, brush, BoxFit.fitHeight);

      if (kDebugMode) print('IMAGE W: ${image.width}');
      if (kDebugMode) print('IMAGE H: ${image.height}');
      if (kDebugMode) print('Width Canvas: ${size.width}');
      if (kDebugMode) print('Height Canvas: ${size.height}');
    }
  }

  void paintImage(ui.Image image, Rect outputRect, Canvas canvas, Paint paint, BoxFit fit) async {
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final FittedSizes sizes = applyBoxFit(fit, imageSize, outputRect.size);
    final Rect inputSubrect = Alignment.center.inscribe(sizes.source, Offset.zero & imageSize);
    final Rect outputSubrect = Alignment.center.inscribe(sizes.destination, outputRect);
    canvas.drawImageRect(image, inputSubrect, outputSubrect, paint);
  }


}

