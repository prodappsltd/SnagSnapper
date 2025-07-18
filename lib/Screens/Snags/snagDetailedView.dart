import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/snag.dart';
import 'package:snagsnapper/Screens/Sites/SiteInfo/siteStatus.dart';
import 'package:snagsnapper/Screens/Snags/CreateEditSnag.dart';
import 'package:snagsnapper/Screens/showFullScreenImage.dart';
import 'package:snagsnapper/Widgets/markedImageStack.dart';
import 'package:snagsnapper/Widgets/smallImageSnags.dart';

class SnagDetailedView extends StatefulWidget {
  final Snag snag;
  final String siteID;
  final String siteOwnersEmail;
  const SnagDetailedView({Key? key, required this.snag, required this.siteID, required this.siteOwnersEmail}) : super(key: key);

  @override
  State<SnagDetailedView> createState() => _SnagDetailedViewState();
}

class _SnagDetailedViewState extends State<SnagDetailedView> {
  String getPhone(String assignedEmail, context) {
    String? phone;
    Provider.of<CP>(context, listen: false).getListOFColleagues().forEach((colleague) {
      if (colleague.email == assignedEmail) phone = colleague.phone;
    });
    return phone!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(TITLE_BAR_HEIGHT),
        child: AppBar(
          //backgroundColor: Theme.of(context).colorScheme.primary,
          title: Text('SNAG DETAILS', style: GoogleFonts.montserrat( textStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground)),),
          leading: IconButton(icon: Icon(Icons.arrow_back), color: Theme.of(context).colorScheme.onBackground, onPressed: ()=> Navigator.pop(context),),
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
                    MarkImageStack(
                      widget.snag.imageMain1!,
                      () async {
                        if (widget.snag.imageMain1!.isNotEmpty) {
                          Navigator.push(
                              context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(widget.snag.imageMain1!)));
                        }
                      },
                      (onValue) {},
                      false, //Don't show any annotation
                      'No main image found',
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        SmallImageSnags(
                          b64Image: widget.snag.image2!,
                          callBackFunc: () async {
                            if (widget.snag.image2 !.isNotEmpty) {
                              Navigator.push(
                                  context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(widget.snag.image2!)));
                            }
                          },
                          showAnnotation: false,
                          callBackMarkupIcon: () {},
                        ),
                        SmallImageSnags(
                          b64Image: widget.snag.image3!,
                          callBackFunc: () async {
                            if (widget.snag.image3 !.isNotEmpty) {
                              Navigator.push(
                                  context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(widget.snag.image3!)));
                            }
                          },
                          showAnnotation: false,
                          callBackMarkupIcon: () {},
                        ),
                        SmallImageSnags(
                          b64Image: widget.snag.image4!,
                          callBackFunc: () async {
                            if (widget.snag.image4 !.isNotEmpty) {
                              Navigator.push(
                                  context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(widget.snag.image4!)));
                            }
                          },
                          showAnnotation: false,
                          callBackMarkupIcon: () {},
                        ),
                      ],
                    ),
                    const Divider(),
                    const Center(child: Text('BRIEF')),
                    const SizedBox(
                      height: 10.0,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  Text(widget.snag.location, style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Theme.of(context).colorScheme.primary)),
                                ],
                              ),


                              Row(
                                children: [
                                  Icon(Icons.assignment_ind, color: Theme.of(context).colorScheme.primary),
                                  Text(widget.snag.assignedName!.isNotEmpty
                                      ? (widget.snag.assignedName!)
                                      : 'Not assigned',
                                    style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Theme.of(context).colorScheme.primary),
                                  ),
                                ],
                              ),

                              (widget.snag.creatorEmail == Provider.of<CP>(context, listen: false).getAppUser()!.email.toLowerCase() &&
                                  (widget.snag.assignedEmail!.isEmpty)) ||
                                  (widget.snag.ownerEmail == Provider.of<CP>(context, listen: false).getAppUser()!.email.toLowerCase())
                                  ? GestureDetector(
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => CreateSnag(
                                                    snag: widget.snag,
                                                    siteID: widget.siteID,
                                                    siteOwnersEmail: widget.siteOwnersEmail,
                                                  ))).then((value) => setState((){})),
                                      child: const CircleAvatar(
                                        backgroundColor: Colors.black,
                                        radius: 13.0,
                                        child: Icon(
                                          Icons.edit,
                                          size: 18.0,
                                          color: Colors.white,
                                        ),
                                      ))
                                  : const Text('')
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                children: [
                                  Icon(
                                    Icons.hourglass_empty,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  Text(
                                      widget.snag.dueDate != null
                                          ? DateFormat(Provider.of<CP>(context, listen: false).getDateFormat()).format(widget.snag.dueDate!)
                                          : ' No due-date ',
                                      style: TextStyle(
                                          fontFamily:'Roboto-Regular.ttf',
                                          fontWeight: FontWeight.bold,
                                          color: // GREATER THAN 5 DAYS
                                              widget.snag.dueDate == null
                                                  ? Colors.white
                                                  : widget.snag.dueDate!.difference(DateTime.now()).inDays >=
                                                          Provider.of<CP>(context, listen: false).greenCondition
                                                      ? Colors.green // LESS THAN 5 DAYS && GREATER THAN 2
                                                      : widget.snag.dueDate!.difference(DateTime.now()).inDays <=
                                                                  Provider.of<CP>(context, listen: false).greenCondition &&
                                                              widget.snag.dueDate!.difference(DateTime.now()).inDays >=
                                                                  Provider.of<CP>(context, listen: false).orangeCondition
                                                          ? Colors.orangeAccent // LESS THAN 2 DAYS
                                                          : widget.snag.dueDate!.difference(DateTime.now()).inDays <=
                                                                  Provider.of<CP>(context, listen: false).orangeCondition
                                                              ? Colors.red
                                                              : Colors.white,
                                          backgroundColor: widget.snag.dueDate == null
                                              ? Theme.of(context).colorScheme.primary
                                              : widget.snag.dueDate!.difference(DateTime.now()).inDays >=
                                                      Provider.of<CP>(context, listen: false).greenCondition
                                                  ? Colors.black // LESS THAN 5 DAYS && GREATER THAN 2
                                                  : widget.snag.dueDate!.difference(DateTime.now()).inDays <=
                                                              Provider.of<CP>(context, listen: false).greenCondition &&
                                                          widget.snag.dueDate!.difference(DateTime.now()).inDays >=
                                                              Provider.of<CP>(context, listen: false).orangeCondition
                                                      ? Colors.black // LESS THAN 2 DAYS
                                                      : widget.snag.dueDate!.difference(DateTime.now()).inDays <=
                                                              Provider.of<CP>(context, listen: false).orangeCondition
                                                          ? Colors.black
                                                          : Colors.black)),
                                ],
                              ),


                              Row(
                                children: [
                                  Icon(Icons.priority_high, color: widget.snag.priority == 2 ? Colors.red[800] : Theme.of(context).colorScheme.primary),
                                  Text(
                                    widget.snag.priority == 2 ? 'HIGH' : widget.snag.priority == 1 ? 'MEDIUM' : 'LOW',
                                    style: TextStyle(
                                        fontFamily:'Roboto-Regular.ttf',
                                        color: widget.snag.priority == 2
                                            ? Colors.red[800]
                                            : widget.snag.priority == 1 ? Colors.deepOrangeAccent : Theme.of(context).colorScheme.primary,
                                        fontWeight:
                                            widget.snag.priority == 2 || widget.snag.priority == 1 ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ],
                              ),


                              Row(
                                children: [
                                  Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary,),
                                  Text(
                                    DateFormat(Provider.of<CP>(context, listen: false).getDateFormat()).format(widget.snag.creationDate),
                                    style: TextStyle(
                                        fontFamily:'Roboto-Regular.ttf',
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),

                            ],
                          ),
                          const Divider(),
                          Row(children: <Widget>[
                            Text('Title: ',style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            Text(widget.snag.title.isEmpty ? 'No title assigned' : widget.snag.title,
                                style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.normal)),
                          ]),
                          const Divider(),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text('Description: ',style: TextStyle(fontFamily:'Roboto-Regular.ttf',color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            Flexible(
                              child: Text(widget.snag.description.isEmpty ? '...' : widget.snag.description,
                                  style: TextStyle(
                                    fontFamily:'Roboto-Regular.ttf',
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                            ),
                          ]),
                          kDebugMode
                              ? Column(
                            children: <Widget>[
                              const Divider(),
                              Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                                Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Flexible(
                                  child: Text('Site Owner: ${widget.snag.ownerEmail}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                      )),
                                ),
                              ]),
                              Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                                Icon(
                                  Icons.person,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Flexible(
                                  child: Text('Snag Creator: ${widget.snag.creatorEmail}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                      )),
                                ),
                              ]),
                              const Divider(),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    Icon(
                                      Icons.person,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    Flexible(
                                      child: Text(widget.snag.assignedEmail !=null && widget.snag.assignedEmail!.isNotEmpty? 'Assigned: ${widget.snag.assignedEmail}' : 'Not assigned to anyone',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                          )),
                                    ),
                                  ]),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    Icon(
                                      Icons.person,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    Flexible(
                                      child: Text('Logged-in: ${Provider.of<CP>(context, listen: false).getAppUser()!.email}',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  ])
                            ],
                          )
                              : const SizedBox(),
                        ],
                      ),
                    ),
                    kDebugMode ? const Divider() : const Text('') ,
                    widget.snag.assignedEmail?.toLowerCase() == Provider.of<CP>(context, listen: false).getAppUser()!.email.toLowerCase() ||
                        widget.snag.ownerEmail.toLowerCase() == Provider.of<CP>(context, listen: false).getAppUser()!.email.toLowerCase() ||
                        viewPermission
                        ? SnagFixImages(widget.snag)
                        : const Center(child: Text('This snag is not assigned to you')),
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

