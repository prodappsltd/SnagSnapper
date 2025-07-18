import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class GetSignature extends StatefulWidget {
  const GetSignature({super.key});


  @override
  _SignatureState createState() => _SignatureState();
}

class _SignatureState extends State<GetSignature> {
  //List<Offset> _points = <Offset>[];

  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[800],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          title: const Text('Add Signature'),
          //backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          //SIGNATURE CANVAS
          Signature(
            //SIGNATURE CANVAS
              controller: _controller,
              height: 300,
              backgroundColor: Colors.white,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              GestureDetector( // SAVE BUTTON
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 20.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25.0, vertical: 25.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius:
                    const BorderRadius.all(Radius.circular(10.0)),
                    //gradient: GRADIENTDISABLED,
                  ),
                  child: Center(
                      child: Text(
                        'SAVE',
                        style: TextStyle(
                            fontSize: 20.0, color: Theme.of(context).colorScheme.onPrimary),
                      )),
                ),
                onTap: () async {
                  Uint8List? _image = await _controller.toPngBytes();
                  Navigator.pop(context,_image?? '');
                },
              ),
              GestureDetector( //CLEAR BUTTON
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 10.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25.0, vertical: 25.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius:
                    const BorderRadius.all(Radius.circular(10.0)),
                    //gradient: GRADIENTDISABLED,
                  ),
                  child: Center(
                      child: Text(
                        'CLEAR',
                        style: TextStyle(
                            fontSize: 20.0, color: Theme.of(context).colorScheme.onPrimary),
                      )),
                ),
                onTap: () {
                  setState(() {
                    setState(() => _controller.clear());
                  });
                },
              )
            ],
          )
        ],
      ),
    );
  }
}


class SignaturePainter extends CustomPainter {
  SignaturePainter(this.points);

  final List<Offset> points;

  void paint(Canvas canvas, Size size) {
//    canvas.clipRect(Offset.zero & size);
    Paint paint = new Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  bool shouldRepaint(SignaturePainter other) => other.points != points;
}
