import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/site.dart';
import 'package:snagsnapper/Data/snag.dart';
import 'package:snagsnapper/Helper/purchasesHelper.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteInfo.dart';
import 'package:snagsnapper/Screens/Snags/CreateEditSnag.dart';
import 'package:snagsnapper/Screens/Snags/snagDetailedView.dart';
import 'package:snagsnapper/Widgets/reportCardView.dart';
import 'package:snagsnapper/Widgets/snagCardView.dart';

import '../../../Data/ArgsViewPDF.dart';
import '../../../Data/createPDF.dart';
import '../../../Data/user.dart';

bool viewPermission = false;

class SiteStatus extends StatefulWidget {
  final Site site;
  const SiteStatus({Key? key, required this.site}): super (key: key);

  @override
  _SiteStatusState createState() => _SiteStatusState();
}

class _SiteStatusState extends State<SiteStatus> {
  String selectionText = ALL_SNAGS;
  List<Snag> snags = [];
  List<Snag> displaySnags = [];
  String selection = ALL_SNAGS;
  final ScrollController _controller = ScrollController();
  String link = '';
  bool sharedSite = false;
  User firebaseUser = FirebaseAuth.instance.currentUser!;
  bool listenersSet = false;
  bool createPDFInProgress = false;
  List<FileSystemEntity> reports = [];
  bool reportsDirectoryExists = false;

  static const String ALL_SNAGS = 'ALL';
  static const String OPEN_SNAGS = 'OPEN';
  static const String CLOSED_SNAGS = 'CLOSED';
  static const String UNASSIGNED_SNAGS = 'UNASSIGNED';
  static const String FOR_REVIEW_SNAGS = 'FOR REVIEW';
  static const String ASSIGNED_SNAGS = 'ASSIGNED';