class SnagFixImages extends StatefulWidget {
  final Snag snag;
  const SnagFixImages(this.snag, {Key? key}) : super(key: key);

  @override
  _SnagFixImagesState createState() => _SnagFixImagesState();
}

class _SnagFixImagesState extends State<SnagFixImages> {
  late Snag snag;
  List<bool> showAnnotation = [false, false, false, false];
  String snagFixDescription = '';
  String snagFixMainImage = '';
  String snagFixImage1 = '';
  String snagFixImage2 = '';
  String snagFixImage3 = '';
  bool snagStatus = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    snag = widget.snag;
    snagFixDescription = snag.snagFixDescription!;
    snagFixMainImage = snag.snagFixMainImage!;
    snagFixImage1 = snag.snagFixImage1!;
    snagFixImage2 = snag.snagFixImage2!;
    snagFixImage3 = snag.snagFixImage3!;
    snagStatus = snag.snagStatus;
    if (snagFixMainImage.isNotEmpty) showAnnotation[0] = true;
    if (snagFixImage1.isNotEmpty) showAnnotation[1] = true;
    if (snagFixImage2.isNotEmpty) showAnnotation[2] = true;
    if (snagFixImage3.isNotEmpty) showAnnotation[3] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(child: Text(viewPermission? 'VIEW SNAG STATUS':'PLEASE COMPLETE THE WORKSHEET BELOW', style: const TextStyle(fontFamily:'Roboto-Regular.ttf',fontWeight: FontWeight.bold),)),
        ),
        MarkImageStack(
          snagFixMainImage,
          viewPermission? (){}:() async {
            String image;
            snagFixMainImage.isEmpty
                ? image = await optionsDialogBox(context, 1000)?? snagFixMainImage
                : image = await optionsDialogBoxWithDEL(context, () {
                    setState(() {
                      image = '';
                      snagFixMainImage = '';
                      showAnnotation[0] = false;
                    });
                    Navigator.pop(context);
                  })?? snagFixMainImage;
            if (image.isNotEmpty) {
              setState(() => snagFixMainImage = image);
              setState(() => showAnnotation[0] = true);
            }
          },
          (onValue) {
            if (onValue != null) snagFixMainImage = onValue;
          },
          snagFixMainImage .isEmpty ? false : true, //Don't show any annotation
          viewPermission? 'No image to show':'Click to add Image',
        ),
        Container(
          padding: const EdgeInsets.all(20.0),
          margin: const EdgeInsets.only(left: 0.0, right: 0.0, top: 10.0, bottom: 15.0),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
              boxShadow: [
                BoxShadow(color: Colors.grey, offset: Offset(0.0, 0.0), blurRadius: 5.0, spreadRadius: 1.0)
              ]),
          child: Column(
            children: <Widget>[
              Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                    TextFormField(
                      validator: (value) {
                        return !snagStatus? value.toString().isEmpty ? '* Required *' : null : null;
                      },
                      readOnly: viewPermission? true:false,
                    onChanged: (value) => viewPermission? null:snagFixDescription = value.toString().trim(),
                    autocorrect: true,
                      style: const TextStyle(fontFamily:'Roboto-Regular.ttf',),
                    initialValue: snagFixDescription,
                    decoration: InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(
                          Icons.description,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ),
                    maxLines: 1,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.text,
                  ),
                      const SizedBox(
                        height: 30.0,
                      ),
                      Column(
                        children: <Widget>[
                          Text(viewPermission? 'Supporting photos':'Add supporting photos (Optional)'),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              SmallImageSnags(
                                b64Image: snagFixImage1,
                                callBackFunc: viewPermission? (){}:() async {
                                  String image;
                                  snagFixImage1 .isEmpty
                                      ? image = await optionsDialogBox(context, 1000)?? snagFixImage1
                                      : image = await optionsDialogBoxWithDEL(context, () {
                                          image = '';
                                          snagFixImage1 = '';
                                          setState(() => snagFixImage1);
                                          setState(() => showAnnotation[1] = false);
                                          Navigator.pop(context);
                                        })?? snagFixImage1;
                                  if (image.isNotEmpty) {
                                    setState(() => snagFixImage1 = image);
                                    setState(() => showAnnotation[1] = true);
                                  }
                                },
                                showAnnotation: snagFixImage1.isEmpty ? false : true,
                                callBackMarkupIcon: () {
                                  Navigator.push(
                                      context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(snagFixImage1)));
//                                    Navigator.push(
//                                            context, MaterialPageRoute(builder: (context) => Markup(snagFixImage1)))
//                                        .then((onValue) => (onValue != null) ? snagFixImage1 = onValue : null);
                                },
                              ),
                              SmallImageSnags(
                                b64Image: snagFixImage2,
                                callBackFunc: viewPermission? (){}:() async {
                                  String image;
                                  snagFixImage2.isEmpty
                                      ? image = await optionsDialogBox(context, 1000)?? snagFixImage2
                                      : image = await optionsDialogBoxWithDEL(context, () {
                                          image = '';
                                          setState(() => snagFixImage2 = '');
                                          setState(() => showAnnotation[2] = false);
                                          Navigator.pop(context);
                                        })?? snagFixImage2;
                                  if (image.isNotEmpty) {
                                    setState(() => snagFixImage2 = image);
                                    setState(() => showAnnotation[2] = true);
                                  }
                                },
                                showAnnotation: snagFixImage2.isEmpty ? false : true,
                                callBackMarkupIcon: () {
                                  Navigator.push(
                                      context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(snagFixImage2)));

                                  //                                    Navigator.push(
//                                            context, MaterialPageRoute(builder: (context) => Markup(snagFixImage2)))
//                                        .then((onValue) => (onValue != null) ? snagFixImage2 = onValue : null);
                                },
                              ),
                              SmallImageSnags(
                                b64Image: snagFixImage3,
                                callBackFunc: viewPermission? (){}:() async {
                                  String image;
                                  snagFixImage3 .isEmpty
                                      ? image = await optionsDialogBox(context, 1000)?? snagFixImage3
                                      : image = await optionsDialogBoxWithDEL(context, () {
                                          image = '';
                                          setState(() => snagFixImage3 = '');
                                          setState(() => showAnnotation[3] = false);
                                          Navigator.pop(context);
                                        })?? snagFixImage3;
                                  if (image.isEmpty) {
                                    setState(() => snagFixImage3 = image);
                                    setState(() => showAnnotation[3] = true);
                                  }
                                },
                                showAnnotation: snagFixImage3.isEmpty ? false : true,
                                callBackMarkupIcon: () {
                                  Navigator.push(
                                      context, MaterialPageRoute(builder: (context) => ShowFullScreenImage(snagFixImage3)));

//                                    Navigator.push(
//                                            context, MaterialPageRoute(builder: (context) => Markup(snagFixImage3)))
//                                        .then((onValue) => (onValue != null) ? snagFixImage3 = onValue : null);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 20.0,
                          ),
                          Text('Snag Status', style: GoogleFonts.montserrat(textStyle: const TextStyle(fontSize: 22)),),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              TextButton(
                                onPressed: viewPermission? (){}:() {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    snagStatus = true;
                                  });
                                },
                                // color: snagStatus == true ? Provider.of<UserData>(context, listen: false).getMainColor() : Colors.white,
                                // shape: RoundedRectangleBorder(
                                //   borderRadius: const BorderRadius.only(
                                //       topLeft: Radius.circular(10.0), bottomLeft: Radius.circular(10.0)),
                                //   side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                // ),
                                child: Text(
                                  'OPEN',
                                  style: GoogleFonts.roboto(textStyle: TextStyle(fontSize: snagStatus? 22:16, fontWeight: snagStatus? FontWeight.w800 : FontWeight.normal,color: snagStatus? Colors.black : Theme.of(context).colorScheme.primary)),
                                ),
                              ),
                              TextButton(
                                onPressed: viewPermission? (){}:() {
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    snagStatus = false;
                                  });
                                },
                                // color: snagStatus == false ? Provider.of<UserData>(context, listen: false).getMainColor() : Colors.white,
                                // shape: RoundedRectangleBorder(
                                //   borderRadius: const BorderRadius.only(
                                //       topRight: Radius.circular(10.0), bottomRight: Radius.circular(10.0)),
                                //   side: BorderSide(color: Provider.of<UserData>(context, listen: false).getMainColor(), width: 1.0),
                                // ),
                                child: Text(
                                  'CLOSE',
                                  style: GoogleFonts.roboto(textStyle: TextStyle(fontSize: !snagStatus? 22:16,fontWeight: !snagStatus? FontWeight.w800 : FontWeight.normal,color: !snagStatus? Colors.black : Theme.of(context).colorScheme.primary)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )),
              const SizedBox(
                height: 10.0,
              ),
              GestureDetector(
                onTap: viewPermission? (){Navigator.pop(context);}:() {
                  FocusScope.of(context).requestFocus(FocusNode());
                  if (_formKey.currentState!.validate()) {


                    if (snagFixMainImage != snag.snagFixMainImage) snag.snagFixMainImage = snagFixMainImage;
                    if (snagFixImage1 != snag.snagFixImage1) snag.snagFixImage1 = snagFixImage1;
                    if (snagFixImage2 != snag.snagFixImage2) snag.snagFixImage2 = snagFixImage2;
                    if (snagFixImage3 != snag.snagFixImage3) snag.snagFixImage3 = snagFixImage3;
                    if (snagFixDescription != snag.snagFixDescription) snag.snagFixDescription = snagFixDescription;
                    if (snagStatus != snag.snagStatus) snag.snagStatus = snagStatus;
                    if (Provider.of<CP>(context, listen: false).getAppUser()!.email.toLowerCase() == snag.ownerEmail.toLowerCase()){
                      if (!snag.snagStatus) snag.snagConfirmedStatus = false;
                      if (snag.snagStatus && !snag.snagConfirmedStatus) snag.snagConfirmedStatus = true;
                    }

                    Provider.of<CP>(context, listen: false).updateSnag(snag);
                    if(kDebugMode) print('SNAG-status: ${snag.snagStatus}');
                    if(kDebugMode) print('SNAG-Confirmed-status: ${snag.snagConfirmedStatus}');

                    Navigator.pop(context);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(color: activeBTN, borderRadius: const BorderRadius.all(Radius.circular(10.0))),
                  padding: const EdgeInsets.all(20.0),
                  margin: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
                  width: double.infinity,
                  child: Center(
                      child: Text(
                        viewPermission? 'GO BACK':Provider.of<CP>(context, listen: false).getAppUser()!.email.toString().toLowerCase().trim() != snag.ownerEmail.toLowerCase().trim()? 'SAVE':'CONFIRM',
                    style: const TextStyle(fontFamily:'Roboto-Regular.ttf',color: Colors.white, fontSize: 20.0),
                  )),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
