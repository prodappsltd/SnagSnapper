import 'dart:convert';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Screens/signature.dart';
import 'package:snagsnapper/Widgets/imageHelper.dart';

import '../Constants/constants.dart';
import '../Data/site.dart';
import '../Data/user.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _formKey = GlobalKey<FormState>();
  final _formKeyColleaguePopUp = GlobalKey<FormState>();
  bool dateBritish = true;

  /// AppUser definitely exists when on this screen as to login you need to signup and
  /// to signup you need to create a profile first which becomes app user.
  late AppUser appUser;
  String _name = '';
  String _jobTitle = '';
  String _companyName = '';
  String _postcodeOrArea = '';
  String _phone = '';
  String _email = '';
  String _dateFomat = '';
  String _signature = '';
  bool busy = false;

  final colleagueNameController = TextEditingController();
  final colleagueEmailController = TextEditingController();
  final colleaguePhoneController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    appUser = Provider.of<CP>(context, listen: false).getAppUser()!;
    if (appUser.dateFormat == 'dd-MM-yyyy') {
      setState(() => dateBritish = true);
    } else {
      setState(() => dateBritish = false);
    }
    setState(() {
      _signature = appUser.signature;
    });
  }

  @override
  void dispose() {
    if (kDebugMode) print('Profile Disposed');
    colleagueEmailController.dispose();
    colleagueNameController.dispose();
    colleaguePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //loadAppUser();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          title: Text(
            'My Profile',
            style: GoogleFonts.montserrat(textStyle: (TextStyle(color: Theme.of(context).colorScheme.onSurface))),
          ),
          //backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: () {
                Navigator.pop(context);
              }),
          elevation: 5.0,
          //backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
                //  minHeight: viewportConstraints.maxHeight,
                ),
            child: Container(
              margin: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ImageHelper(
                      b64Image: appUser.image,
                      height: getProportionalHeightForTopImage(context, FRACTION),
                      text: 'Click to add your \ncompany logo',
                      callBackFunction: busy
                          ? () {}
                          : () async {
                              appUser.image.isEmpty
                                  ? appUser.image = await optionsDialogBox(context, 1000) ?? appUser.image
                                  : appUser.image = await optionsDialogBoxWithDEL(context, () {
                                        setState(() => appUser.image = '');
                                        Provider.of<CP>(context, listen: false).updateProfileImage();
                                        Navigator.pop(context);
                                      }) ??
                                      appUser.image;
                              if (appUser.image.isNotEmpty) {
                                setState(() => appUser.image);
                                Provider.of<CP>(context, listen: false).updateProfileImage();
                              }
                            }),
                  const Divider(
                    height: 30,
                    thickness: 0.0,
                  ),
                  // PROFILE DETAILS
                  Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                        boxShadow: const [
                          //BoxShadow(color: Theme.of(context).colorScheme.shadow, offset: const Offset(0.0, 0.0), blurRadius: 5.0, spreadRadius: 1.0)
                        ]),
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Text(
                                'Profile',
                                textScaler: const TextScaler.linear(2),
                                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiaryContainer),
                              ),
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              enabled: !busy,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              initialValue: appUser.name,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.perm_identity, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Name (Required)'),
                              onChanged: (value) {
                                _name = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : '*Required*';
                              },
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              enabled: !busy,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              initialValue: appUser.jobTitle,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.perm_contact_calendar, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Job Title (Required)'),
                              onChanged: (value) {
                                _jobTitle = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : '*Required*';
                              },
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              enabled: !busy,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              initialValue: appUser.companyName,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Company Name (Required)'),
                              onChanged: (value) {
                                _companyName = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : '*Required*';
                              },
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              enabled: !busy,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z ]'))],
                              keyboardType: TextInputType.text,
                              // textCapitalization: TextCapitalization.characters,
                              initialValue: appUser.postcodeOrArea,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Postcode or Area (Required)'),
                              onChanged: (value) {
                                _postcodeOrArea = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isNotEmpty ? null : '*Required*';
                              },
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              enabled: !busy,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[+0-9]'))],
                              keyboardType: TextInputType.phone,
                              //textCapitalization: TextCapitalization.none,
                              initialValue: appUser.phone,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Phone (Required)'),
                              onChanged: (value) {
                                _phone = value.toString().trim();
                              },
                              validator: (value) {
                                return value.toString().isEmpty ? '* Required *' : null;
                              },
                            ),

                            TextFormField(
                              style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@_ ]'))],
                              keyboardType: TextInputType.emailAddress,
                              textCapitalization: TextCapitalization.none,
                              enabled: false,
                              initialValue: appUser.email,
                              decoration: InputDecoration(
                                  //    border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.mail_outline, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer),
                                  labelText: 'Email (Required)'),
                              onChanged: (value) {
                                _email = value.toString().trim();
                              },
                              validator: (value) {
                                String pattern1 =
                                    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
                                RegExp regex = RegExp(pattern1);
                                return (!regex.hasMatch(value ?? '')) ? 'Invalid email' : null;
                              },
                            ),
                            const SizedBox(
                              height: 10.0,
                            ),
                            // Colour Pickup - Theme SetUp
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Column(
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Theme Color',
                                        style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: busy
                                          ? null
                                          : () {
                                              showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title: const Text('Pick theme color!'),
                                                      content: SingleChildScrollView(
                                                        child: BlockPicker(
                                                          pickerColor: Theme.of(context).colorScheme.primary,
                                                          onColorChanged: (Color color) => Provider.of<CP>(context, listen: false).changeSeed(color),
                                                        ), // TODO SIMPLIFY THIS - TOO MANY OPTIONS
                                                      ),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          child: const Text('Done'),
                                                          onPressed: () {
//                                            setState(() => currentColor = pickerColor);
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            },
                                      child: Container(
                                        height: 60.0,
                                        width: 60.0,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(Radius.circular(30.0)),
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 20.0,
                            ),
                            Center(
                                child: Text(
                              'Date Format',
                              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            )),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    Provider.of<CP>(context, listen: false).changeDateFormat(true);
                                    _dateFomat = 'dd-MM-yyyy';
                                    setState(() => dateBritish = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                                      border: Border.all(
                                          width: dateBritish == true ? 0.0 : 1.0,
                                          color: dateBritish == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary),
                                      color: dateBritish == true ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiaryContainer,
                                    ),
                                    // shape: RoundedRectangleBorder(
                                    //   borderRadius: const BorderRadius.only(
                                    //       topLeft: Radius.circular(10.0), bottomLeft: Radius.circular(10.0)),
                                    //   side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                    // ),
                                    child: Text(
                                      'DD-MM-YYYY',
                                      style: TextStyle(
                                          color: dateBritish == true
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : Theme.of(context).colorScheme.onTertiaryContainer),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 20,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    Provider.of<CP>(context, listen: false).changeDateFormat(false);
                                    _dateFomat = 'MM-dd-yyyy';
                                    setState(() => dateBritish = false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                                      border: Border.all(
                                          width: dateBritish == false ? 0.0 : 1.0,
                                          color: dateBritish == false ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary),
                                      color: dateBritish == false ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiaryContainer,
                                    ),
                                    child: Text(
                                      'MM-DD-YYYY',
                                      style: TextStyle(
                                          color: dateBritish == false
                                              ? Theme.of(context).colorScheme.onPrimary
                                              : Theme.of(context).colorScheme.onTertiaryContainer),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 30.0,
                            ),
                            Center(
                                child: Text(
                              'Add/Edit Signature',
                              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            )),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                GestureDetector(
                                  onTap: busy
                                      ? null
                                      : () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const GetSignature())).then((value) {
                                            if (value != null) {
                                              setState(() {
                                                _signature = base64Encode(value);
                                              });
                                            }
                                          });
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                                    width: MediaQuery.of(context).size.width / 2,
                                    height: 75,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).colorScheme.primary),
