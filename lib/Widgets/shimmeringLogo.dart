import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class ShimmeringLogo extends StatelessWidget {
  const ShimmeringLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 100,
            width: 100,
            decoration: const BoxDecoration(
              image: DecorationImage(
                  image: AssetImage('images/1024LowPoly.png',),
                  fit: BoxFit.contain
              ),
              borderRadius: BorderRadius.all(Radius.circular(5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: Offset(0, 0), // changes position of shadow
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 10.0,
          ),
          // Flexible(
          //   child: Shimmer.fromColors(
          //     baseColor: Colors.white,
          //     highlightColor: Provider.of<UserData>(context).getOrangeColor(),
          //     period: const Duration(seconds: 3),
          //     loop: 5,
          //     child: const Text(
          //       'SNAG SNAPPER',
          //       style: TextStyle(
          //         fontSize: 40.0,
          //         fontWeight: FontWeight.w900,
          //         fontFamily: 'Roboto',
          //         shadows: [
          //           Shadow(
          //             blurRadius: 9.0,
          //             color: Colors.black54,
          //             offset: Offset(0.0, 2.0),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
