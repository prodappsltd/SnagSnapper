import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Widgets/ActionButton.dart';

import '../Data/ArgsViewPDF.dart';

/// A screen to get PhoneAuth and then upload the file and get the Dynamic link.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  _ShareScreenState createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String message = 'Checking if logged in already...';
  bool loggedIn = false;
  bool busy = false;
  bool uploadingFile = false;

  bool textSent = false;
  late String _verificationID;
  String errorMessage = '';

  get sharePos {
    final size = MediaQuery.of(context).size;
    return  Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final ArgsVIEWPDF args =
        ModalRoute.of(context)!.settings.arguments as ArgsVIEWPDF;
    final String path = args.path;
    final String uID = args.siteUID;

    return Scaffold(
      appBar: AppBar(
        //flexibleSpace: const TitleBarBackground(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Share Report'),
        elevation: 5.0,
      ),
      body: SafeArea(
          child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Card(
              margin: const EdgeInsets.all(8.0),
              child: LoggedInView(
                          phoneNumber: FirebaseAuth.instance.currentUser!.email!,
                          busy: uploadingFile,
                          path: path,
                          uID: uID,
                        ),
            ),
            Divider(
              thickness: 1.0,
              color: Theme.of(context).colorScheme.primary,
            ),
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (Platform.isAndroid) {
                        final MailOptions mailOptions = MailOptions(
                          body:
                          'Hi, Please find the report attached to this email. <br>Kind Regards',
                          subject: 'Report attached',
                          recipients: [],
                          isHTML: true,
                          bccRecipients: [],
                          ccRecipients: [],
                          attachments: [path],
                        );
                        await FlutterMailer.send(mailOptions);
                      } else {
                        try{
                          await Share.shareXFiles(
                            [XFile(path)],
                            sharePositionOrigin: sharePos,
                            subject: 'Report attached',
                            text: 'Please find the report I created.',
                          );
                        } catch (e){
                          print (e);
                        }
                      }
                    },
                    child: const ActButton(busy: false, text: 'Quick share',),
                  ),

                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Directly share the file from available options on your phone.',
                      textAlign: TextAlign.center,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class LoggedInView extends StatefulWidget {
  const LoggedInView({
    required this.phoneNumber,
    required this.busy,
    required this.path,
    required this.uID,
  });

  final String phoneNumber;
  final bool busy;
  final String path;
  final String uID;

  @override
  _LoggedInViewState createState() => _LoggedInViewState();
}

class _LoggedInViewState extends State<LoggedInView> {
  String message = 'Suitable for bigger files';
  bool busy = false;
  Uri? uri;
  bool showSpinner = false;
  bool uploadingDone = false;

  @override
  void initState() {
    super.initState();
    busy = widget.busy;
    showSpinner = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Logged in:',
            style: TextStyle(
                fontSize: 30.0, fontWeight: FontWeight.bold, fontFamily: ''),
          ),
          const SizedBox(
            height: 8.0,
          ),
          Text(widget.phoneNumber),
          const SizedBox(
            height: 8.0,
          ),
          BusyContainer(message, showSpinner),
          GestureDetector(
            onTap: () async {
              setState(() {
                showSpinner = true;
                busy = true;
              });
              if (!uploadingDone) await _getLink();
              setState(() {
                showSpinner = false;
                busy = false;
              });
              uploadingDone = true;
              Share.share(
                'Hi, please click on the link below to view the PDF report I have created.\n\n$uri \n\nThanks\n${Provider.of<CP>(context, listen: false).getAppUser()!.name}',
                subject: 'View PDF report link',
                sharePositionOrigin: Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height / 2),
              );
            },
            child: ActButton(
              busy: busy,
              text: 'Share link',
            ),
          ),
          const Text(
            'Upload file to a secure google provided storage and share the link.',
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  _getLink() async {
    setState(() {
      message = "Uploading to Google storage...";
    });
    if (kDebugMode) print('PDF CLICKED...');
    firebase_storage.FirebaseStorage storage =
        firebase_storage.FirebaseStorage.instance;

    firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child(widget.uID)
        .child(widget.uID);

    try {
      await storage
          .ref('${widget.uID}/${widget.uID}')
          .putFile(File(widget.path));
      setState(() => message = 'Upload complete!');

    } on firebase_core.FirebaseException catch (e) {
      // e.g, e.code == 'canceled'
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('Error'),
                content: const Text('Error uploading file. Please try again!'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ));
    }

    String URL = await firebase_storage.FirebaseStorage.instance
        .ref('${widget.uID}/${widget.uID}')
        .getDownloadURL();
    uri = await getDynamicLink(URL);
    if (kDebugMode) print('Short link: $uri');
  }

  Future getDynamicLink(String URL) async {
    return (await createDynamicLinkForThisReport(URL));
  }

  Future<Uri?> createDynamicLinkForThisReport(String URL) async {
    late Uri link;
    try {
      final DynamicLinkParameters parameters = DynamicLinkParameters(
        uriPrefix:
            'https://snagsnapper.web.app', //'https://eelavan.co.uk/auditrReport',
        link: Uri.parse(URL),
        navigationInfoParameters: const NavigationInfoParameters(
          forcedRedirectEnabled: true,
        ),
        // Below three lines are obsolete
        // dynamicLinkParametersOptions: DynamicLinkParametersOptions(
        //   shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short,
        // ),

//      googleAnalyticsParameters: GoogleAnalyticsParameters(
//        campaign: 'example-promo',
//        medium: 'social',
//        source: 'orkut',
//      ),
//      itunesConnectAnalyticsParameters: ItunesConnectAnalyticsParameters(
//        providerToken: '123456',
//        campaignToken: 'example-promo',
//      ),
//      socialMetaTagParameters:  SocialMetaTagParameters(
//        title: 'Example of a Dynamic Link',
//        description: 'This link works whether app is installed or not!',
//      ),
      );
      link = (await FirebaseDynamicLinks.instance.buildShortLink(parameters))
          .shortUrl;
    } on PlatformException catch (e) {
      setState(() {
        message = e.message!;
      });
    }
    if (kDebugMode) print('Complete Report link: $URL');
    return link;
  }
}

class BusyContainer extends StatelessWidget {
  final String message;
  final bool showSpinner;
  const BusyContainer(this.message, this.showSpinner, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.all(8.0),
      width: double.infinity,
      decoration: BoxDecoration(
          border: Border.all(
              color: Theme.of(context).colorScheme.primary),
//        color: Provider.of<UserData>(context).getMainColor
//       (),
          borderRadius: const BorderRadius.all(
            Radius.circular(8.0),
          )),
      child: Column(
        children: <Widget>[
          Visibility(
              visible: (showSpinner),
              child: SpinKitDualRing(
                size: 40.0,
                color: Theme.of(context).colorScheme.primary,
              )),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      ),
    );
  }
}
