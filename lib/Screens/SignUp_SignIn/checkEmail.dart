

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                height: 150.0,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 100.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(20.0))

                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          SvgPicture.asset(
                              'images/mail-send.svg',
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                              height: 50,
                              semanticsLabel: 'Mail sent'
                          ),
                          const SizedBox(height: 50.0,),
                          Text('Check in your mail!', style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiaryContainer),),
                          const SizedBox(height: 25.0,),
                          Text('We\'ve just emailed you with the instructions', style: TextStyle(fontSize: 15.0, color: Theme.of(context).colorScheme.onTertiaryContainer),),
                          Text('to reset your password', style: TextStyle(fontSize: 15.0, color: Theme.of(context).colorScheme.onTertiaryContainer),),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic>route) => false),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: const BorderRadius.all(Radius.circular(20.0))

                        ),
                        padding: const EdgeInsets.all(20.0),
                        margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
                        width: double.infinity,
                        child: Center(child: Text('BACK TO LOGIN', style: TextStyle(fontWeight:FontWeight.bold,color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),)),
                      ),
                    ),
                    const SizedBox(height: 10.0,)
                  ],
                ),
              ),
            ),
            Column(
            children: <Widget>[
              Text('For any questions or issues', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              Text('please contact us at', style: TextStyle(color: Theme.of(context).colorScheme.primary),),
              Padding(
                padding: const EdgeInsets.only(bottom:8.0),
                child: Text('developer@productiveapps.co.uk',textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 16),),
              ),

            ],
            )
          ],
        ),
      ),
    );
  }
}