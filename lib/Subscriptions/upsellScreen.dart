import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:snagsnapper/Helper/purchasesHelper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Constants/constants.dart';
import '../Data/contentProvider.dart';

class UpsellScreen extends StatefulWidget {
  const UpsellScreen({super.key});

  @override
  _UpsellScreenState createState() => _UpsellScreenState();
}

class _UpsellScreenState extends State<UpsellScreen> {
  bool busy = false;

  _launchURLWebsite(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  int selected = 1;

  @override
  Widget build(BuildContext context) {
    final Offerings offerings = Provider.of<CP>(context).getOfferings();
    final Map<String, Offering> offering = offerings.all;
    if (kDebugMode) print(offering);
    if (offering.isNotEmpty) {
      final Package? monthly = offering['SSMonthly']?.monthly;
      final Package? yearly = offering['SSYearly']?.annual;
      IntroductoryPrice? yIntroPrice = yearly?.storeProduct.introductoryPrice;
      IntroductoryPrice? mIntroPrice = monthly?.storeProduct.introductoryPrice;
      if (kDebugMode) print('----------------');
      if (kDebugMode) print(monthly);
      if (kDebugMode) print(yearly);
      if (monthly != null && yearly != null) {
        return Scaffold(
          // backgroundColor: Colors.grey[100],
            body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height / 3,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 25.0),
                  decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('images/inspections.jpg'), fit: BoxFit.cover)),
                ),
                Positioned(
                  right: 10.0,
                  bottom: 0.0,
                  child: FloatingActionButton.small(
                      onPressed: () => Navigator.pop(context),
                      backgroundColor: Colors.white,
                      shape: const CircleBorder(),
                      child: const Icon(
                        Icons.cancel,
                        size: 40.0,
                        color: Colors.grey,
                      )),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Text(
                        'Go Pro and unlock extra features!',
                        style: GoogleFonts.montserrat(textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Share your sites and collaborate with others',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.robotoCondensed(textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Control permissions to assigned sites',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.robotoCondensed(textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Enjoy cross platform sharing (iOS & Android)',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.robotoCondensed(textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Create customised PDF reports',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.robotoCondensed(textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Get firsthand access to new features',
                                    textAlign: TextAlign.start,
                                    style: GoogleFonts.robotoCondensed(textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => selected = 1),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        width: double.infinity,
                        height: 100.0,
                        decoration: BoxDecoration(
                            border: Border.all(width: 3.0, color: selected == 1 ? Theme.of(context).colorScheme.primary : Colors.grey),
                            borderRadius: const BorderRadius.all(Radius.circular(20.0))),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: selected == 1 ? Theme.of(context).colorScheme.primary : Colors.grey,
                                    size: 30.0,
                                  ),
                                  const SizedBox(
                                    width: 8.0,
                                  ),
                                  Text(
                                    'Monthly',
                                    style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(
                                'Monthly renewable subscription',
                                style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => selected = 2),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        width: double.infinity,
                        height: 100.0,
                        decoration: BoxDecoration(
                            border: Border.all(width: 3.0, color: selected == 2 ? Theme.of(context).colorScheme.primary : Colors.grey),
                            borderRadius: const BorderRadius.all(Radius.circular(20.0))),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: selected == 2 ? Theme.of(context).colorScheme.primary : Colors.grey,
                                    size: 30.0,
                                  ),
                                  const SizedBox(
                                    width: 8.0,
                                  ),
                                  Text(
                                    'Yearly',
                                    style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(
                                'Yearly renewable subscription',
                                style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            SafeArea(
              left: false,
              top: false,
              right: false,
              child: Column(
                children: <Widget>[
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                            });
                            try {
                              await PurchasesHelper.purchaseGivenPackage(selected==1? monthly:yearly);
                              if (await PurchasesHelper.isUserPro()) {
                                Provider.of<CP>(context, listen: false).setPro(true);
                                await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return const AlertDialog(
                                      title: Text('Success'),
                                      content: Text('Purchase successful'),
                                    );
                                  },
                                );
                              }
                            } on PlatformException catch (e) {
                              if (kDebugMode) print('=========');
                              if (kDebugMode) print(e);
                              var errorCode = PurchasesErrorHelper.getErrorCode(e);
                              if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
                                FirebaseCrashlytics.instance.recordError(e, e.stacktrace as StackTrace?);
                              }
                            } finally {
                              setState(() {
                                busy = false;
                              });
                              if (Provider.of<CP>(context, listen: false).getPro()) Navigator.pop(context);
                              if (Provider.of<CP>(context, listen: false).getPro()) Navigator.pop(context);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 8.0),
                      width: double.infinity,
                      // height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: const BorderRadius.all(Radius.circular(50.0)),
                      ),
                      child: Center(
                          child: busy
                              ? Text(
                                  'Please wait...',
                                  style: GoogleFonts.roboto(
                                      textStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary)),
                                )
                              : Column(
                                  children: [
                                    Text(
                                      selected == 1
                                          ? '${monthly.storeProduct.priceString} /month'
                                          : selected == 2
                                              ? '${yearly.storeProduct.priceString} /year'
                                              : 'Select Option',
                                      style: GoogleFonts.roboto(
                                          textStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary)),
                                    ),
                                    Text(
                                      selected == 1
                                          ? mIntroPrice==null
                                              ? 'Renews monthly'
                                              : '${mIntroPrice.periodNumberOfUnits} days FREE trial'
                                          : selected == 2
                                              ? yIntroPrice == null
                                                  ? 'Renews yearly'
                                                  : '${yIntroPrice.periodNumberOfUnits} days FREE trial'
                                              : 'Select Option',
                                      style: GoogleFonts.roboto(
                                          textStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.normal, color: Theme.of(context).colorScheme.onPrimary)),
                                    ),
                                  ],
                                )),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _launchURLWebsite('https://www.eelavan.co.uk/snagsnapper/privacy-policy');
                    },
                    child: Text(
                      'Privacy Policy',
                      style: kSendButtonTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _launchURLWebsite('https://www.eelavan.co.uk/snagsnapper/termsofuse-policy');
                    },
                    child: Text(
                      'Term of Use',
                      style: kSendButtonTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ));
      }
    }

    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Icon(
                  Icons.error,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  size: 44.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  "There was an error. Please check that your device is allowed to make purchases and try again. Please contact us at developer@productiveapps.co.uk if the problem persists.",
                  textAlign: TextAlign.center,
                  style: kSendButtonTextStyle,
                ),
              ),
            ],
          ),
        ));
  }
}
