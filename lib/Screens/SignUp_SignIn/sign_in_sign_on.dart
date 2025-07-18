
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Widgets/SelectionButton.dart';

import '../../Data/contentProvider.dart';

class SignInSignOnScreen extends StatelessWidget {
  final bool showButtons = true;

  const SignInSignOnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    height: 150,
                    width: 150,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('images/1024LowPoly.png',),
                        fit: BoxFit.contain
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                  ),
                  const SizedBox(
                    width: 10.0,
                  ),
                  Text('Snag Snapper', style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Theme.of(context).colorScheme.primary),),
                  Text('Your ultimate snagging app', style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Theme.of(context).colorScheme.primary),)
                ],
              ),
            ),
            const SizedBox(
              height: 50.0,
            ),
            showButtons
                ? GestureDetector(
                onTap: () => Navigator.pushNamed(context,'/signIn'),
                child: const SelectionBtn('LOGIN'))
                : const Text(''),
            const SizedBox(
              height: 30.0,
            ),
            showButtons
                ? GestureDetector(
                onTap: () => Navigator.pushNamed(context,'/signUp').then((value){
                  Provider.of<CP>(context, listen: false).setAppUser(null);
                }),
                child: const SelectionBtn('SIGN-UP'))
                : const Text(''),
            const SizedBox(height: 80,),
            GestureDetector(
                onTap: () => Provider.of<CP>(context, listen: false).changeBrightness(Theme.of(context).brightness==Brightness.light? Brightness.dark: Brightness.light),
                child: ThemeSelector(Theme.of(context).brightness==Brightness.light? 'dark' : 'light')
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSelector extends StatelessWidget{
  const ThemeSelector(this.theme,{super.key});
  final String theme;
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) print (theme);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 3, color: Theme.of(context).colorScheme.primary),
        //borderRadius: const BorderRadius.all(Radius.circular(20)),
        shape: BoxShape.circle
      ),
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Icon(theme=='dark'? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).colorScheme.primary, size: 30,)
    );
  }

}