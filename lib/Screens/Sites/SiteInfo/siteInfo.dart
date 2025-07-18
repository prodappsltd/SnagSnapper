
import 'package:firebase_auth/firebase_auth.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/site.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';

import '../../../Widgets/basicDateField.dart';



class SiteInfo extends StatefulWidget {
  const SiteInfo(this.site, {super.key});
  final Site? site;
  @override
  _SiteInfoState createState() => _SiteInfoState();
}

class _SiteInfoState extends State<SiteInfo> {

  final _formKey = GlobalKey<FormState>();

  /// If existing site is clicked this will be filled in with existing site details
  Site? site;
  /// If no existing sound found then this will be true
  bool newSite = false;


  /// Picture quality button selection
  late int _btnPicQuality;
  /// Emails from map of colleagues where colleague is selected. <Name, Email> map
  Map<String,String> _assignedEmails = {};
  late String _siteImage;
  late String _siteLocation;
  late String _siteName;
  late String _siteClientName;
  late DateTime _siteDate;

  /// Firebase user
  final User _firebaseUser = FirebaseAuth.instance.currentUser!;
  /// General purpose busy flag
  bool busy = false;

  @override
  void initState() {
    super.initState();
    site = widget.site;
    if (site != null) { // If existing site is there, load values
      _loadValuesFromSite(site!);
    } else { // Else start with default values
      _loadDefaults();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Theme.of(context,.colorScheme.primary
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          //backgroundColor: Theme.of(context,.colorScheme.primary
          title: Text('SITE DETAILS', style: GoogleFonts.montserrat(textStyle: (TextStyle(color: Theme.of(context).colorScheme.onBackground))),),
          //backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(icon: const Icon(Icons.arrow_back), color: Theme.of(context).colorScheme.onBackground, onPressed: () { Navigator.pop(context); },),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: IntrinsicHeight(
              child: Container(
                margin: const EdgeInsets.only(left: 10.0, right: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ImageHelper(
                        b64Image: _siteImage,
                        height: getProportionalHeightForTopImage(context,FRACTION),
                        text: 'Add a picture\nof your site',
                        callBackFunction :() async {
                          _siteImage.isEmpty
                              ? _siteImage = await optionsDialogBox(context, 1000)?? '' // Fill it with blank string if null is returned
                              : _siteImage = await optionsDialogBoxWithDEL(context,(){
                                  setState(() =>  _siteImage = '');
                                  Navigator.pop(context);
                                  return;
                              })?? _siteImage;
                          setState(() => _siteImage);
                        }
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        margin: const EdgeInsets.only(left:0.0, right: 0.0, top: 10.0, bottom: 15.0),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(5.0)),
                            boxShadow: [BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0),blurRadius: 5.0, spreadRadius: 1.0)]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      TextFormField(
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                                        keyboardType: TextInputType.text,
                                        textCapitalization: TextCapitalization.words,
                                        initialValue: _siteClientName,
                                        decoration: InputDecoration(
                                          //    border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                                            labelText: 'Client Name (Required)'),
                                        onChanged: (value) {
                                          _siteClientName = value.toString().trim();
                                        },
                                        validator: (value) {
                                          return value.toString().isNotEmpty ? null : '*Required*';
                                        },
                                      ),
                                      TextFormField(
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                                        keyboardType: TextInputType.text,
                                        textCapitalization: TextCapitalization.words,
                                        initialValue: _siteName,
                                        decoration: InputDecoration(
                                          //    border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.business, color: Theme.of(context).colorScheme.primary),
                                            labelText: 'Site Name (Required)'),
                                        onChanged: (value) {
                                          _siteName = value.toString().trim();
                                        },
                                        validator: (value) {
                                          return value.toString().isNotEmpty ? null : '*Required*';
                                        },
                                      ),
                                      TextFormField(
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_ ]'))],
                                        keyboardType: TextInputType.text,
                                        textCapitalization: TextCapitalization.words,
                                        initialValue: _siteLocation,
                                        decoration: InputDecoration(
                                          //    border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                                            labelText: 'Location Name'),
                                        onChanged: (value) {
                                          _siteLocation = value.toString().trim();
                                        },
                                        validator: (value) => null, // Optional field
                                      ),
                                      Container(
                                        width:double.infinity,
                                        margin: const EdgeInsets.symmetric(vertical: 2.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                        ),
                                        child: BasicDateField(
                                            dateFormat: Provider.of<CP>(context, listen: false).getDateFormat(),
                                            siteDate: _siteDate, // For new site it will be DateTime.now
                                            newSite : newSite,
                                            dateChangeFunction: (value) => setState(() => _siteDate = value?? DateTime.now())
                                            ),
                                      ),
                                      Column(
                                        children: <Widget>[
                                          Center(child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('PICTURE QUALITY', style: GoogleFonts.roboto(textStyle:TextStyle(fontWeight: _btnPicQuality==2? FontWeight.w800 : FontWeight.w300,color: Colors.black))),
                                          ),),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              TextButton(
                                                  onPressed: (){
                                                    FocusScope.of(context).unfocus();
                                                    setState(() {
                                                      _btnPicQuality=0;
                                                    });
                                                  },
                                                // style: ButtonStyle(
                                                //   backgroundColor: _btnPicQuality==0? Provider.of<UserData>(context, listen: false).getMainColor():Colors.white,
                                                //   shape: RoundedRectangleBorder(
                                                //     borderRadius: const BorderRadius.only(topLeft: Radius.circular(10.0),bottomLeft: Radius.circular(10.0)),
                                                //     side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                                //   ),
                                                // ),

                                                  child: Text('LOW',style: GoogleFonts.roboto(textStyle:TextStyle(fontSize: _btnPicQuality==0? 22:16,fontWeight: _btnPicQuality==0? FontWeight.w800 : FontWeight.normal,color: _btnPicQuality==0? Colors.black:Theme.of(context).colorScheme.primary))),
                                              ),
                                              TextButton(
                                                  onPressed: (){
                                                    FocusScope.of(context).unfocus();
                                                    setState(() {
                                                      _btnPicQuality=1;
                                                    });
                                                  },
                                                //   color: _btnPicQuality==1? Provider.of<UserData>(context, listen: false).getMainColor():Colors.white,
                                                // shape: RoundedRectangleBorder(
                                                //   side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                                // ),
                                                  child: Text('MEDIUM',style: GoogleFonts.roboto(textStyle:TextStyle(fontSize: _btnPicQuality==1? 22:16,fontWeight: _btnPicQuality==1? FontWeight.w800 : FontWeight.normal, color: _btnPicQuality==1? Colors.black:Theme.of(context).colorScheme.primary))),
                                              ),
                                              TextButton(
                                                  onPressed: (){
                                                    FocusScope.of(context).unfocus();
                                                    setState(() {
                                                      _btnPicQuality=2;
                                                    });
                                                  },
                                                  //color: _btnPicQuality==2? Provider.of<UserData>(context, listen: false).getMainColor():Colors.white,
                                                // shape: RoundedRectangleBorder(
                                                //   borderRadius: const BorderRadius.only(topRight: Radius.circular(10.0),bottomRight: Radius.circular(10.0)),
                                                //   side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                                // ),
                                                  child: Text('HIGH',style: GoogleFonts.roboto(textStyle:TextStyle(fontSize: _btnPicQuality==2? 22:16,fontWeight: _btnPicQuality==2? FontWeight.w800 : FontWeight.normal,color: _btnPicQuality==2? Colors.black:Theme.of(context).colorScheme.primary))),
                                              ),
                                            ],
                                          ),
                                          const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.arrow_drop_up),
                                              Text('Optimum',style: TextStyle(fontSize: 14),),
                                              Icon(Icons.arrow_drop_up),
                                            ],
                                          ),
                                          Text('Lower quality results in smaller PDF report size',textAlign: TextAlign.center,style: GoogleFonts.roboto(textStyle:TextStyle(fontSize: 14,fontWeight: FontWeight.w500,color: Colors.black))),
                                        ],
                                      ),
                                    ],
                                  )
                              ),
                            ),
                            const Divider(),
                            const Center(child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_drop_down),
                                  Text('SHARE WITH COLLEAGUES'),
                                  Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            )),
                            Container(
                              width: double.infinity,
                              height: 313.0,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.grey,
                                    offset: Offset(0.0, 0.0),
                                  ),
                                  BoxShadow(
                                    color: Colors.grey,
                                    offset: Offset(1.0, 1.0),
                                    spreadRadius: -3.0,
                                    blurRadius: 5.0,
                                  ),
                                ],
                              ),

                              child: Center(
                                  child: Provider.of<CP>(context).getListOFColleagues().isEmpty
                                      ? GestureDetector(onTap:()=>Navigator.pushNamed(context, '/profile'),child: const Text('Add colleagues from profile\n\nClick here', textAlign: TextAlign.center, style:TextStyle(fontSize: 20),))
                                      : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: Provider.of<CP>(context).getListOFColleagues().length,
                                    itemBuilder: (BuildContext context, int position) {
                                      return AssignCheckBoxView(
                                          selectedChkBxFunction: (value) async {
                                            setState(() {
                                              if (value != null && value ) {
                                                _assignedEmails.putIfAbsent(Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email,()=> 'FULL');
                                              } else if (value != null && !value ) {
                                                _assignedEmails.remove(Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email);
                                              }
                                            });
                                            if (kDebugMode) print(_assignedEmails);
                                          },
                                          permissionCalBckFunction: () async {
                                            setState(() {
                                              if (_assignedEmails[Provider.of<CP>(context, listen: false)
                                                  .getListOFColleagues()[position].email] == 'FULL'){
                                                _assignedEmails[Provider.of<CP>(context, listen: false)
                                                    .getListOFColleagues()[position].email] = 'VIEW';

                                              } else {
                                                _assignedEmails[Provider.of<CP>(context, listen: false)
                                                    .getListOFColleagues()[position].email] = 'FULL';
                                              }
                                            });
                                            if(kDebugMode) print(_assignedEmails);
                                          },
                                          permissionString: _assignedEmails[Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email],
                                          selectedStatus:_assignedEmails.containsKey(Provider.of<CP>(context, listen: false).getListOFColleagues()[position].email),
                                          colleague: Provider.of<CP>(context, listen: false).getListOFColleagues()[position]);
                                    },
                                  )),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: GestureDetector(
                                  onTap:() => Navigator.pushNamed(context, '/profile'),
                                  child: const Text('Click to add more colleagues', textAlign: TextAlign.center,)),
                            ),
                            const Divider(),
                            GestureDetector(
                              onTap: busy? null : () async {
                                FocusScope.of(context).unfocus();
                                if (_formKey.currentState!.validate()){
                                  _formKey.currentState!.save();
                                  if (kDebugMode) print('Site - Form validated');
                                  if (newSite || _siteImage != site!.image ||
                                      _siteName != site!.name||
                                      _siteClientName != site!.companyName||
                                      _siteLocation != site!.location||
                                      _siteDate != site!.date ||
                                      _btnPicQuality != site!.pictureQuality ||
                                      mapEquals(_assignedEmails,site!.sharedWith)
                                  ) {
                                    setState(() => busy = true);
                                    if (kDebugMode) print('Site - Create Update initiated');
                                    Site nSite = Site(
                                        image: _siteImage,
                                        name : _siteName,
                                        companyName : _siteClientName,
                                        location : _siteLocation,
                                        date : _siteDate,
                                        pictureQuality : _btnPicQuality,
                                        sharedWith : _assignedEmails,
                                      archive: newSite? false : site!.archive,
                                      uID: newSite? getuID() : site!.uID,
                                      ownerEmail: newSite? _firebaseUser.email! : site!.ownerEmail,
                                      ownerName: newSite? Provider.of<CP>(context, listen: false).getAppUser()!.name : site!.ownerName,
                                    );
                                    try {
                                      if (newSite) {
                                        nSite.sharedWith.putIfAbsent(nSite.ownerEmail.toLowerCase(), () => 'OWNER');
                                        await Provider.of<CP>(context, listen: false).addSite(nSite);
                                      } else {
                                        await Provider.of<CP>(context, listen: false).updateSite(nSite);
                                      }
                                      Navigator.pop(context, site);
                                    } catch (e) {
                                      if (mounted) {
                                        showFlushbar(
                                            context: context,
                                            flushbar: Flushbar(
                                              boxShadows: const [
                                                BoxShadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3, spreadRadius: 4),
                                              ],
                                              duration: const Duration(seconds: 6),
                                              flushbarPosition: FlushbarPosition.TOP,
                                              title: 'Error',
                                              message: 'Error updating Site, please try again',
                                              icon: const Icon(Icons.error, size: 35.0,),
                                              shouldIconPulse: true,
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                                              backgroundColor: Colors.red,
                                            )..show(context)
                                        );
                                        setState(() => busy = false);
                                      }
                                    }
                                    setState(() => busy = false);
                                  }
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                    color: activeBTN,
                                    borderRadius: const BorderRadius.all(Radius.circular(10.0))
                                ),
                                padding: const EdgeInsets.all(20.0),
                                margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
                                width: double.infinity,
                                child: Center(child: busy? const SpinKitRipple(color: Colors.white,):const Text('SAVE', style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Colors.white, fontSize: 20.0),)),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _loadDefaults() {
    newSite = true;
    _siteImage = '';
    _siteName = '';
    _siteClientName = '';
    _siteLocation = '';
    _siteDate = DateTime.now();
    _btnPicQuality = 0;
    _assignedEmails = {};
  }
  void _loadValuesFromSite(Site site) {
    _siteImage = site.image;
    _siteName = site.name;
    _siteClientName = site.companyName;
    _siteLocation = site.location;
    _siteDate = site.date;
    _btnPicQuality = site.pictureQuality;
    _assignedEmails = site.sharedWith;
  }

}


