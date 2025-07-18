import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Widgets/imagePainter.dart';

var canvasHeight;
var imageHeight;
var canvasWidth;
var imageWidth;
var canvasMiddleX;
var canvasMiddleY;
var imageMiddleX;
var imageMiddleY;
var offsetX;
var offsetY;

class Markup extends StatefulWidget {
  final String image;
  Markup(this.image);

  @override
  _MarkupState createState() => _MarkupState();
}

class _MarkupState extends State<Markup> {
  late ui.Image image;
  final points=<Offset>[];


  @override
  void initState() {
    super.initState();
    loadImage();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
          child: AppBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            title: const Text('ANNOTATE IMAGE'),
          ),
        ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onPanStart: (details)=> points.add(details.localPosition),
              onPanUpdate: (DragUpdateDetails details){
                setState(() => points.add(details.localPosition));
              },
              //onPanEnd: (_)=> points.add(null), // TODO - This was not commented before
              child: Container(
                child: ClipRect(
                  child: CustomPaint(
                    painter: ImagePainter(points, image),
                    size: Size.infinite,//(image.width.toDouble(), image.height.toDouble()),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Container(
                  margin: EdgeInsets.all(10.0),
                  height: 40.0,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [BoxShadow(
                          color: Colors.grey[500]!,
                          offset: const Offset(0.0,0.0),
                          blurRadius: 5.0,
                          spreadRadius:1.0
                      )]
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Icon(Icons.call_made, color: Colors.white,),
                      Icon(Icons.gesture, color: Colors.white,),
                      Icon(Icons.check_box_outline_blank, color: Colors.white,),
                      Icon(Icons.remove_circle_outline, color: Colors.white,),
                      Icon(Icons.timeline, color: Colors.white,),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(10.0,0.0,10.0,0.0),
                  height: 40.0,
                  color: Theme.of(context).colorScheme.primary,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Icon(Icons.arrow_drop_down_circle, color: Colors.white,),
                      Icon(Icons.menu, color: Colors.white,),
                      Icon(Icons.undo, color: Colors.white,),
                      Icon(Icons.threesixty, color: Colors.white,),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: ()  {

                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.all(Radius.circular(10.0))
                    ),
                    padding: const EdgeInsets.all(15.0),
                    margin: const EdgeInsets.only(left: 50.0, right: 50.0, top: 20.0, bottom: 0.0),
                    width: double.infinity,
                    child: const Center(
                        child: Text('SAVE',
                          style: TextStyle(
                              fontWeight:FontWeight.bold,
                              color: Colors.white,
                              fontSize: 20.0
                          ),
                        )
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> loadImage() async {
    var codec = await ui.instantiateImageCodec(base64.decode(widget.image));
    var fi = await codec.getNextFrame();
    setState(() {
      image = fi.image;
    });
  }

  setRenderedImage(BuildContext context) async {
//    ui.Image renderedImage = await signatureKey.currentState.rendered;

    setState(() {
//      image = renderedImage;
    });
//    var pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
  }


}