//                                    image: DecorationImage()
                                    ),
                                    child: (_signature.isEmpty)
                                        ? Center(
                                            child: Text(
                                            'Click Here',
                                            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onTertiaryContainer),
                                          ))
                                        : Image.memory(
                                            base64Decode(_signature),
                                            fit: BoxFit.fill,
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            /// SAVE BUTTON
                            GestureDetector(
                              onTap: busy
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        setState(() => busy = true);
                                        await Provider.of<CP>(context, listen: false)
                                            .updateProfile(_name, _jobTitle, _companyName, _postcodeOrArea, _phone, _email, _dateFomat, _signature);
                                        setState(() => busy = false);
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                      }
                                    },
                              child: Container(
                                decoration:
                                    BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                                padding: const EdgeInsets.all(20.0),
                                margin: const EdgeInsets.only(left: 30.0, right: 30.0, top: 20.0, bottom: 20.0),
                                width: double.infinity,
                                child: Center(
                                    child: busy
                                        ? SpinKitRipple(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          )
                                        : Text(
                                            'SAVE',
                                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),
                                          )),
                              ),
                            ),
                          ],
                        )),
                  ),
                  const Divider(
                    height: 30,
                  ),

                  // ADD COLLEAGUE
                  Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: const BorderRadius.all(Radius.circular(10.0)),
                        boxShadow: const [
                          //BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0), blurRadius: 5.0, spreadRadius: 1.0)
                        ]),
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Colleagues',
                              textScaler: const TextScaler.linear(2),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            ),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return const AlertDialog(
                                          title: Text('Colleagues'),
                                          content: Text(
                                              'You should add \'ALL\' your colleagues here with whom you might collaborate e.g. share a site or a snag with. '
                                              '\n\nThese will appear under individual sites and you can select which colleagues you want to share information with.'
                                              '\n\nYou can add and delete colleagues later here as well'));
                                    });
                              },
                              child: Icon(
                                size: 40.0,
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                              ),
                            )
                          ],
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: Provider.of<CP>(context, listen: true).getListOFColleagues().length,
                          itemBuilder: (BuildContext context, int index) {
                            return Dismissible(
                              confirmDismiss: (DismissDirection direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("CONFIRM"),
                                      content: const Text(
                                          "Are you sure you wish to delete this colleague? \n\nYou will not be able to share any site with them and they will not be able to access any sites already shared."),
                                      actions: <Widget>[
                                        TextButton(
                                            onPressed: () {
                                              String email = Provider.of<CP>(context, listen: false).getListOFColleagues().elementAt(index).email;
                                              bool isShared = false;
                                              late Site siteShared;
                                              for (var site in Provider.of<CP>(context, listen: false).getMapOfOwnedSites().values) {
                                                if (site.sharedWith[email] != null) {
                                                  if (kDebugMode) print('Cannot Delete this colleague!');
                                                  isShared = true;
                                                  siteShared = site;
                                                  break;
                                                }
                                              }
                                              if (isShared) {
                                                Navigator.of(context).pop(false);
                                                showSharedSitePopUp(siteShared);
                                              } else {
                                                Navigator.of(context).pop(true);
                                              }
                                            },
                                            child: const Text("DELETE")),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text("CANCEL"),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              background: Container(
                                  color: Colors.red,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: <Widget>[
                                      Icon(
                                        Icons.delete_sweep,
                                        color: Colors.white,
                                        size: 35.0,
                                      ),
                                    ],
                                  )),
                              key: Key(Provider.of<CP>(context, listen: false).getListOFColleagues()[index].uniqueID),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) async {
                                bool result = await Provider.of<CP>(context, listen: false)
                                    .removeColleague(Provider.of<CP>(context, listen: false).getListOFColleagues()[index]);
                                if (kDebugMode) print('Result of removing colleague : $result');
                                Flushbar(
                                  title: result ? "Success" : "Error",
                                  icon: result ? const Icon(Icons.check_circle) : const Icon(Icons.error),
                                  backgroundColor: result ? Colors.green : Theme.of(context).colorScheme.onError,
                                  message: result ? 'Colleague successfully removed' : 'Error removing colleague, please try again',
                                  duration: Duration(milliseconds: result ? 1500 : 2500),
                                ).show(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.email,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            Provider.of<CP>(context, listen: false).getListOFColleagues()[index].name,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(Provider.of<CP>(context, listen: false).getListOFColleagues()[index].email, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_back_ios,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (BuildContext context, int index) {
                            return const Divider();
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            setState(() => busy = true);
                            Colleague? colleague = await _showPopUpDialog();
                            if (colleague != null) {
                              if (colleague.email != Provider.of<CP>(context, listen: false).getAppUser()!.email) {
                                // To make sure you are not adding yourself
                                bool result = await Provider.of<CP>(context, listen: false).addColleague(colleague);
                                Flushbar(
                                  title: result ? "Success" : "Error",
                                  icon: result ? const Icon(Icons.check_circle) : const Icon(Icons.error),
                                  backgroundColor: result ? Colors.green : Theme.of(context).colorScheme.onError,
                                  message: result ? 'Colleague successfully added' : 'Error adding colleague, please try again',
                                  duration: Duration(milliseconds: result ? 1500 : 2500),
                                ).show(context);
                              } else {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return const AlertDialog(
                                        title: Text('Information'),
                                        content: Text('You cannot add yourself as your colleague, please use a different email '),
                                      );
                                    });
                              }
                            }
                            setState(() => busy = false);
                          },
                          child: Container(
                            decoration:
                                BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                            padding: const EdgeInsets.all(20.0),
                            margin: const EdgeInsets.only(left: 30.0, right: 30.0, top: 20.0, bottom: 20.0),
                            width: double.infinity,
                            child: Center(
                                child: busy
                                    ? SpinKitRipple(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      )
                                    : Text(
                                        'ADD',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),
                                      )),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _showPopUpDialog() {
    //Colleague colleague = Colleague();
    String name = '';
    String email = '';
    String phone = '';
    return showDialog(
        barrierColor: Theme.of(context).colorScheme.tertiaryContainer,
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  right: -40.0,
                  top: -40.0,
                  child: InkResponse(
                    onTap: () {
                      if (kDebugMode) print('Dialog closed');
                      Navigator.of(context).pop();
                    },
                    child: CircleAvatar(
                      radius: 25.0,
                      backgroundColor: Theme.of(context).colorScheme.error,
                      child: const Icon(Icons.close),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Form(
                    key: _formKeyColleaguePopUp,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: TextFormField(
                            //inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9- ]'))],
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                //    border: OutlineInputBorder(),
                                icon: Icon(Icons.person),
                                // labelStyle: TextStyle(color:Theme.of(context).colorScheme.onTertiaryContainer),
                                labelText: 'Name (Required)'),
                            onChanged: (value) {
                              name = value.toString().trim();
                            },
                            validator: (value) {
                              return value.toString().isNotEmpty ? null : '*Required*';
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 8.0,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextFormField(
                            //inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-.@_ ]'))],
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(icon: Icon(Icons.alternate_email), labelText: 'Email (Required)'),
                            onChanged: (value) {
                              email = value.toString().toLowerCase().trim();
                            },
                            validator: (value) {
                              String pattern1 =
                                  r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
                              RegExp regex = RegExp(pattern1);
                              return (!regex.hasMatch(value ?? '')) ? 'Invalid email' : null;
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 8.0,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextFormField(
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9+]'))],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                //     border: OutlineInputBorder(),
                                icon: Icon(Icons.phone_android),
                                labelText: 'Phone (Optional)'),
                            onChanged: (value) {
                              phone = value.toString().trim();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () {
                              if (_formKeyColleaguePopUp.currentState!.validate()) {
                                Navigator.of(context).pop(Colleague(name: name, email: email, phone: phone, uniqueID: getuID()));
                              }
                            },
                            child: Container(
                              decoration:
                                  BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                              padding: const EdgeInsets.all(20.0),
                              margin: const EdgeInsets.only(left: 30.0, right: 30.0, top: 20.0, bottom: 20.0),
                              width: double.infinity,
                              child: Center(
                                  child: Text(
                                'ADD',
                                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 20.0),
                              )),
                            ),
                          ),
                        ),
                        Text('Enter the email your colleague uses to login to SnagSnapper on their device',
                            textAlign: TextAlign.center, style: GoogleFonts.montserrat(textStyle: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  void showSharedSitePopUp(Site siteShared) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Shared site found"),
          content: Text("Remove site sharing from site: '${siteShared.name}' first, before deleting this colleague"),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("  OK  ")),
          ],
        );
      },
    );
  }
}
