// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../Data/contentProvider.dart';

const kColorPrimary = Color(0xff283149);
const kColorPrimaryLight = Color(0xff424B67);
const kColorPrimaryDark = Color(0xff21293E);
kWelcomeAlertStyle (BuildContext c) => AlertStyle(
  backgroundColor: Theme.of(c).colorScheme.tertiaryContainer,
  animationType: AnimationType.grow,
  isCloseButton: false,
  isOverlayTapDismiss: false,
  animationDuration: const Duration(milliseconds: 450),
  alertBorder: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10.0),
  ),
  titleStyle: TextStyle(
  color: Theme.of(c).colorScheme.onTertiaryContainer,
    fontWeight: FontWeight.bold,
    fontSize: 30.0,
    letterSpacing: 1.5,
  ),
);

TextStyle kSendButtonTextStyle = const TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 16,
);
////////////////////////////////

final Color? activeBTN = Colors.green[500];
const Color cameraColor = Color(0xFF615225);
const Color inactiveTabIcon = Colors.black;
const Color activePageIcon = Color(0xFFFFFFFF);
const Color greenCardView = Color(0x9992CD32);
const Color orangeCardView = Color(0x99FF8C00);
const Color redCardView = Color(0x99FF0000);

const errorDisplaytime = 3500;
const successDisplaytime = 3400;
const TITLE_BAR_HEIGHT = 40.0;
const TITLE_BAR_HEIGHT_WITH_OPTIONS = 105.0;

const String DATE_FORMAT = 'DATE_FORMAT';
const String NAME = 'NAME';
const String JOB_TITLE = 'JOB_TITLE';
const String TITLE = 'TITLE';
const String PRIORITY = 'PRIORITY';
const String DESCRIPTION = 'DESCRIPTION';
const String SNAG_FIX_DESCRIPTION = 'SNAG_FIX_DESCRIPTION';
const String COMPANY_NAME = 'COMPANY_NAME';
const String EMAIL = 'EMAIL';
const String PHONE = 'PHONE';
const String POSTCODE_AREA = 'POSTCODE_AREA';
const String COMPANY_IMAGE = 'COMPANY_IMAGE';
const String LIST_OF_COLLEAGUES = 'LIST_OF_COLLEAGUES';
const String LIST_OF_SITE_PATHS = 'LIST_OF_SITE_PATHS';

const String PICTURE_QUALITY = 'PICTURE_QUALITY';
const String DATE = 'DATE';
const String LOCATION = 'LOCATION';
const String IMAGE = 'IMAGE';
const String SIGNATURE = 'SIGNATURE';
const String IMAGE_MAIN1 = 'IMAGE_MAIN1';
const String IMAGE2 = 'IMAGE2';
const String IMAGE3 = 'IMAGE3';
const String IMAGE4 = 'IMAGE4';
const String SNAG_FIX_MAIN_IMAGE = 'IMAGE_FIX_MAIN_IMAGE';
const String SNAG_FIX_IMAGE_1 = 'SNAG_FIX_IMAGE_1';
const String SNAG_FIX_IMAGE_2 = 'SNAG_FIX_IMAGE_2';
const String SNAG_FIX_IMAGE_3 = 'SNAG_FIX_IMAGE_3';
const String SNAG_STATUS = 'SNAG_STATUS';
const String SNAG_CONFIRMED_STATUS = 'SNAG_CONFIRMED_STATUS';
const String OWNER_EMAIL = 'OWNER_EMAIL';
const String OWNER_NAME = 'OWNER_NAME';
const String ARCHIVE = 'ARCHIVE';
const String CREATOR_EMAIL = 'CREATOR_EMAIL';
const String ASSIGNED_EMAIL = 'ASSIGNED_EMAIL';
const String ASSIGNED_NAME = 'ASSIGNED_NAME';
const String UID = 'UID';
const String SITE_UID = 'SITE_UID';
const String DUE_DATE = 'DUE_DATE';
const String DATE_CREATED = 'DATE_CREATED';
const String SHARED_WITH = 'SHARED_WITH';
const int FRACTION = 4;

