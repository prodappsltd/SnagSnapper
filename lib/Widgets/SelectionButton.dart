
import 'package:flutter/material.dart';

class SelectionBtn extends StatelessWidget {
  final String text;
  const SelectionBtn(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.symmetric(horizontal: 35.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.all(Radius.circular(10.0)),
          boxShadow: [
            BoxShadow(
              spreadRadius: 0.0,
              blurRadius: 2.0,
              color: Theme.of(context).colorScheme.shadow,
              offset: const Offset(0.0, 0.0),
            ),
          ],
      ),
      child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          )),
    );
  }
}