class AssignCheckBoxView extends StatelessWidget {
  final Colleague colleague;
  final bool selectedStatus;
  final Function(bool?) selectedChkBxFunction;
  final VoidCallback permissionCalBckFunction;
  final String? permissionString;
  const AssignCheckBoxView({super.key, this.permissionString, required this.colleague, required this.selectedStatus, required this.selectedChkBxFunction, required this.permissionCalBckFunction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(10.0))),
      padding: const EdgeInsets.only(left: 0.0, right: 0.0),
      margin: const EdgeInsets.only(left: 5.0, top: 5.0, right: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            //width: 90,
            //height: 50,
            decoration: BoxDecoration(
                boxShadow:const [ BoxShadow(
                  color: Colors.black12,
                  offset: Offset(1.0, 1.0),
                  spreadRadius: 1.0,
                  blurRadius: 1.0,
                )],
                color: !selectedStatus? Theme.of(context).colorScheme.primary : permissionString == 'VIEW'? Colors.grey[700]: Colors.green[700],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10.0), bottomLeft: Radius.circular(10.0))
            ),
            child: TextButton(
              //padding: const EdgeInsets.all(3.0),
              onPressed: permissionCalBckFunction,
              child: !selectedStatus
                  ? const Text('')
                  : permissionString == 'VIEW'
                    ? Text('View\nOnly', style: GoogleFonts.montserrat(textStyle: const TextStyle(fontSize: 14.0, color: Colors.white, )),textAlign: TextAlign.center,)
                    : Text('Create/Edit\nSnags', style: GoogleFonts.montserrat(textStyle:const TextStyle(fontSize: 14.0,color: Colors.white)),textAlign: TextAlign.center),),
          ),
          const SizedBox(width: 8.0,),
          Expanded(child: Text('${colleague.name}\n${colleague.email}',
            textAlign: TextAlign.start, overflow: TextOverflow.ellipsis, style: styleNormal,)),
          Checkbox(
            value: selectedStatus,
            onChanged: selectedChkBxFunction,
          )
        ],
      ),
    );
  }
}

