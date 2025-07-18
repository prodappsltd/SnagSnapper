
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Constants/constants.dart';

/// Action Button class
class ActButton extends StatelessWidget {
  const ActButton({
    super.key,
    required this.busy,
    required this.text,
  });

  final bool busy;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
      width: double.infinity,
      child: Center(
          child: busy? SpinKitRipple(color: Theme.of(context).colorScheme.onPrimary,) : Text(
            text,
              style: GoogleFonts.roboto(textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary))
          )),
    );
  }
}