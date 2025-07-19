import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // Removed outdated package
import 'package:image_picker/image_picker.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/site.dart';
import 'package:snagsnapper/Data/snag.dart';
import 'package:snagsnapper/Data/user.dart';
import 'package:path/path.dart' as p;
import 'package:snagsnapper/Helper/purchasesHelper.dart';

class CP extends ChangeNotifier {
  bool _isPro = false;
  bool _isProSiteSharing = false;
  late Offerings _offerings;
  AppUser? _appUser;
  final Map<String, Site> _allSites = {}; //SiteUID, Site
  /// Map <String SiteID, Site site>
  final Map<String, Site> _ownedSites = {}; //SiteUID, Site
  final Map<String, Site> _sharedSites = {}; //SiteUID, Site
  final Map<String, String> _sharedSitedata = {}; //SiteUID, Site
  final Map<String, Map<String, Snag>> _snags = {}; //SiteUID > Map<SnagUID, Snag>

  /// More than 5 days left, show it as green
  int greenCondition = 5;

  /// More than 2, less than 5 days left, show it as orange
  int orangeCondition = 2;

  /// No days left, overdue
  int redCondition = 0;

  /// Checks internet connection
  bool hasInternet = false;
  bool _internetCheckInProgress = false;
  late Timer _timer;

  Color seedColour = const Color(0xFFFE5000);
  Brightness brightness = Brightness.dark;
  Color _pdfColor = const Color(0xFF607D8B);
  // Color _secondryBackgroundColor = const Color(0xFF607D8B);

  CP() {
    _getColors();
    _getTheme();
    getNetworkStatus();
  }

  changeBrightness(Brightness b){
    brightness = b;
    _setTheme(b==Brightness.light? 'light' : 'dark');
    notifyListeners();
  }

  changeSeed(Color c) async {
    seedColour = c;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('seed', _colorToString(c));
    notifyListeners();
  }

  setPro(bool proValue) {
    _isPro = proValue;
    notifyListeners();
  }

  setProSiteSharing(bool proValue) {
    _isProSiteSharing = proValue;
    notifyListeners();
  }

  getPro() => _isPro;
  getProSiteSharing() => _isProSiteSharing;
  getOfferings() => _offerings;