double getProportionalHeightForTopImage(BuildContext context, int fractionOfScreen) =>
    MediaQuery.of(context).size.height / fractionOfScreen;

var styleNormal = const TextStyle(
  fontWeight: FontWeight.w500,
  fontSize: 14.0,
  fontFamily: "Roboto-Regular.ttf",
  fontStyle: FontStyle.normal,
);

var styleBold = const TextStyle(
  fontWeight: FontWeight.w900,
  fontSize: 14.0,
  fontFamily: "Roboto-Regular.ttf",
  fontStyle: FontStyle.normal,
);

String getuID() {
  return Uuid().v4();
}

Future<String?> openGallery(BuildContext context1,  double maxImageSize) async {
  final picker = ImagePicker();
  var gallery = await picker.pickImage(
    source: ImageSource.gallery,
    maxHeight: maxImageSize,
    maxWidth: maxImageSize,
  );
  if (gallery != null) {
    var bytes = await gallery.readAsBytes();
    if (kDebugMode) print('Image bytes: ${bytes.length / 1024} KB');
    if (!context1.mounted) return null;
    Navigator.of(context1).pop(base64Encode(bytes));
  }
  return null;
}


Future<String?> openCamera(BuildContext context1, double maxImageSize) async {
  try {
    XFile? picture = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxHeight: maxImageSize,
      maxWidth: maxImageSize,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (!context1.mounted) return null;
    _dealWithSaving(picture, true, context1);
  }on PlatformException catch (e){
    await showDialog(context: context1, builder: (BuildContext context) {
      return AlertDialog(
        title: Icon(
          Icons.warning,
          size: 35,
          color: Theme.of(context1).colorScheme.error,
        ),
        content: Text("${e.message?? ''}\n\nPlease enable camera/storage/library permissions in settings", textAlign: TextAlign.center,),
      );
    });
    Navigator.pop(context1);
  }
}

_dealWithSaving(XFile? pic, bool saveExternally, BuildContext context) async {
  if (pic == null) return;
  String? completePath = await Provider.of<CP>(context, listen: false).saveNewPicture(pic, siteID: null, storeExternally: saveExternally, snagID: null);
  //if (completePath == null) await showFailureAlert();
  if (completePath == null) return;
  var temp = completePath;
  //setState(() => widget.profile.imageLogoPath = temp);
  //Navigator.pop(context);
}

Future<String?> optionsDialogBox(BuildContext context1, double maxImageSize) {
  //return optionsDialogBoxPretty(context1);
  return showDialog(
      context: context1,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: Theme.of(context1).colorScheme.primary, size: 40.0,),
                  title: const Text('OPEN CAMERA', style: TextStyle(fontSize: 16.0)),
                  onTap: () => openCamera(context1, maxImageSize),
                ),
                const Divider(height: 10.0,),
                ListTile(
                  leading: Icon(Icons.collections,color: Theme.of(context1).colorScheme.primary, size: 40.0,),
                  title: const Text('SELECT FROM GALLERY', style: TextStyle(fontSize: 16.0)),
                  onTap: () => openGallery(context1, maxImageSize),
                ),
              ],
            ),
          ),
        );
      });
}