  bool viewAccess = false;
  bool hasInternet = false;
  StreamSubscription<DocumentSnapshot>? listenSite;
  StreamSubscription<QuerySnapshot>? listenSnags;
  List<StreamSubscription<QuerySnapshot>>? listeners;
  int allCounter = 0, openCounter = 0, closedCounter = 0, unassignedCounter = 0, reviewCounter = 0, assignedCounter = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialSetup();
      setState(() => displaySnags = snags);
    });
    _listofFiles();
  }

  initialSetup() async {
    if (kDebugMode) print('SiteStatus: Asking for network Status');
    bool hasInternet = await Provider.of<CP>(context, listen: false).getNetworkStatus();
    if (!hasInternet) {
      if (kDebugMode) print('SiteStatus: Informed No Internet');
      networkAlertDialog();
      if (kDebugMode) print('SiteStatus: Leaving initial Function');
      return;
    }
    if (kDebugMode) print('SiteStatus: Calling attachListeners()');
    await _attachSiteListener();
    getDynamicLink();
    listenersSet = true;
    resetCounters();
  }

  resetCounters(){
    setSnagsToDisplay(ASSIGNED_SNAGS);
    setSnagsToDisplay(FOR_REVIEW_SNAGS);
    setSnagsToDisplay(UNASSIGNED_SNAGS);
    setSnagsToDisplay(CLOSED_SNAGS);
    setSnagsToDisplay(OPEN_SNAGS);
    setSnagsToDisplay(ALL_SNAGS);
  }

  /// Attach a listener to the site selected here
  _attachSiteListener() async {
    String siteID = widget.site.uID;
    String siteOwnerEmail = widget.site.ownerEmail.toLowerCase();
    if (kDebugMode) print('SiteStatus: attachSiteListener : OwnerEmail: $siteOwnerEmail  + FireBaseUserEmail: ${firebaseUser.email}');
    /// if owner email != logged in firebase user email, set flag to show it is a shared site
    sharedSite = siteOwnerEmail.toLowerCase() != firebaseUser.email!.toLowerCase();
    if (kDebugMode) print('Attaching Listener SharedSite: $sharedSite');
    // Listen to SNAGS ONLY, if it your OWN site, No need for site listener
    if (!sharedSite) { // Only watch for snag changes if it is your own site
      _attachSnagListener();
      return; // No need to go down and listen to SITE as well
    }
    //No need for a SITE listener below IF it is an OWNED Site as no one else can make changes to your OWN site
    Map<String, String> sharedSitesPath = Provider.of<CP>(context, listen:false).getAppUser()!.mapOfSitePaths!;
    if (kDebugMode && sharedSitesPath.isEmpty) print('Attach Listener : Shared sites Path is Empty');
    if (sharedSitesPath.isEmpty) return; //It will be weird but still adding this statement
    // As it is shared site. Get the owner ID
    String? ownerUID = sharedSitesPath[siteID];
    if (kDebugMode) print('Attach Listener SiteOwnerUID: $ownerUID');
    if (ownerUID != null) {
      DocumentReference ref = FirebaseFirestore.instance.collection('Profile/$ownerUID/Sites').doc(siteID);
      listenSite = ref.snapshots().listen((DocumentSnapshot documentSnapshot) {
        if (kDebugMode) print('Site ${widget.site.name} - Changed Detected');
        Site site = Site.fromJson(documentSnapshot.data() as Map<String, dynamic>);
        Provider.of<CP>(context, listen:false).updateSiteLocalVariables(site);
      });
    }
    await _attachSnagListener();
  }

  _attachSnagListener() async {
    String siteID = widget.site.uID;
    if (kDebugMode) print('Attaching SNAG listener to siteID: $siteID');
    String siteOwnerEmail = widget.site.ownerEmail.toLowerCase();
    if (kDebugMode) print('SiteStatus: attachSnagListener : OwnerEmail: $siteOwnerEmail  + FireBaseUserEmail: ${firebaseUser.email}');
    sharedSite = siteOwnerEmail.toLowerCase() != firebaseUser.email!.toLowerCase();
    if (kDebugMode) print('Attaching SNAG Listener SharedSite: $sharedSite');
    if (!sharedSite) {
      _attachAllSnagOwnerListener(); //No need for a listener
      return;
    }
    // NOW WE NEED COLLECTION DOCUMENT LISTENER FOR THIS SITE ONLY!
    Map<String, String> listOfPaths = Provider.of<CP>(context, listen:false).getAppUser()!.mapOfSitePaths!;
    String? ownerUID = listOfPaths[siteID];
    if (ownerUID != null) {
      listeners ??= [];
      if (widget.site.sharedWith[firebaseUser.email!.toLowerCase()] == 'VIEW') {
        if (kDebugMode) print('Listening to all SNAGS because of VIEW permission');
        listeners!.add(FirebaseFirestore.instance
            .collection('Profile/$ownerUID/Sites/$siteID/Snags')
            .snapshots()
            .listen((QuerySnapshot snapshot) => handleSnapShot(snapshot)));
      } else {
        listeners!.add(FirebaseFirestore.instance
            .collection('Profile/$ownerUID/Sites/$siteID/Snags')
            .where(ASSIGNED_EMAIL, isEqualTo: firebaseUser.email!.toLowerCase())
            .snapshots()
            .listen((QuerySnapshot snapshot) => handleSnapShot(snapshot)));
        listeners!.add(FirebaseFirestore.instance
            .collection('Profile/$ownerUID/Sites/$siteID/Snags')
            .where(CREATOR_EMAIL, isEqualTo: firebaseUser.email!.toLowerCase())
            .snapshots()
            .listen((QuerySnapshot snapshot) => handleSnapShot(snapshot)));
      }
    }
  }

  handleSnapShot(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      switch (change.type) {
        case DocumentChangeType.added:
          {
            Snag snag = Snag.fromJson(change.doc.data() as Map<String, dynamic>);
            Provider.of<CP>(context, listen:false).addToLocalSnags(snag);
            if (kDebugMode) print('SNAG Document added NAME: ${snag.location}');
          }
          break;
        case DocumentChangeType.modified:
          {
            Snag snag = Snag.fromJson(change.doc.data() as Map<String, dynamic>);
            Provider.of<CP>(context, listen:false).addToLocalSnags(snag);
            if (kDebugMode) print('SNAG Document modified NAME: ${snag.location}');
          }
          break;
        case DocumentChangeType.removed:
          {
            Snag snag = Snag.fromJson(change.doc.data() as Map<String, dynamic>);
            if (snag.creatorEmail == FirebaseAuth.instance.currentUser!.email) return; // For cases where created by by someone, then assigned to whoever does not remove from the creator list.
            Provider.of<CP>(context, listen:false).removeFromLocalSnags(Snag.fromJson(change.doc.data() as Map<String, dynamic>));
            if (kDebugMode) print('SNAG Document removed NAME: ${snag.location}');
          }
          break;
      }
    }
  }

  _attachAllSnagOwnerListener() async {
    CollectionReference ref =
        FirebaseFirestore.instance.collection('Profile/${firebaseUser.uid}/Sites/${widget.site.uID}/Snags');
    listenSnags = ref.snapshots().listen((QuerySnapshot snapshot) {
      for (var change in snapshot.docChanges) {
        switch (change.type) {
          case DocumentChangeType.added:
            {
              if (kDebugMode) print('DOCUMENT-CHANGE-TYPE: Document Added');
              Provider.of<CP>(context, listen:false).addToLocalSnags(Snag.fromJson(change.doc.data() as Map<String, dynamic>));
            }
            break;
          case DocumentChangeType.modified:
            {
              if (kDebugMode) print('DOCUMENT-CHANGE-TYPE: Document Modified');
              Provider.of<CP>(context, listen:false).addToLocalSnags(Snag.fromJson(change.doc.data() as Map<String, dynamic>));
            }
            break;
          case DocumentChangeType.removed:
            {
              if (kDebugMode) print('DOCUMENT-CHANGE-TYPE: Document Removed');
              Provider.of<CP>(context, listen:false).removeFromLocalSnags(Snag.fromJson(change.doc.data() as Map<String, dynamic>));
            }
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    if (kDebugMode) print('Listener Disposed - SiteStatus');
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    listenSite?.cancel();
    listenSnags?.cancel();
    listeners?.forEach((listener) => listener.cancel());
    super.dispose();
  }

  void resetDisplayList(String text) {
//    encrypExample();
    setState(() {
      displaySnags = [];
      selectionText = text;
    });
  }

  void setSnagsToDisplay(String text) {
    switch (text) {
      case (ALL_SNAGS):
        {
          resetDisplayList(text);
          setState(() {
            displaySnags = snags;
            allCounter = snags.length;
          });
          if (kDebugMode) print('ALL SNAGS Clicked: ${displaySnags.length} snags.');
        }
        break;
      case (OPEN_SNAGS):
        {
          resetDisplayList(text);
          if (kDebugMode) print(selectionText);
          openCounter = 0;
          for (var snag in snags) {
            if (snag.snagConfirmedStatus) {
              setState(() {
                openCounter++;
                displaySnags.add(snag);
              });
              if (kDebugMode) print('SNAG LOC Name: ${snag.location}');
            }
          }
          if (kDebugMode) print('OPEN SNAGS found: ${displaySnags.length} snags.');
        }
        break;
      case (CLOSED_SNAGS):
        {
          resetDisplayList(text);
          closedCounter = 0;
          for (var snag in snags) {
            if (!snag.snagConfirmedStatus && !snag.snagStatus) {
              setState(() {
                closedCounter++;
                displaySnags.add(snag);
              });
              if (kDebugMode) print('SNAG LOC Name: ${snag.location}');
            }
          }
          if (kDebugMode) print('CLOSED SNAGS Clicked: ${displaySnags.length} snags.');
        }
        break;
      case (UNASSIGNED_SNAGS):
        {
          resetDisplayList(text);
          unassignedCounter = 0;
          for (var snag in snags) {
            if (snag.assignedEmail!.isEmpty) {
              setState(() {
                ++unassignedCounter;
                displaySnags.add(snag);
              });
              if (kDebugMode) print('SNAG LOC Name: ${snag.location}');
            }
          }
          if (kDebugMode) print('UNASSIGNED SNAGS Clicked: ${displaySnags.length} snags.');
        }
        break;
      case (FOR_REVIEW_SNAGS):
        {
          resetDisplayList(text);
          reviewCounter = 0;
          snags.forEach((snag) {
            if (snag.snagConfirmedStatus && !snag.snagStatus) {
              setState(() {
                reviewCounter++;
                displaySnags.add(snag);
              });
            }
          });
          if (kDebugMode) print('FOR REVIEW SNAGS Clicked: ${displaySnags.length} snags.');
        }
        break;
      case (ASSIGNED_SNAGS):
        {
          resetDisplayList(text);
          assignedCounter = 0;
          for (var snag in snags) {
            if (snag.assignedEmail!.isNotEmpty ) {
              setState(() {
                assignedCounter++;
                displaySnags.add(snag);
              });
              if (kDebugMode) print('SNAG LOC Name: ${snag.location}');
            }
          }
          if (kDebugMode) print('ASSIGNED SNAGS Clicked: ${displaySnags.length} snags.');
        }
        break;
    }
  }

  // Make New Function
  _listofFiles() async {
    String directory = (await getApplicationDocumentsDirectory()).path;
    Directory d = Directory("$directory/${widget.site.uID}/");
    if (d.existsSync()){
      reportsDirectoryExists = true;
      setState(() {
        reports = Directory("$directory/${widget.site.uID}/").listSync();  //use your folder name instead of resume.
      });
      if (kDebugMode){
        if (reports.isEmpty) {
          // TODO TEst this - Is it Empty of NULL?
          print('Reports is NULL');
        } else {
          print ('Number of reports found: ${reports.length}');
        }
          print (reports[0].toString());
      }
    } else {
      reports = [];
      reportsDirectoryExists = false;
      if (kDebugMode) print('Directory Does not Exist...');
    }
  }

  @override
  Widget build(BuildContext context) {
    viewPermission = widget.site.sharedWith[Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase()] == 'VIEW';
    snags = Provider.of<CP>(context, listen:false).getListOfSnags(widget.site.uID);
    if (selectionText == ALL_SNAGS) setState(() => displaySnags = snags);
    viewAccess = widget.site.sharedWith[Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase()] == 'VIEW';

    return Scaffold(
      drawer: Drawer(
          child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          SizedBox(
            height: 100,
            child: DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
              ),
              child: Center(child: Text('SNAG TYPE', style: TextStyle(fontSize: 20.0, color: Theme.of(context).colorScheme.tertiaryContainer),)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.done_all),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(allCounter.toString()),),
            title: const Text(ALL_SNAGS),
            subtitle: const Text('Show me all the snags'),
            onTap: () {
              setSnagsToDisplay(ALL_SNAGS);
              Navigator.pop(context);
            },
          ),
          Divider(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(openCounter.toString()),),
            title: const Text(OPEN_SNAGS),
            subtitle: const Text('Only snags which are still open'),
            onTap: () {
              setSnagsToDisplay(OPEN_SNAGS);
              Navigator.pop(context);
            },
          ),
          Divider(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text(CLOSED_SNAGS),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(closedCounter.toString()),),
            subtitle: const Text('Snags which are closed'),
            onTap: () {
              setSnagsToDisplay(CLOSED_SNAGS);
              Navigator.pop(context);
            },
          ),
          Divider(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text(UNASSIGNED_SNAGS),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(unassignedCounter.toString()),),
            subtitle: const Text('Snags which are yet to be assigned'),
            onTap: () {
              setSnagsToDisplay(UNASSIGNED_SNAGS);
              Navigator.pop(context);
            },
          ),
          Divider(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.remove_red_eye),
            title: const Text(FOR_REVIEW_SNAGS),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(reviewCounter.toString()),),
            subtitle: const Text('Snags awaiting a review to be closed'),
            onTap: () {
              setSnagsToDisplay(FOR_REVIEW_SNAGS);
              Navigator.pop(context);
            },
          ),
          Divider(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind),
            title: const Text(ASSIGNED_SNAGS),
            trailing: CircleAvatar(backgroundColor: Colors.grey, foregroundColor: Colors.black,child: Text(assignedCounter.toString()),),
            subtitle: const Text('Show all assigned snags'),
            onTap: () {
              setSnagsToDisplay(ASSIGNED_SNAGS);
              Navigator.pop(context);
            },
          ),
        ],
      )
      ),
      endDrawer: Provider.of<CP>(context, listen:false).isOwner(widget.site.ownerEmail)
          ? Drawer(
          child: LayoutBuilder(
              builder: (context, constraint){
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraint.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          //height: 100,
                          child: DrawerHeader(
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary
                            ),
                            child: Center(child: Text('SELECT OPTION', style: TextStyle(fontSize: 20.0, color: Theme.of(context).colorScheme.onPrimary),)),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf),
                          title: const Text('CREATE REPORT'),
                          subtitle: const Text('Create and view report'),
                          onTap: () async {
                            int groupValue = 0;
                            int? result =
                            await showDialog(
                                context: context,
                                builder: (BuildContext context){
                                  return StatefulBuilder(
                                    builder: (context,setState){
                                      return AlertDialog(
                                        title: const Text('Pick Content'),
                                        content: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            GestureDetector(onTap:()=>setState(()=> groupValue=0),child: Container(padding:const EdgeInsets.all(16.0), color: groupValue==0? activeBTN : Colors.white,child: const Text('All Snags'),)),
                                            GestureDetector(onTap:()=>setState(()=> groupValue=1),child: Container(padding:const EdgeInsets.all(16.0), color: groupValue==1? activeBTN : Colors.white,child: const Text('Open Snags'),)),
                                            GestureDetector(onTap:()=>setState(()=> groupValue=2),child: Container(padding:const EdgeInsets.all(16.0), color: groupValue==2? activeBTN : Colors.white,child: const Text('Closed Snags'),)),
                                          ],
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('PROCEED'),
                                            onPressed: ()=>Navigator.pop(context,groupValue),
                                          )
                                        ],
                                      );
                                    }
                                  );
                                }
                            );
                            if (kDebugMode) print('Only print $result SNAGS--------');
                            if (result != null) _createPDFAndView(this.context, result);
                            Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        ListTile(
                          leading: Icon(Icons.color_lens, color: Provider.of<CP>(context).getPDFColor(),),
                          title: Text('REPORT COLOR', style: TextStyle(color: Provider.of<CP>(context).getPDFColor()),),
                          subtitle: Text('Choose report theme color', style: TextStyle(color: Provider.of<CP>(context).getPDFColor()),),
                          onTap: () async {
                            return showDialog(
                              context: context,
                              builder:(context){
                                return AlertDialog(
                                  title: const Text('Pick PDF color!'),
                                  content: SingleChildScrollView(
                                    child: MaterialPicker(
                                      pickerColor: Provider.of<CP>(context).getPDFColor(),
                                      onColorChanged: (Color color) =>
                                          Provider.of<CP>(context, listen:false).setPDFColor(color),
                                    ),
                                    // Use Material color picker:
                                    //
                                    // child: MaterialPicker(
                                    //   pickerColor: pickerColor,
                                    //   onColorChanged: changeColor,
                                    //   showLabel: true, // only on portrait mode
                                    // ),
                                    //
                                    // Use Block color picker:
                                    //
                                    // child: BlockPicker(
                                    //   pickerColor: currentColor,
                                    //   onColorChanged: changeColor,
                                    // ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Perfect!'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              }
                            );
                            Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        ListTile(
                          leading: const Icon(Icons.style),
                          title: const Text('REPORT STYLE'),
                          subtitle: const Text('Select the style of your report'),
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/reportFormat');
                          },
                        ),
                        Divider(
                          height: 1.0,
                          color: Theme.of(context).colorScheme.primary,

                        ),
                        ListTile(
                          leading: const Icon(Icons.remove_red_eye),
                          title: const Text('VIEW PAST REPORTS'),
                          subtitle: const Text('Select to view reports already created'),
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (context)=>AlertDialog(
                                  title: const Text('Previous Reports'),
                                  content: reportsDirectoryExists? SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.95,
                                    child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: reports.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          return Dismissible(
                                            background: Container(
                                              margin: const EdgeInsets.all(0.0),
                                              padding: const EdgeInsets.only(right: 8.0),
                                              color: Colors.red,
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: <Widget>[
                                                  Icon(
                                                    Icons.delete_sweep,
                                                    size: 35,
                                                    color: Colors.white,
                                                  )
                                                ],
                                              ),
                                            ),
                                            key: Key(reports[index].toString()),
                                            direction: DismissDirection.endToStart,
                                            onDismissed: (direction){
                                              //bool result;
                                              FileSystemEntity? file = reports[index];
                                              if (file.existsSync()){
                                                try {
                                                  file.deleteSync();
                                                  reports.removeAt(index);
                                                } catch (e){
                                                  if (kDebugMode) print('Error deleting file');
                                                }
                                              }
                                            },
                                            confirmDismiss: (DismissDirection direction) async {
                                              return await showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  // Do not allow people with View permission to delete snags.
                                                  return AlertDialog(
                                                    title: const Text("Confirm"),
                                                    content: const Text('Are you sure you wish to delete this report?'),
                                                    actions: <Widget>[
                                                      TextButton(
                                                          onPressed: () => Navigator.of(context).pop(true), child: const Text("DELETE")),
                                                      TextButton(
                                                        onPressed: () => Navigator.of(context).pop(false),
                                                        child: const Text("CANCEL"),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: GestureDetector(
                                              child: ReportCardView(path:reports[index].toString()),
                                              //TODO onTap: (){Navigator.push(context, MaterialPageRoute(builder: (context)=> PdfViewer(reports[index].path,widget.site.uID)));},
                                            ),
                                          );
                                        }),
                                  ): const Text('No reports have been created!'),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: ()=>Navigator.pop(context),
                                      child: const Text('Close'),
                                    )
                                  ],
                                )
                            );
                          },
                        ),
                        Divider(
                          height: 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const Expanded(child: SizedBox(),),
                        Divider(
                          thickness: 10.0,
                          color: Theme.of(context).colorScheme.primary,

                        ),
                        Container(
                          color: Colors.red,
                          child: ListTile(
                            leading: const Icon(Icons.delete, color: Colors.black,),
                            title: const Text('DELETE SITE'),
                            subtitle: const Text('Delete this site. This cannot be undone!'),
                            onTap: () async {
                              bool result = await showDialog(
                                  context: context,
                                  builder: (context)=> AlertDialog(
                                    title: const Text('DELETE SITE!'),
                                    content: const Text('Are you sure to delete this site?'),
                                    actions: <Widget>[
                                      TextButton(
                                        child: const Text('CANCEL'),
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                      ),
                                      TextButton(
                                        child: const Text('DELETE'),
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                      ),
                                    ],
                                )
                              );
                              if (result) {
                                Provider.of<CP>(context, listen:false).deleteSite(widget.site);
                                Navigator.popUntil(context, ModalRoute.withName('/mySites'));
                              }
                            },
                          ),
                        ),
                        Divider(
                          thickness: 10.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
              },
          )
      )
          :Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 100,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(child: Text('SHARED SITE', style: TextStyle(fontSize: 20.0, color: Theme.of(context).colorScheme.tertiaryContainer),)),
              ),
            ),

            ListTile(
              leading: Icon(Icons.info, color: Theme.of(context).colorScheme.primary,),
              title: const Text('This is a shared site. No options available!'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

          ],
        )

      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          leading: IconButton(icon: Icon(Icons.arrow_back), color: Theme.of(context).colorScheme.onBackground, onPressed: ()=> Navigator.pop(context),
          ),
          title: Text(
            'SNAGS', style: GoogleFonts.montserrat( textStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
          ),
          // backgroundColor: Theme.of(context).colorScheme.onBackground,
          elevation: 1.0,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: viewAccess
          ? const Text('')
          : FloatingActionButton(
        enableFeedback: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topRight: Radius.circular(100),
                bottomLeft: Radius.circular(100),
                bottomRight: Radius.circular(100),
                topLeft: Radius.circular(20))
        ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CreateSnag(
                              snag: null,
                              siteID: widget.site.uID,
                              siteOwnersEmail: widget.site.ownerEmail,
                            )));

              },
              elevation: 5.0,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.add,
                size: 50.0,
                color: Colors.white,
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        elevation: 5.0,
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: const CircularNotchedRectangle(),
        notchMargin: 5.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Builder(
              builder: (context){
                return IconButton(
                    icon: Icon(Icons.receipt, color: Theme.of(context).colorScheme.onPrimaryContainer,),
                    onPressed: () async {
                      resetCounters();
                      Scaffold.of(context).openDrawer();
                    }
                );
              },
            ),
            Text(
              selectionText,
              style: GoogleFonts.montserrat (textStyle: TextStyle(
                  fontSize: 18.0,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.background, //mainYellow,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            onTap: () async {
              String email = FirebaseAuth.instance.currentUser!.email!;
              if (kDebugMode) print('Owner Email: ${widget.site.ownerEmail} - Firebase Email: $email');
              widget.site.ownerEmail == email
                  ? Navigator.push(context, MaterialPageRoute(builder: (context) => SiteInfo(widget.site)))
                  : null;
            },
            child: SizedBox(
              height: MediaQuery.of(context).size.height / 7,
              child: Row(
//                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  SiteImage(site: widget.site),
                  Flexible(child: SiteText(site: widget.site)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('$selectionText SNAGS', style: GoogleFonts.roboto(textStyle: TextStyle(color:Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto-BoldItalic.ttf')),),
                sharedSite
                    ? const Text('')
                    : link == ''
                        ? const Center(child: Text(''))
                        : InkWell(
                            child: GestureDetector(
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.share,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                    Text(
                                      '  Share Site Link',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.normal,
                                          fontFamily: "Roboto-Bold.ttf"),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () async {
                                bool isSiteSharing = await PurchasesHelper.isSiteSharingEnabled();
                                if (!isSiteSharing){// Show Dialog to purchase
                                showProUserAlert(context);
                                }
                                //Purchase success then proceed
                                isSiteSharing = await PurchasesHelper.isSiteSharingEnabled();
                                if (isSiteSharing) Share.share(
                                    'Hi, I would like to share \'${widget.site.name}\' site at \'${widget.site.location}\' with you on SnagSnapper app. Please click on the link to download the site to your app: \n $link',
                                    subject: 'Site share request on SnagSnapper app');
                                },
                            ),
                          ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
                scrollDirection: Axis.vertical,
                controller: _controller,
                reverse: false,
                shrinkWrap: true,
                itemCount: displaySnags.length,
                itemBuilder: (BuildContext context, int index) {
                  return Dismissible(
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.all(5.0),
                      padding: const EdgeInsets.only(right: 16.0),
                      color: Colors.red,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Icon(
                            Icons.delete_sweep,
                            size: 35,
                            color: Colors.white,
                          )
                        ],
                      ),
                    ),
                    key: UniqueKey(),
                    confirmDismiss: (DismissDirection direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          // Do not allow people with View permission to delete snags.
                          return AlertDialog(
                            title: Text(((viewPermission) ||
                                ((displaySnags[index].assignedEmail!.isNotEmpty) &&
                                    displaySnags[index].ownerEmail.toLowerCase() != Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase())
                            )
                                ? "Not Allowed"
                                : "Confirm"),
                            content: Text(viewPermission
                                ? "Your \'View\' access does not allow for deleting snag(s)"
                                : ((displaySnags[index].assignedEmail != null &&
                                        displaySnags[index].assignedEmail!.isNotEmpty) &&
                            displaySnags[index].ownerEmail.toLowerCase()!=Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase())
                                    ? "You cannot delete snags which are already assigned"
                                    : "Are you sure you wish to delete this snag?"),
                            actions: (viewAccess) ||
                                ((displaySnags[index].assignedEmail != null &&
                                        displaySnags[index].assignedEmail!.isNotEmpty) &&
                                    displaySnags[index].ownerEmail.toLowerCase()!=Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase())
                                ? <Widget>[
                                    TextButton(
                                        onPressed: () {
                                          if (kDebugMode) print(displaySnags[index].assignedEmail != null);
                                          if (kDebugMode) print(displaySnags[index].assignedEmail!.isNotEmpty);
                                          Navigator.of(context).pop(false);
                                        },
                                        child: const Text("OK")),
                                  ]
                                : <Widget>[
                                    TextButton(
                                        onPressed: () { Navigator.of(context).pop(true);}, child: const Text("DELETE")),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("CANCEL"),
                                    ),
                                  ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        await Provider.of<CP>(context, listen:false).deleteSnag(displaySnags[index]);
                        setState(() {
                          //snags.remove(displaySnags[index]);
                          displaySnags.removeAt(index);
                        });
                      }
                    },
                    child: SnagCardView(
                        key: Key((displaySnags[index]).uID),
                        snag: displaySnags[index],
                        callBack: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SnagDetailedView(
                                        snag: displaySnags[index],
                                        siteID: widget.site.uID,
                                        siteOwnersEmail: widget.site.ownerEmail,
                                      )));
                        }),
                  );
                }),
          ),
        ],
      ),
    );
  }

  _createPDFAndView(BuildContext context, int result) async {
    setState(() => createPDFInProgress = true);
    var listOfSnags = Provider.of<CP>(context, listen:false).getListOfSnags(widget.site.uID);
    var listOfChosenSnags = <Snag>[];
    if (result>0) {
      listOfSnags.forEach((Snag snag) {
        switch (result){
          case 1: {
            if (snag.snagConfirmedStatus) listOfChosenSnags.add(snag);
          } break;
          case 2:{
            if (!snag.snagConfirmedStatus) listOfChosenSnags.add(snag);
          }break;
        }
      });
    } else {
      listOfChosenSnags = listOfSnags;
    }
    var site = widget.site;
    AppUser user = Provider.of<CP>(context, listen:false).getAppUser()!;
    Color color = Provider.of<CP>(context, listen:false).getPDFColor();
    CreatePDF doc = CreatePDF(
      context,
      site,
      listOfChosenSnags,
      user,
      color,
    );
    String? path = await doc.createPDF();
    setState(() => createPDFInProgress = false);
    path != null
        ? Navigator.pushNamed(context, '/pdfViewer', arguments: ArgsVIEWPDF(siteUID: site.uID, path: path))
        : showErrorDialog();
  }

  showErrorDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error encountered'),
            content: const Text('Error creating PDF, please try again'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          );
        }
        );
  }

  Future getDynamicLink() async {
    var user = FirebaseAuth.instance.currentUser;
    // String encryptedUserID = encryptText(user!.uid);
    // String encryptedSiteID = encryptText(widget.site.uID);
    // if (kDebugMode) {
    //   print('UserUID: ${user.uid}');
    //   print('Encrypted UserID: $encryptedUserID');
    //   print('Decrypted UserID: ${decryptText(encryptedUserID)}');
    //   print('SiteUID: ${widget.site.uID}');
    //   print('Encrypted SiteID: $encryptedSiteID');
    //   print('Decrypted SiteID: ${decryptText(encryptedSiteID)}');
    // }

    try {
      // Bypassing the encryption as it is not decrupting properly!
      //link = (await createDynamicLinkForThisSite(encryptedUserID, encryptedSiteID)).toString();
      link = (await createDynamicLinkForThisSite(user!.uid, widget.site.uID)).toString();
    } on PlatformException catch(e){
      link = '';
      if (kDebugMode) print('**************************** - Platform Exception oCcured : ${e.details}');
    }
    setState(() => link);
  }


  networkAlertDialog() {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder:(context){
          return AlertDialog(
                title: const Text("NETWORK ERROR!"),
                content: const Text("Internet connection error. I will be unable to listen to any updates or download snags!"),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK")),
                ]);
        }

    );
  }

  showProUserAlert(context){
    Alert(
      context: context,
      style: kWelcomeAlertStyle(context),
      image: Image.asset(
        "images/worker.png",
        height: 75,
      ),
      title: "Site Sharing",
      content: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 20.0, right: 8.0, left: 8.0, bottom: 20.0),
            child: Text(
              'This is a paid upgrade feature.\nUpgraded users can share the sites with other users and collaborate in populating information '
                  'for the same site. You can however still create PDF reports of your own work and share them freely without this upgrade',
              textAlign: TextAlign.center,
              style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer), // TODO - Try something else, description too bold
              // style: kSendButtonTextStyle,
            ),
          )
        ],
      ),
      buttons: [
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () {
            Navigator.pushNamed(context, '/upSellSiteSharing');
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "Show more",
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
        DialogButton(
          radius: BorderRadius.circular(10),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
          width: 127,
          color: Theme.of(context).colorScheme.primary,
          height: 52,
          child: Text(
            "OK",
            style: kSendButtonTextStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary,),
          ),
        ),
      ],
    ).show();
  }

}

class SiteText extends StatelessWidget {
  final Site site;
  const SiteText({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 0.0, bottom: 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text(
            'Site Name: ${site.name}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.normal,
                fontFamily: "Roboto-Bold.ttf"),
          ),
          Text('Client: ${site.companyName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              fontFamily: "Roboto-Bold.ttf")),
          Container(
            color: Theme.of(context).colorScheme.primary,
            height: 1.0,
            width: 150.0,
          ),
          Text('Manager: ${site.ownerName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.normal,
              fontFamily: "Roboto-Bold.ttf")),
          //Text('Creator Name: ${site.ownerName}', style: smallStyle),
        ],
      ),
    );
  }
}

class SiteImage extends StatelessWidget {
  final Site site;
  const SiteImage({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width / 3,
      decoration: BoxDecoration(
          image: DecorationImage(
              image: site.image.isNotEmpty ? MemoryImage(base64Decode(site.image)) : const AssetImage('images/1024LowPoly.png') as ImageProvider,
              fit: BoxFit.cover)),
    );
  }
}
