
import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/snag.dart';
import 'package:snagsnapper/Screens/Markup/markup.dart';
import 'package:snagsnapper/Widgets/markedImageStack.dart';
import 'package:snagsnapper/Widgets/smallImageSnags.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../Data/site.dart';
import '../../Widgets/ActionButton.dart';


class CreateSnag extends StatefulWidget {
  final Snag? snag;
  final String siteID;
  final String siteOwnersEmail;

  const CreateSnag({Key? key, required this.snag, required this.siteID, required this.siteOwnersEmail}) : super(key: key);

  @override
  _CreateSnagState createState() => _CreateSnagState();
}

class _CreateSnagState extends State<CreateSnag> {
  bool showAnnotation = false;
  Snag? snag;
  late String siteID;
  late String siteOwnersEmail;
  late String mainImage1;

  @override
  void initState() {
    super.initState();
    siteID = widget.siteID;
    siteOwnersEmail = widget.siteOwnersEmail;
    snag = widget.snag;
    if (snag != null) {
      mainImage1 = snag!.imageMain1?? '';
    } else {
      mainImage1 = '';
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,

    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          //getbackgroundColor: Theme.of(context).colorScheme.primary,
          title: Text(snag == null ? 'ADD SNAG' : ' EDIT SNAG'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: IntrinsicHeight(
              child: Container(
                margin: EdgeInsets.only(left: 10.0, right: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    MarkImageStack(
                      mainImage1,
                      () async {
                        String image = '';
                        mainImage1.isEmpty
                            ? image = await optionsDialogBox(context, 1000)?? mainImage1
                            : image = await optionsDialogBoxWithDEL(context, () {
                                setState(() {
                                  image = '';
                                  mainImage1 = '';
                                  showAnnotation = false;
                                });
                                Navigator.pop(context);
                              })?? mainImage1;
                        if (image.isNotEmpty) {
                          setState(() => mainImage1 = image);
                          setState(() => showAnnotation = true);
                        }
                      },
                      (onValue) {
                        if (onValue != null) mainImage1 = onValue;
                      },
                      false, // TODO - Once annotation implemented, uncomment bottom line
                      //mainImage1 == null ? false : true, // Show annotation icon criteria
                      'Add main picture \nof your snag',
                    ),
                    SnagForm(snag:snag, mainImage1:mainImage1, siteID:siteID, siteOwnersEmail:siteOwnersEmail),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SnagForm extends StatefulWidget {
  final Snag? snag;
  final String siteID;
  final String siteOwnersEmail;
  final String mainImage1;
  SnagForm({required this.snag, required this.mainImage1, required this.siteID, required this.siteOwnersEmail});

  @override
  _SnagFormState createState() => _SnagFormState();
}

class _SnagFormState extends State<SnagForm> {
  Snag? snag;
  final _formKey = GlobalKey<FormState>();
  List<bool> showAnnotation = [false, false, false];



  String preAssEmail = '';
  String location = '';
  String title = '';
  int priority = 0;
  String detailedDescription = '';
  String assignedName = '';
  String assignedEmail = '';
  String image2 = '';
  String image3 = '';
  String image4 = '';

  bool newSnag = false;
  late DateTime? dueDate;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    snag = widget.snag;
    if (snag != null) {
      image2 = snag!.image2 ?? '';
      image3 = snag!.image3 ?? '';
      image4 = snag!.image4 ?? '';
      title = snag!.title;
      dueDate = snag!.dueDate;
      priority = snag!.priority;
      detailedDescription = snag!.description;
      location = snag!.location;
      assignedEmail = snag!.assignedEmail ?? '';
      assignedName = snag!.assignedName ?? '';
    } else {
      newSnag = true;
      dueDate = null;
    }
    if (newSnag) priority = 0;
  }

  bool _checkIfOwner(){
    if (Provider.of<CP>(context,listen: false).getAppUser()!.email.toLowerCase()
        == widget.siteOwnersEmail.toLowerCase()){
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(left: 0.0, right: 0.0, top: 10.0, bottom: 15.0),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
          boxShadow: [BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0), blurRadius: 5.0, spreadRadius: 1.0)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[

                  TextFormField(
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z-0-9 ]'))],
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    initialValue: location,
                    decoration: InputDecoration(
                      //    border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary),
                        labelText: 'Location/Room No. (Required)'),
                    onChanged: (value) {
                      location = value.toString().trim();
                    },
                    validator: (value) {
                      return value.toString().isEmpty? '* Required *' : null;
                    },
                  ),

                  TextFormField(
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z-0-9 ]'))],
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    initialValue: title,
                    decoration: InputDecoration(
                      //    border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title, color: Theme.of(context).colorScheme.primary),
                        labelText: 'Title (Required)'),
                    onChanged: (value) {
                      title = value.toString().trim();
                    },
                    validator: (value) {
                      return value.toString().isEmpty? '* Required *' : null;
                    },
                  ),


                  TextFormField(
                    style: const TextStyle(fontFamily:'Roboto-Regular.ttf',),
                    decoration: InputDecoration(
                      labelText: 'Detailed description',
                      prefixIcon: Icon(
                        Icons.description,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    autocorrect: true,
                    textInputAction: TextInputAction.done ,
                    onChanged: (value) => detailedDescription = value.toString().trim(),
                    validator: (value) {
                      return value.toString().isEmpty ? '* Required *' : null;
                    },
                    initialValue: detailedDescription,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardAppearance: Brightness.dark,
                    maxLines: 5,
                    //expands: true,
                  ),
                  const SizedBox(
                    height: 30.0,
                  ),
                  Column(
                    children: <Widget>[
                      Center(
                        child: _checkIfOwner()? Text('PRIORITY') : Text(''),
                      ),
                      _checkIfOwner()
                          ? Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  priority = 0;
                                  if (kDebugMode) print ('Priority: $priority');
                                });
                              },
                              // color: priority == 0 ? Provider.of<UserData>(context, listen:false).getMainColor() : Colors.white,
                              // shape: RoundedRectangleBorder(
                              //   borderRadius: const BorderRadius.only(
                              //       topLeft: Radius.circular(10.0), bottomLeft: Radius.circular(10.0)),
                              //   side: BorderSide(color: Provider.of<UserData>(context, listen:false).getMainColor(), width: 1.0),
                              // ),
                              child: Text(
                                'LOW',
                                style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: priority == 0 ? Colors.white : Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  priority = 1;
                                  if (kDebugMode) print ('Priority: $priority');
                                });
                              },
                              // color: priority == 1 ? Provider.of<UserData>(context, listen:false).getMainColor() : Colors.white,
                              // shape: RoundedRectangleBorder(
                              //   side: BorderSide(color: Provider.of<UserData>(context, listen:false).getMainColor(), width: 1.0),
                              // ),
                              child: Text(
                                'MEDIUM',
                                style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: priority == 1 ? Colors.white : Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  priority = 2;
                                  if (kDebugMode) print ('Priority: $priority');
                                });
                              },
                              // color: priority == 2 ? Provider.of<UserData>(context, listen:false).getMainColor() : Colors.white,
                              // shape: RoundedRectangleBorder(
                              //   borderRadius: const BorderRadius.only(
                              //       topRight: Radius.circular(10.0), bottomRight: Radius.circular(10.0)),
                              //   side: BorderSide(color: Provider.of<UserData>(context, listen:false).getMainColor(), width: 1.0),
                              // ),
                              child: Text(
                                'HIGH',
                                style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: priority == 2 ? Colors.white : Theme.of(context).colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ) : const Text(''),
                      SizedBox(
                        height: _checkIfOwner()? 20.0 : 0.0,
                      ),
                      const Divider(),
                      const Text('Add supporting photos (Optional)'),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          SmallImageSnags(
                            b64Image: image2,
                            callBackFunc: () async {
                              String image;
                              image2.isEmpty
                                  ? image = await optionsDialogBox(context, 1000)?? image2
                                  : image = await optionsDialogBoxWithDEL(context, () {
                                      image = '';
                                      setState(() => image2 = '');
                                      setState(() => showAnnotation[0] = false);
                                      Navigator.pop(context);
                                    })?? image2;
                              if (image.isNotEmpty) {
                                setState(() => image2 = image); // TODO Two set states?
                                setState(() => showAnnotation[0] = true);
                              }
                            },
                            showAnnotation: false,//image2 == null ? false : true,
                            callBackMarkupIcon: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => Markup(image2)))
                                  .then((onValue) => (onValue != null) ? image2 = onValue : null);
                            },
                          ),
                          SmallImageSnags(
                            b64Image: image3,
                            callBackFunc: () async {
                              String image;
                              image3 . isEmpty
                                  ? image = await optionsDialogBox(context, 1000)?? image3
                                  : image = await optionsDialogBoxWithDEL(context, () {
                                      image = '';
                                      setState(() => image3 = '');
                                      setState(() => showAnnotation[1] = false);
                                      Navigator.pop(context);
                                    })?? image3;
                              if (image .isNotEmpty) {
                                setState(() => image3 = image);
                                setState(() => showAnnotation[1] = true);
                              }
                            },
                            showAnnotation: false,//image3 == null ? false : true,
                            callBackMarkupIcon: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => Markup(image3)))
                                  .then((onValue) => (onValue != null) ? image3 = onValue : null);
                            },
                          ),
                          SmallImageSnags(
                            b64Image: image4,
                            callBackFunc: () async {
                              String image;
                              image4 . isEmpty
                                  ? image = await optionsDialogBox(context, 1000)?? image4
                                  : image = await optionsDialogBoxWithDEL(context, () {
                                      image = '';
                                      setState(() => image4 = '');
                                      setState(() => showAnnotation[2] = false);
                                      Navigator.pop(context);
                                    })?? image4;
                              if (image . isNotEmpty) {
                                setState(() => image4 = image);
                                setState(() => showAnnotation[2] = true);
                              }
                            },
                            showAnnotation: false,//image4 == null ? false : true,
                            callBackMarkupIcon: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => Markup(image4)))
                                  .then((onValue) => (onValue != null) ? image4 = onValue : null);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              )
          ),
          _checkIfOwner()?
              Column(
                children: <Widget>[
                  const Divider(),
                  const SizedBox(
                    height: 5.0,
                  ),
                  const Center(child: Text('ASSIGN SNAG')),
                  const Center(child: Text('(Select One)')),
                  const Divider(),
                  Provider.of<CP>(context).getMapOfAllSites()[widget.siteID].sharedWith.length < 1
                      ? const Center(
                      child: Text(
                        'To assign this SNAG, please share the site first!',
                        textAlign: TextAlign.center,
                      ))
                      : Container(
                    width: double.infinity,
                    height: 200.0,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                    child: Center(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: Provider.of<CP>(context).getMapOfAllSites()[widget.siteID].sharedWith.length,
                          itemBuilder: (BuildContext context, int position) {
                            return AssignChkBoxView( // TODO - Add an option for NONE so snag is assigned to no-one.
                                sharedWith: getSharedList(),
                                function: (value) { // This is the bool value
                                  setState(() {
                                    if (value != null && value && Provider.of<CP>(context, listen: false).getMapOfAllSites()[widget.siteID].sharedWith.keys.toList()[position] == FirebaseAuth.instance.currentUser!.email) {
                                      assignedEmail = FirebaseAuth.instance.currentUser!.email!;
                                      assignedName = Provider.of<CP>(context, listen: false).getAppUser()!.name;
                                    } else if (value != null && value) {
                                      assignedName = _getNameOfColleague((Provider.of<CP>(context, listen: false).getMapOfAllSites()[widget.siteID]).sharedWith.keys.toList()[position])?? 'Error';
                                      assignedEmail = Provider.of<CP>(context, listen: false).getMapOfAllSites()[widget.siteID].sharedWith.keys.toList()[position];
                                    }
                                    //if (preAssEmail == assignedEmail) {
                                    if (value != null && !value )assignedEmail = '';
                                    if (value != null && !value )assignedName = '';
                                    //} else {
                                      //preAssEmail = assignedEmail;
                                    //}
                                  });
                                },
                                emailSelected: assignedEmail,
                                listOfColleagues: Provider.of<CP>(context).getListOFColleagues(),
                                email: Provider.of<CP>(context)
                                    .getMapOfAllSites()[widget.siteID]
                                    .sharedWith
                                    .keys
                                    .toList()[position]);
                          },
                        )),
                  ),
                ],
              ) : const Text(''),
          _checkIfOwner()
              ? Container(
            width:double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            child: BasicDateField(
                format : Provider.of<CP>(context, listen:false).getDateFormat(),
                dueDate : dueDate,
                dateChangeFunction :(value){if (value!=null) setState(() => dueDate = value);
            }),
          ): const Text(''),
          newSnag? const Text(''):Text('Created - ${DateFormat(Provider.of<CP>(context, listen:false).getDateFormat()).format(snag!.creationDate)}'),
          GestureDetector(
            onTap: () async {
              FocusScope.of(context).requestFocus(FocusNode());
              if (_formKey.currentState!.validate()) {
                setState(() => busy = true);
                if (kDebugMode) {
                  print('---------------------LOCAL LOCAL------------------------');
                  print('Location - $location');
                  print('Title - $title');
                  print('Description - $detailedDescription');
                  print('Priority - $priority');
                  print('DueDate - $dueDate');
                  widget . mainImage1.isNotEmpty ? print('MainImage1 present') : print('MainImage1  NOT present');
                  image2 . isNotEmpty ? print('Image2 present') : print('Image2 NOT present');
                  image3 . isNotEmpty ? print('Image3 present') : print('Image3 NOT present');
                  image4 . isNotEmpty ? print('Image4 present') : print('Image4 NOT present');
                  print('---------------------SNAG SNAG------------------------');
                  if (snag != null) {
                    snag!.imageMain1!.isNotEmpty ? print('MainImage1 present') : print('MainImage1  NOT present');
                    print('Location - ${snag!.location}');
                    print('Title - ${snag!.title}');
                    print('Description - ${snag!.description}');
                    print('Priority - ${snag!.priority}');
                    snag!.image2 !. isNotEmpty ? print('Image2 present') : print('Image2 NOT present');
                    snag!.image3 !. isNotEmpty ? print('Image3 present') : print('Image3 NOT present');
                    snag!.image4 !. isNotEmpty ? print('Image4 present') : print('Image4 NOT present');
                  }
                }

                if (snag == null) {
                  snag = Snag(
                    location: location,
                    title: title,
                    priority: priority,
                    description: detailedDescription,
                    creatorEmail: Provider.of<CP>(context, listen:false).getAppUser()!.email.toLowerCase(),
                    assignedEmail: assignedEmail,
                    assignedName: assignedName,
                    uID: Uuid().v4(),
                    siteUID: widget.siteID,
                    dueDate: dueDate,
                    creationDate: DateTime.now(),
                    ownerEmail: widget.siteOwnersEmail,
                    imageMain1: widget.mainImage1,
                    image2: image2,
                    image3: image3,
                    image4: image4,
                    snagStatus: true,
                    snagConfirmedStatus: true,
                  );
                  if (kDebugMode) print('Creator email = ${Provider.of<CP>(context, listen:false).getAppUser()!.email}');
                  await Provider.of<CP>(context, listen:false).addSnag(snag!);

                } else {

                  if (widget.mainImage1 != snag!.imageMain1) snag!.imageMain1 = widget.mainImage1;
                  if (image2 != snag!.image2) snag!.image2 = image2;
                  if (image3 != snag!.image3) snag!.image3 = image3;
                  if (image4 != snag!.image4) snag!.image4 = image4;
                  if (dueDate != snag!.dueDate) snag!.dueDate = dueDate;
                  if (location != snag!.location) snag!.location = location;
                  if (title != snag!.title) snag!.title = title;
                  if (detailedDescription != snag!.description) snag!.description = detailedDescription;
                  if (priority != snag!.priority) snag!.priority = priority;
                  if (snag!.assignedEmail != assignedEmail) snag!.assignedEmail = assignedEmail;
                  if (snag!.assignedName != assignedName) snag!.assignedName = assignedName;
                  await Provider.of<CP>(context, listen:false).updateSnag(snag!);

                }
                setState(() => busy = false);
                Navigator.pop(context,snag);
              }
            },
            child: ActButton(busy: busy, text: 'Save'),
          )
        ],
      ),
    );
  }

  String? _getNameOfColleague(String email) {
    List<Colleague> colleagues = Provider.of<CP>(context, listen:false).getListOFColleagues();
    String? name;
    for (int i = 0; i < colleagues.length; i++) {
      if (colleagues[i].email.toString().toLowerCase() == email.toLowerCase()) {
        name = colleagues[i].name;
        break;
      }
    }
    return name;
  }

  getSharedList() => (Provider.of<CP>(context).getSite(widget.siteID) as Site).sharedWith;

}



