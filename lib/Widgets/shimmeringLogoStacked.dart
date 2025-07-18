import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class ShimmeringLogoStacked extends StatelessWidget {
  const ShimmeringLogoStacked({
    required Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8.0),
      margin: EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
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
          SizedBox(
            height: 10.0,
          ),
          // Shimmer.fromColors(
          //   baseColor: Provider.of<UserData>(context).getSecondryColor(),
          //   highlightColor: Colors.white,
          //   period: Duration(seconds: 10),
          //   loop: 10,
          //   child: Text(
          //     'SNAG SNAPPER',
          //     style: TextStyle(
          //       fontSize: 40.0,
          //       fontWeight: FontWeight.w900,
          //       fontFamily: 'Roboto',
          //       shadows: [
          //         Shadow(
          //           blurRadius: 9.0,
          //           color: Colors.black54,
          //           offset: Offset(0.0, 2.0),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