  /// Loads the saved colors by the user and use it in the app
  /// Defaults are loaded before, if nothing is saved then default options stay
  _getColors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pdfResult = prefs.getString('pdfColor');
    String? seedColour = prefs.getString('seed');
    if (pdfResult != null) _pdfColor = _colorFromHex(pdfResult);
    if (seedColour != null) changeSeed(_colorFromHex(seedColour));
  }

  _getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? theme = prefs.getString('theme');
    if (theme != null) brightness = theme=='light'? Brightness.light : Brightness.dark;
  }
  _setTheme(String theme) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
  }

  void setPDFColor(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool mainResult = await prefs.setString('pdfColor', _colorToString(color));
    _pdfColor = color;
    notifyListeners();
  }

  // Color getMainColor(){
  //   return _mainBackgroundColor;
  // }

  Color getPDFColor() => _pdfColor;

  Color _colorFromHex(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    return Color(int.parse('$hexCode', radix: 16));
  }

  String _colorToString(Color color) {
    if (kDebugMode) print('#${color.value.toRadixString(16)}');
    return '#${color.value.toRadixString(16)}';
  }

  bool isOwner(String email) => _appUser!.email.toLowerCase() == email.toLowerCase();

  _informNoNetwork() async {
    if (kDebugMode) print('DATA-F_INN: Inform no network');
    if (!_internetCheckInProgress) {
      if (kDebugMode) print('DATA_INN: Informed of no network');
      _internetCheckInProgress = true;
      hasInternet = false;
      _timer = Timer.periodic(Duration(seconds: 3), (time) async {
        //if (kDebugMode) print ('DATA_INN: Pinging to see Internet...');
        hasInternet = await InternetConnectionChecker.instance.hasConnection;
        if (hasInternet) {
          if (kDebugMode) print('DATA_INN: We have Internet...');
          _timer.cancel();
          hasInternet = true;
          _internetCheckInProgress = false;
          notifyListeners();
        }
      });
    }
    if (kDebugMode) print('DATA-L_INN: END');
  }

  /// Checks for the network status by calling DataConnection class
  /// [hasInternet] get updated as true, if internet is there else false
  /// Not just wifi/4G etc check, it is actual data transmission test
  getNetworkStatus() async {
    if (kDebugMode) print('DATA-F_GNS: Getting Network Status');
    hasInternet = await InternetConnectionChecker.instance.hasConnection;
    //notifyListeners();
    if (!hasInternet) _informNoNetwork();
    if (kDebugMode) print('DATA-L_GNS: Got Internet?: $hasInternet');
    return hasInternet;
  }

  Future<bool> storeSharedSite(String UID, String siteID) async {
    if (kDebugMode) print('DATA-F_SSS: Store shared site ');
    _sharedSitedata[siteID] = UID;
    if (kDebugMode) print('DATA-L-SSS: END ');
    return await downloadSite(UID, siteID);
  }

  Future<bool> downloadSite(String ownerUID, String siteID) async {
    if (kDebugMode) print('DATA-F_DS: Download Site');
    bool result = false;
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('Profile/$ownerUID/Sites').doc(siteID).get();
      // .onError((error, stackTrace) => null)
      // .catchError((error){
      //   if (kDebugMode) print('DATA_DS: --Site CANNOT be downloaded-- $error');
      //   return Future.value(result);
      // });
      if (snapshot.exists) {
        if (kDebugMode) print('DATA_DS: Received snapshot of site ');
        Site site = Site.fromJson(snapshot.data()!);
        if (site.ownerEmail.toString().toLowerCase() == _appUser!.email.toLowerCase()) {
          if (kDebugMode) print('DATA-L_DS: Returning from DS User == Owner');
          return false;
        }
        result = true;
        updateSiteLocalVariables(site);
        if (kDebugMode) print('DATA_DS: Adding this site to \'Profile\' under LIST_OF_SITE_PATHS ');
        FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid).set({
          LIST_OF_SITE_PATHS: {siteID: ownerUID}
        }, SetOptions(merge: true));
        if (kDebugMode) print('DATA_DS: Site can be downloaded - User is Allowed');
      } else {
        if (kDebugMode) print('DATA_DS : Site received was NULL ');
      }
    } on Exception catch (e) {
      // TODO - Show Error to user
      result = false;
      if (kDebugMode) print('DATA_DS: --Site CANNOT be downloaded-- ${e}');
    }
    if (kDebugMode) print('DATA-L_DS: END ');
    return result;
  }

  /// App user is not null at this stage
  Future loadOnlySharedSites() async {
    //throw PlatformException(code: 'Test Error');
    if (kDebugMode) print('DATA-F_LSS: Load Shared Sites ');
    if (_appUser!.mapOfSitePaths == null || _appUser!.mapOfSitePaths!.isEmpty) {
      if (kDebugMode) print('DATA-L_LSS: No Shared sites found for the user ');
      return;
    }
    Map<String, String> listOfSharedPathsCopy = Map.from(_appUser!.mapOfSitePaths as Map<String, String>);
    if (kDebugMode) print('DATA_LSS: Loading SHARED Sites........');
    for (int i = 0; i < _appUser!.mapOfSitePaths!.length; i++) {
      if (kDebugMode) print('*');
      String siteID = _appUser!.mapOfSitePaths!.keys.elementAt(i);
      String ownerID = _appUser!.mapOfSitePaths!.values.elementAt(i);
      try {
        if (kDebugMode) print('DATA_LSS: OwnerID - $ownerID');
        if (kDebugMode) print('DATA_LSS: SiteID - $siteID');
        DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('Profile/$ownerID/Sites').doc(siteID).get();
        if (snapshot.exists) updateSiteLocalVariables(Site.fromJson(snapshot.data()!));
      } catch (error) {
        if (kDebugMode) print('DATA_LSS: Error downloading site - Details: ${error} ');
        if (kDebugMode) print('DATA_LSS: Removing this site from List of shared sites ');

        /// If site could not be found or cannot be downloaded because may be this persons email is removed by the site owner
        /// remove this from the shared site list
        listOfSharedPathsCopy.remove(siteID);
      } finally {
        if (listOfSharedPathsCopy.length != _appUser!.mapOfSitePaths!.length) {
          if (kDebugMode) print('DATA_LSS: Need to update user account with Shared Sites List ');
          await _updateSharedSitesList(listOfSharedPathsCopy);
        }
      }
    }
    notifyListeners();
    if (kDebugMode) print('DATA_USLV: Notified Listeners ');
    if (kDebugMode) print('DATA-L_LSS: END - SHARED Sites Loaded..');
  }

  /// If
  Future<bool> _updateSharedSitesList(listOfSharedPathCopy) async {
    if (kDebugMode) print('DATA-F_USSL: Update Shared Sites List');
    bool result = false;
    //-- FIREBASE UPDATE START--
    final DocumentReference postRef = FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid);
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(postRef);
      if (postSnapshot.exists) {
        try {
          if (kDebugMode) print('DATA_USSL: Updating on FIREBASE - shared paths list...');
          tx.update(postRef, {LIST_OF_SITE_PATHS: listOfSharedPathCopy});
          result = true;
        } on PlatformException catch (e) {
          if (kDebugMode) print('DATA_USSL: Error Message: ' + e.details);
        }
      }
    });
    //--FIREBASE UPDATE FINISH--
    if (kDebugMode) print('DATA-L_USSL: END - Update Successful - $result');
    return result;
  }

  Future<bool> updateProfile(
      String _name, String _jobTitle, String _companyName, String _postCode, String _phone, String _email, String _dateFormat, String _signature) async {
    if (kDebugMode) print('DATA-F_UP: Update Profile');
    bool result = false;
    //-- FIREBASE UPDATE START--
    /// WHY DOES THIS NEED TO BE IN A TRANSACTION
    final DocumentReference postRef = FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid);
    await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
      DocumentSnapshot postSnapshot = await tx.get(postRef);
      if (postSnapshot.exists) {
        try {
          if (kDebugMode) print('DATA_UP: Updating Profile on FIREBASE...');
          tx.update(postRef, {'Ignore': 1}); // Without this if nothing is getting updated then Exception happens. MUST do a write// TODO CHECK THIS, NOT MAKING SENSE
          if (_appUser!.name != _name && _name.isNotEmpty) tx.update(postRef, {NAME: _name});
          if (_appUser!.signature != _signature && _signature.isNotEmpty) tx.update(postRef, {SIGNATURE: _signature});
          if (_appUser!.jobTitle != _jobTitle && _jobTitle.isNotEmpty) tx.update(postRef, {JOB_TITLE: _jobTitle});
          if (_appUser!.companyName != _companyName && _companyName.isNotEmpty) tx.update(postRef, {COMPANY_NAME: _companyName});
          if (_appUser!.postcodeOrArea != _postCode && _postCode.isNotEmpty) tx.update(postRef, {POSTCODE_AREA: _postCode});
          if (_appUser!.phone != _phone && _phone.isNotEmpty) tx.update(postRef, {PHONE: _phone});
          if (_appUser!.email != _email && _email.isNotEmpty) tx.update(postRef, {EMAIL: _email});
          if (_appUser!.dateFormat != _dateFormat && _dateFormat.isNotEmpty) tx.update(postRef, {DATE_FORMAT: _dateFormat})

          ;
          if (_appUser!.name != _name && _name.isNotEmpty) _appUser!.name = _name;
          if (_appUser!.signature != _signature && _signature.isNotEmpty) _appUser!.signature = _signature;
          if (_appUser!.jobTitle != _jobTitle && _jobTitle.isNotEmpty) _appUser!.jobTitle = _jobTitle;
          if (_appUser!.companyName != _companyName && _companyName.isNotEmpty) _appUser!.companyName = _companyName;
          if (_appUser!.postcodeOrArea != _postCode && _postCode.isNotEmpty) _appUser!.postcodeOrArea = _postCode;
          if (_appUser!.phone != _phone && _phone.isNotEmpty) _appUser!.phone = _phone;
          if (_appUser!.email != _email && _email.isNotEmpty) _appUser!.email = _email;
          if (_appUser!.dateFormat != _dateFormat && _dateFormat.isNotEmpty) _appUser!.dateFormat = _dateFormat;
          result = true;
        } on PlatformException catch (e) {
          if (kDebugMode) print('DATA_UP: Error Updating Profile: ${e.message!}');
        }
      }
    });
    //--FIREBASE UPDATE FINISH--
    if (kDebugMode) print('DATA-L_UP: END Profile Updated: $result');
    return result;
  }

  void changeDateFormat(bool british) {
    if (kDebugMode) print('DATA-F_CDF: Change Date Format');
    if (british) _appUser!.dateFormat = 'dd-MM-yyyy';
    if (!british) _appUser!.dateFormat = 'MM-dd-yyyy';
    if (kDebugMode) print('DATA_CDF: Notifying Listeners');
    notifyListeners();
    if (kDebugMode) print('DATA-L_CDF: END Final format:${_appUser!.dateFormat}');
  }

  void resetVariables() async {
    if (kDebugMode) print('DATA-F_RV: Reset Variables');
    await FirebaseAuth.instance.signOut();
    assert(FirebaseAuth.instance.currentUser == null);
    _appUser = null;
    _allSites.clear();
    _ownedSites.clear();
    _sharedSites.clear();
    _sharedSitedata.clear();
    _snags.clear();
    if (kDebugMode) print('DATA-L_RV: END');
  }

  String getDateFormat() {
    if (kDebugMode) print('DATA-F-L_GDF: Get Date Format');
    return _appUser!.dateFormat;
  }

  Future<bool> addSite(Site site) async {
    if (kDebugMode) print('DATA-F_AS: Add Site...');
    bool result = false;
    //-- FIREBASE UPDATE START--
    try {
      await FirebaseFirestore.instance.collection('Profile/${FirebaseAuth.instance.currentUser!.uid}/Sites').doc(site.uID).set(site.toJson()).then((onValue) {
        if (kDebugMode) print('DATA_AS: Site Added');
        updateSiteLocalVariables(site);
        result = true;
      }); //Update firebase first
    } on PlatformException catch (e) {
      if (kDebugMode) print('DATA_AS: Error Adding Site details : ${e.details}');
      result = false;
    }
    if (kDebugMode) print('DATA-L_AS: END Site added: $result');
    return result;
  }

  updateSiteLocalVariables(site) {
    if (kDebugMode) print('DATA-F_USLV: Update site Local Variables');
    _allSites[site.uID] = site;
    if (kDebugMode) print('DATA_USLV: Site added to all sites ');
    if (site.ownerEmail == FirebaseAuth.instance.currentUser!.email) {
      _ownedSites[site.uID] = site;
      if (kDebugMode) print('DATA_USLV: Site added to OWNED sites ');
    } else {
      _sharedSites[site.uID] = site;
      if (kDebugMode) print('DATA_USLV: Site added to SHARED sites');
    }
    _snags.putIfAbsent(site.uID, () => {});
    if (kDebugMode) print('DATA_USLV: END Updating Local Variables');
    notifyListeners();
  }

  Future updateSite(Site site) async {
    if (kDebugMode) print('DATA-F_US: Update Site...');
    await addSite(site);
    if (kDebugMode) print('DATA-L_US: END Update Site');
  }

  /// At this stage Firebase user is confirmed != null
  Future loadOwnedSites() async {
    if (kDebugMode) print('DATA-F_LS: Load Sites.....');
     //throw PlatformException(code: 'Test Error');
     QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('Profile/${FirebaseAuth.instance.currentUser!.uid}/Sites')
        .where('ARCHIVE', isEqualTo: false)
        .orderBy('DATE', descending: true)
        .get();
    if (kDebugMode) print("Querysnapshot length :: ${snapshot.size}");
    if (snapshot.size > 0) {
      for (var snap in snapshot.docs) {
        Site site = Site.fromJson(snap.data() as Map<String, dynamic>);
        updateSiteLocalVariables(site);
      }
      if (kDebugMode) print('DATA_LS: ${snapshot.docs.length} Sites Received');
    }
    if (kDebugMode) print('DATA_LS: OWNED Sites Loaded........');
  }



  Future updateSnag(Snag snag) async {
    //TODO - Just update what is required
    if (kDebugMode) print('DATA-F_US: Update Snag....\n');
    await addSnag(snag);
    if (kDebugMode) print('DATA-L_US: END Update Snag....\n');
  }

  Future addSnag(Snag snag) async {
    if (kDebugMode) print('DATA-F_ASnag: Add Snag....');
    //-- FIREBASE UPDATE START--
    bool isOwner = snag.ownerEmail.toLowerCase() == FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    String? ownerID = isOwner ? FirebaseAuth.instance.currentUser!.uid : _appUser!.mapOfSitePaths![snag.siteUID];
    try {
      if (kDebugMode) print('DATA_ASnag: FIREBASE update starting...');
      await FirebaseFirestore.instance.collection('Profile/$ownerID/Sites/${snag.siteUID}/Snags').doc(snag.uID).set(snag.toJson()).then((onValue) {
        bool hasSite = _snags.containsKey(snag.siteUID);
        if (kDebugMode) print('DATA_ASnag: Added Snag....');
        //if (!hasSite) _snags.putIfAbsent(snag.uID, () => null); // TODO - This was uncommented before
        addToLocalSnags(snag);
      }); //Update firebase first
    } on Exception catch (e) {
      if (kDebugMode) print('DATA_ASnag: Error adding Snag - detail: ${e}');
    }
    if (kDebugMode) print('DATA-L_ASnag: END Adding Snag...');
  }

  addToLocalSnags(Snag snag) {
    if (kDebugMode) print('DATA-F_ALS: Add To Local Snags....');
    Map<String, Snag>? map = _snags[snag.siteUID];
    if (map == null) {
      _snags[snag.siteUID] = {};
      map = _snags[snag.siteUID];
    }
    map![snag.uID] = snag;
    notifyListeners();
//    if (kDebugMode) print('DATA_ALS: Notifying Listeners');
    if (kDebugMode) print('DATA-L_ALS: END Adding LOCAL Snags');
  }

  void removeFromLocalSnags(Snag snag) {
    if (kDebugMode) print('DATA-F_RFLS: Remove From Local Snags...');
    Map<String, Snag>? map = _snags[snag.siteUID];
    if (map == null) {
      if (kDebugMode) print('DATA_RFLS: Map of SNAG does not exist');
      if (kDebugMode) print('DATA-L_RFLS: END');
      return;
    } //Site does not exist, so nothing to remove.
    if (map != null && kDebugMode) print('DATA_RFLS: Length of map before removing: ${map.length}');
    map.remove(snag.uID);
    if (map != null && kDebugMode) print('DATA_RFLS: Length of map before removing: ${map.length}');
    if (map != null && kDebugMode) print('DATA-L_RFLS: Notifying Listeners');
    if (map != null && kDebugMode) print('DATA-L_RFLS: END');
    notifyListeners();
  }

  Future deleteSnag(Snag snag) async {
    if (kDebugMode) print('DATA-F_DSnag: Delete Snag');
    String? ownerID;
    bool isOwner = snag.ownerEmail.toLowerCase() == FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    if (kDebugMode) print('DATA_DSnag : Snag Owner Email: ${snag.ownerEmail} : Site Owner UID: ${_appUser!.mapOfSitePaths![snag.siteUID]}');
    if (!isOwner) {
      ownerID = _appUser!.mapOfSitePaths![snag.siteUID]!;
      if (kDebugMode) print('DATA_DSnag: Snag NOT Found in the List');
      if (kDebugMode) print('DATA-L_DSnag: END');
      if (ownerID == null) return;
    } else {
      ownerID = FirebaseAuth.instance.currentUser!.uid;
    }
    //-- FIREBASE UPDATE START--
    if (kDebugMode) print('DATA_DSnag: FIREBASE Deleting Snag - ${snag.location}');
    try {
      FirebaseFirestore.instance.collection('Profile/$ownerID/Sites/${snag.siteUID}/Snags').doc(snag.uID).delete().then((onValue) {
        if (kDebugMode) print('DATA_DSnag: Deleted Snag - ${snag.location}');
        _snags[snag.siteUID]!.remove(snag.siteUID);
        if (kDebugMode) print('DATA_DSnag: Notifying Listeners');
        notifyListeners();
      }); //Update firebase first
    } on PlatformException catch (e) {
      if (kDebugMode) print('DATA_DSnag: Error Deleting Snag - Details: ${e.code}');
    }
    if (kDebugMode) print('DATA_DSnag: END deleting Snag');
  }

  Future deleteSite(Site site) async {
    if (kDebugMode) print('DATA-F_DSite: Delete Site');
    String ownerID;
    bool isOwner = site.ownerEmail.toLowerCase() == FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    if (!isOwner) return;

    ownerID = FirebaseAuth.instance.currentUser!.uid;

    //-- FIREBASE UPDATE START--
    if (kDebugMode) print('DATA_DSite: FIREBASE Deleting Site - ${site.name}');
    try {
      FirebaseFirestore.instance.collection('Profile/$ownerID/Sites').doc(site.uID).delete().then((onValue) {
        if (kDebugMode) print('DATA_DSite: Deleted Site - ${site.name}');
        _allSites.remove(site.uID);
        _ownedSites.remove(site.uID);
        if (kDebugMode) print('DATA_DSite: Notifying Listeners');
        notifyListeners();
      }); //Update firebase first
    } on PlatformException catch (e) {
      if (kDebugMode) print('DATA_DSite: Error Deleting Site - Details: ${e.code}');
    }
    if (kDebugMode) print('DATA_DSite: END deleting Site');
  }

  getMapOfAllSites() {
    if (kDebugMode) print('DATA-F-L_GMAS: Get map of all sites');
    return _allSites;
  }

  getSite(String siteID) {
    if (kDebugMode) print('DATA-F-L_GS: Get single site');
    return _allSites[siteID]; // returns a site
  }

  /// Returns Map<String Site ID, Site site>
  Map<String, Site> getMapOfOwnedSites() {
    if (kDebugMode) print('DATA-F-L_GLOS: Get List of OWNED sites');
    return _ownedSites;
  }

  getMapOfSharedSites() {
    if (kDebugMode) print('DATA-F-L_GMSS: Get map of SHARED sites');
    return _sharedSites;
  }

  getListOfSnags(String siteUID) {
    if (kDebugMode) print('DATA-F_GLOS: Get List Of All Snags');
    if (_snags[siteUID] != null) {
      if (kDebugMode) print('DATA-L_GLOS: END Returning List of Snags');
      return _snags[siteUID]!.values.toList();
    } else {
      if (kDebugMode) print('DATA-L_GLOS: END Returning NEW List');
      return [];
    }
  }

  List<Colleague> getListOFColleagues() {
    //if (kDebugMode) print('DATA-F-L_GLC: Get List of Colleagues');
    return _appUser!.listOfALLColleagues!;
  }

  Future<bool> addColleague(Colleague colleague2BAdded) async {
    if (kDebugMode) print('DATA-F_AC: Add Colleague');
    bool result = false;
    bool alreadyExists = false;
    for (var colleague in _appUser!.listOfALLColleagues!) {
      colleague.email == colleague2BAdded.email ? alreadyExists = true : false;
    }
    if (alreadyExists && kDebugMode) print('DATA-L_AC: --Colleague ALREADY exists--');
    if (alreadyExists) return true;
    //-- FIREBASE UPDATE START--

      if (kDebugMode) print('DATA_AC: FIREBASE Adding Colleague');
      await FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid).update({
        LIST_OF_COLLEAGUES: FieldValue.arrayUnion([colleague2BAdded.toJson()])
      }).then((onValue) {
        if (kDebugMode) print('DATA_AC: Colleague Added');
        _appUser!.listOfALLColleagues!.add(colleague2BAdded);
        if (kDebugMode) print('DATA_AC: Notifying Listeners');
        notifyListeners();
        result = true;
      })
    .onError((e,StackTrace s){
        if (kDebugMode) print('DATA_AC: Error adding Colleague - Details: $s');
        result = false;
      }); //Update firebase first

    //--FIREBASE UPDATE FINISH--
    if (kDebugMode) print('DATA-L_AC: END Colleague Added: $result');
    return result;
  }

  Future<bool> updateColleague(Colleague person) async {
    if (kDebugMode) print('DATA-F_UC: Update Colleague');
    bool result = false;
    //-- FIREBASE UPDATE START--
    final DocumentReference postRef = FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid);
    try {
      if (kDebugMode) print('DATA_UC: FIREBASE Getting existing profile first');
      await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
        DocumentSnapshot postSnapshot = await tx.get(postRef);
        if (postSnapshot.exists) {
          if (kDebugMode) print('DATA_UC: Profile Exists');
          AppUser user = AppUser.fromJson(postSnapshot.data() as Map<String, dynamic>);
          Colleague? oldColleague;
          user.listOfALLColleagues!.forEach((value) {
            if (value.uniqueID == person.uniqueID) {
              oldColleague = value;
              if (kDebugMode) print('DATA_UC: previous entry is found!');
            }
          });
          if (kDebugMode) print('DATA_UC: FIREBASE Removing from existing Array');
          //Remove the Old instance from the array
          tx.update(postRef, {
            LIST_OF_COLLEAGUES: FieldValue.arrayRemove([oldColleague?.toJson()])
          });
          if (kDebugMode) print('DATA_UC: FIREBASE Adding NEW to existing Array');
          await tx.update(postRef, {
            LIST_OF_COLLEAGUES: FieldValue.arrayUnion([person.toJson()])
          });
        }
      });
      //--FIREBASE UPDATE FINISH--
    } on PlatformException catch (e) {
      if (kDebugMode) print('DATA_UC: Error Updating Colleague - Details: ' + e.details);
    }
    getAppUser()!.listOfALLColleagues!.removeWhere((value) => value.uniqueID == person.uniqueID);
    getAppUser()!.listOfALLColleagues!.add(person);
    if (kDebugMode) print('DATA_UC: Notifying Listener');
    notifyListeners();
    result = true;
    if (kDebugMode) print('DATA-L_UC: END Colleague Updated: $result');
    return result;
  }

  Future<bool> updateProfileImage() async {
    if (kDebugMode) print('DATA-F_UPI: Update Profile Image');
    bool result = false;
    //-- FIREBASE UPDATE START--
    final DocumentReference postRef = FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid);
    try {
      if (kDebugMode) print('DATA_UPI: Firebase update start');
      await FirebaseFirestore.instance.runTransaction((Transaction tx) async {
        DocumentSnapshot postSnapshot = await tx.get(postRef);
        if (kDebugMode) print('DATA_UPI: Getting existing profile');
        if (postSnapshot.exists) {
          if (kDebugMode) print('DATA_UPI: Existing profile found - Updating image');
          tx.update(postRef, {IMAGE: _appUser!.image});
          if (kDebugMode) print('DATA_UPI: Notifying listeners');
          notifyListeners();
          result = true;
        }
      });
    } on PlatformException catch (e) {
      if (kDebugMode) print('DATA_UPI: Error updating profile image - Details: ' + e.details);
    }
    //--FIREBASE UPDATE FINISH--
    if (kDebugMode) print('DATA-L_UPI: END Profile Image Update? $result');
    return result;
  }

  Future<bool> removeColleague(Colleague colleague) async {
    if (kDebugMode) print('DATA-F_RC: Remove Colleague');
    bool result = false;

      if (kDebugMode) print('DATA_RC: Firebase update starting');
      await FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid).update({
        LIST_OF_COLLEAGUES: FieldValue.arrayRemove([colleague.toJson()])
      }).then((onValue) {
        if (kDebugMode) print('DATA_RC: Remove Colleague Successful');
        _appUser!.listOfALLColleagues!.remove(colleague);
        result = true;
        if (kDebugMode) print('DATA_RC: Notifying Listeners');
        notifyListeners();
      }).onError((error, stack) {
        result = false;
        if (kDebugMode) print('DATA_RC: Error updating profile image - Details:  $stack');
      }); //Update firebase first

    //--FIREBASE UPDATE FINISH--
    if (kDebugMode) print('DATA-L_RC: END Colleague Removed? $result');
    return result;
  }

  AppUser? getAppUser() {
    //if (kDebugMode) print('DATA-F-L_GS: Get user');
    return _appUser;
  }

  void setAppUser(AppUser? user) {
    if (kDebugMode) print('DATA-F_SS: Set Profile user');
    _appUser = user;
    if (_appUser != null) if (_appUser!.listOfALLColleagues == null) _appUser!.listOfALLColleagues = [];
    if (_appUser != null) if (_appUser!.mapOfSitePaths == null) _appUser!.mapOfSitePaths = {};
    //if (kDebugMode) print('DATA_SS: Notifying Listeners');
    //notifyListeners();
    if (kDebugMode) print('DATA-L_SS: END set user');
  }

  /// Firebase user is NOT null before coming here
  /// Firebase user email is verified before coming here
  /// This function loads the profile of the app user
  Future<bool> loadAppUserProfile() async {
    //if (kDebugMode) print('Throwing Error');
    //throw PlatformException(code: 'Test Error');
    if (kDebugMode) print('DATA-F_LP: 3 - Load Profile...');
    bool result = false;

    DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('Profile').doc(FirebaseAuth.instance.currentUser!.uid).get();
    if (snapshot.exists) {
      setAppUser(AppUser.fromJson(snapshot.data()!));
      result = true;
      if (kDebugMode) print('DATA_LP: 6.0 - Profile user SET....');
    } else {
      if (kDebugMode) print('DATA_LP: 6.1 - SNAPSHOT DATA WAS NULL');
    }
    if (kDebugMode) print('DATA_LP: 7 - Profile loading complete...');
    return result;
  }



  /// Saves image in ApplicationSupportDirectory
  /// [picture] - Picture which needs to be saved
  /// [siteID] - ID of the site which this pic belongs to (Can be null)
  /// in which case it will be stored in the "QuoteJet" folder
  Future<String?> saveNewPicture(XFile picture, {required String? siteID, required String? snagID, required bool storeExternally}) async {
    // This needs to be done online

    String path = (await getApplicationSupportDirectory()).path; // Can use for both iOS & Android
    path = p.join(path, 'SnagSnapper'); // ..../SnagSnapper/
    if (siteID != null) path = p.join(path, siteID); //..../SnagSnapper/siteID
    if (snagID != null) path = p.join(path, snagID); //..../SnagSnapper/siteID/snadID
    if (kDebugMode) print('COMPLETE PATH NULL - ALERT SHOULD BE SHOWN 1');
    String? returnPath = await _savePic(picture, path);
    if (kDebugMode) print('COMPLETE PATH NULL - ALERT HOULD BE SHOWN 2');
    if (returnPath == null) return null; // Some error happened in creating directory;
    if (storeExternally) {
      try {
        var t = await picture.readAsBytes();
        // ImageGallerySaver.saveImage(
        //   t.buffer.asUint8List(),
        //   quality: 100,
        //   name: "${DateTime.now().toIso8601String()}.png",
        // );
        // TODO: Replace with modern image saving solution
      } on Exception catch (e) {
        if (!kDebugMode) FirebaseCrashlytics.instance.log('** ERROR SAVING NEW PICTURE EXTERNALLY ** $e');
        if (kDebugMode) print('** ERROR SAVING NEW PICTURE EXTERNALLY ** $e');
      }
    }
    return returnPath;
  }

  /// Saves a [picture] file to a given [path]. It creates the name for the [picture] file and stores it
  /// on the given [path] inside a folder called "SiteReport" or the [siteID] if it is not null
  Future<String?> _savePic(XFile picture, String path) async {
    final Directory? directory = await _checkDirectories(path);
    if (kDebugMode) print('COMPLETE PATH NULL - ALERT HOULD BE SHOWN');
    if (directory == null) return null; // Some error happened in cresting directories
    final String saveToPath = p.join(directory.path, 'PNG_${"${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_.png"}');
    await picture.saveTo(saveToPath);
    if (kDebugMode) print('IMAGE SAVED TO: $saveToPath');
    return saveToPath;
  }

  /// Whatever [path] comes in, this function either creates/checks for a folder/directory
  Future<Directory?> _checkDirectories(String path) async {
    Directory? directory;
    try {
      if (await Directory(path).exists()) return Directory(path);
      directory = await Directory(path).create(recursive: true);
    } on Exception catch (e) {
      directory = null;
      FirebaseCrashlytics.instance.log('Could not createDirectory, ERROR:: $e');
      if (kDebugMode) print('** ERROR CREATING DIRECTORY ** $e');
    }
    return directory;
  }

  /// This gets called when the user is already logged in
  /// Similar functionality exists in SignIn Class
  loadProfileOfUser() async {
    User firebaseUser = FirebaseAuth.instance.currentUser!;
    if (firebaseUser.emailVerified) {
      if (kDebugMode) print('MAIN-F_LP: Email is verified -> Load Profile...');

      try {
        if (kDebugMode) print('Initialising purchases');
        await PurchasesHelper.configurePurchases();
        _isProSiteSharing = await PurchasesHelper.isSiteSharingEnabled();
        _isPro = await PurchasesHelper.isUserPro();
        _offerings = await PurchasesHelper.getOfferings();
        // Update CP
        if (kDebugMode) print("ProUser? :: $_isPro   SiteSharingEnabled? :: $_isProSiteSharing");
        if (kDebugMode) print('---Initialising purchases END---');
      } on PlatformException catch (e) {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.fromString('Error in Initialising Rev Cat Purchases Main.dart : _loadUserProfile Function'));
        if (kDebugMode) print('### Error $e');
        return 'RevCat Error';
      }

      try {
        if (kDebugMode) print('---Loading user profile---');
        bool profileResult = await loadAppUserProfile();
        if (kDebugMode) print('MAIN-L_LP: END Loading Profile');
        // 1 - Load Owned Sites
        try {
          if (profileResult) {
            await loadOwnedSites();
          }
        } on Exception catch (e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.fromString('Error in loading Owned Sites : Main.dart : Load Owned Sites'));
          if (kDebugMode) print('MAIN_LP: Error loading Owned - Details: $e');
          return 'Firebase Error Owned Sites';
        }
        // Load Shared Sites
        try {
          if (profileResult) {
            await loadOnlySharedSites();
          }
        } on Exception catch (e) {
          FirebaseCrashlytics.instance.recordError(e, StackTrace.fromString('Error in loading Shared Sites : Main.dart : Load Shared Sites'));
          if (kDebugMode) print('MAIN_LP: Error loading Shared Sites - Details: $e');
          return 'Firebase Error Shared Sites';
        }
        if (profileResult) return 'Profile Found';
        return 'Profile Not Found';
      } on Exception catch (e) {
        if (kDebugMode) log('MAIN_LP: Error loading profile - Details: $e');
        FirebaseCrashlytics.instance.recordError(e, StackTrace.fromString('Error in loading user profile : Main.dart : Load profile of user'));
        return 'Firebase Error';
      }
    } else {
      if (kDebugMode) print('MAIN-F_LP: Email not verified...');
      return 'Email Not Verified'; // Goto Login Page
    }
  }
}