Future<String?> optionsDialogBoxWithDEL(BuildContext context1, callBackDelete) {
  return showDialog(
      context: context1,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  dense: false,
                  leading: const Icon(Icons.camera_alt_outlined, color: Colors.deepOrange, size: 40.0,),
                  title: const Text('OPEN CAMERA', style: TextStyle(fontSize: 16.0)),
                  onTap: () => openCamera(context1, 1000),
                ),
                const Divider(height: 10.0,),
                ListTile(
                  dense: false,
                  leading: const Icon(Icons.collections,color: Colors.deepOrange, size: 40.0,),
                  title: const Text('SELECT FROM GALLERY', style: TextStyle(fontSize: 16.0)),
                  onTap: () => openGallery(context1, 1000),
                ),
                const Divider(height: 10.0,),
                ListTile(
                  dense: false,
                  leading: const Icon(Icons.delete_outline,color: Colors.deepOrange, size: 40.0,),
                  title: const Text('DELETE PIC', style: TextStyle(fontSize: 16.0)),
                  onTap: callBackDelete
                ),
              ],
            ),
          ),
        );
      });
}









Future<Uri?> createDynamicLinkForThisSite(String userUID, String? siteUID) async {
  if (siteUID == null || siteUID.isEmpty) return null;
  final DynamicLinkParameters parameters = DynamicLinkParameters(
    // Firebase assigned domain
    uriPrefix: 'https://snagsnapper.productiveapps.co.uk', // This should also be updated in Android Manifest.com under intent filters
    // Link the target app will try to open
    link: Uri.parse('https://snagsnapper.productiveapps.co.uk/?ownerID=$userUID&siteID=$siteUID'),
    androidParameters: AndroidParameters(
      // Link to open if app isn't installed!
      fallbackUrl: Uri.parse('https://play.google.com/store/apps/details?id=com.productiveapps.snagsnapper'),
      packageName: 'com.productiveapps.snagsnapper',
      minimumVersion: 1,
    ),
    iosParameters: IOSParameters(
      bundleId: 'com.productiveapps.snagsnapper',
      fallbackUrl: Uri.parse('https://play.google.com/store/apps/details?id=com.productiveapps.snagsnapper'),
      ipadFallbackUrl: Uri.parse('https://play.google.com/store/apps/details?id=com.productiveapps.snagsnapper'),
      ipadBundleId: 'com.productiveapps.snagsnapper',
      minimumVersion: '0',
      appStoreId: '6474559094',
    ),
    navigationInfoParameters: const NavigationInfoParameters(
      forcedRedirectEnabled: false,
    ),
    //dynamicLinkParametersOptions: DynamicLinkParametersOptions(
    // shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short,
    //),
  );
  var dynamicLinks = FirebaseDynamicLinks.instance;
  return (await dynamicLinks.buildShortLink(parameters)).shortUrl;
}

Future<Uri> createDynamicLinkForThisReport(String URL) async {
  final DynamicLinkParameters parameters = DynamicLinkParameters(
    uriPrefix: 'https://snagsnapper.productiveapps.co.uk',
    link: Uri.parse(URL),
    navigationInfoParameters: const NavigationInfoParameters(
      forcedRedirectEnabled: true,
    ),
//    dynamicLinkParametersOptions: DynamicLinkParametersOptions(
//      shortDynamicLinkPathLength: ShortDynamicLinkPathLength.short,
//    ),

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

  var link = (await FirebaseDynamicLinks.instance.buildShortLink(parameters)).shortUrl;
  if (kDebugMode) print('Complete Report link: $URL');
  return link;
}

String encryptText(String text) {
  final key = encrypt.Key.fromUtf8('SnagSnappers 32 bit length key t');
  final iv = encrypt.IV.fromLength(16);
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  encrypt.Encrypted encrypted = encrypter.encrypt(text, iv: iv);
  return encrypted.base64;
}

String decryptText(String text) {
  if (kDebugMode) print('Received to decrypt: $text');
  final key = encrypt.Key.fromUtf8('SnagSnappers 32 bit length key t');
  final iv = encrypt.IV.fromLength(16);
  final encrypter = encrypt.Encrypter(encrypt.AES(key));
  if (kDebugMode) print('Reached here...');
  final decrypted = encrypter.decrypt(Encrypted.fromBase64(text), iv: iv);
  if (kDebugMode) print('Reached here 2...');
  return decrypted;
}