class BasicDateField extends StatelessWidget {
  final String format;
  final DateTime? dueDate;
  final Function(DateTime?) dateChangeFunction;

  const BasicDateField({Key? key, required this.format, required this.dueDate, required this.dateChangeFunction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DateTimeField(
      style: const TextStyle(fontFamily:'Roboto-Regular.ttf',),
      initialValue: dueDate,
      onChanged: dateChangeFunction,
      decoration: InputDecoration(labelText: 'DUE BY DATE', prefixIcon: Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary,)),
      resetIcon: Icon(Icons.clear,color: Theme.of(context).colorScheme.primary,),
      format: DateFormat(format),
      onShowPicker: (context, currentValue) {
        return showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            initialDate: dueDate !=null ? dueDate! : DateTime.now(),
            lastDate: DateTime(2100)
        );
      },
    );
  }
}

class AssignChkBoxView extends StatelessWidget {
  final String email;
  final Map<String, String> sharedWith;
  final List<Colleague> listOfColleagues;
  final String emailSelected;
  final Function(bool?) function;
  const AssignChkBoxView({
    required this.sharedWith,
    required this.email,
    required this.emailSelected,
    required this.function,
    required this.listOfColleagues
  });



  String _getNameOfColleague(String email, BuildContext context) {
    //TODO - CHECK IF VIEW PERMISSION IS THERE then don;t show that as option
    if (kDebugMode) print ('Getting name....Email received: $email');
    String? name;
    for (int i = 0; i < listOfColleagues.length; i++) {
      if(kDebugMode) print('EMAIL: ${listOfColleagues[i].email}  NAME: ${listOfColleagues[i].name}');
      if (listOfColleagues[i].email.toLowerCase() == email.toLowerCase()) {
        name = listOfColleagues[i].name;
        if (kDebugMode) print(listOfColleagues[i].name);
        break;
      }
    }
    if (name == null) {
      if (Provider.of<CP>(context, listen:false).getAppUser()!.email == email) name = Provider.of<CP>(context, listen:false).getAppUser()!.name;
    }
    return name?? 'Error 3';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(10.0))),
      padding: const EdgeInsets.only(left: 10.0, right: 0.0),
      margin: const EdgeInsets.only(left: 5.0, top: 10.0, right: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(child: Text('${_getNameOfColleague(email, context)}\n$email', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily:'Roboto-Regular.ttf',),)),
          !(sharedWith[email] == 'VIEW')?
          // Radio(
          //   value: email,
          //   groupValue: emailSelected,
          //   onChanged: function,
          // )
          Checkbox(
            value: email == emailSelected,
//            groupValue: emailSelected,
            onChanged: function,
          ) : const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('View\nOnly', textAlign: TextAlign.center, style: TextStyle(color: Colors.red),),
          )
        ],
      ),
    );
  }
}
