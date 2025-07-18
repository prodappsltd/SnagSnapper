import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/snag.dart';

class SnagCardView extends StatelessWidget {
  final Snag snag;
  final VoidCallback callBack;


  const SnagCardView({required this.snag,required this.callBack, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: callBack,
      //key: key,
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: SizedBox(
          height: 100.0,
          child: Row(
            children: <Widget>[
              Container(
                width: 100.0,
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(5.0), bottomLeft: Radius.circular(5.0)),
                    image: DecorationImage(
                      image: snag.imageMain1!.isNotEmpty
                          ? MemoryImage(base64Decode(snag.imageMain1!))
                          : const AssetImage('images/1024LowPoly.png') as ImageProvider,
                      fit: BoxFit.cover,
                    )),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Row(children: <Widget>[
                        Icon(
                          Icons.location_on,
                          size: 20.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        Text(' ${snag.location}', style: const TextStyle(
                            fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                            fontFamily: "Roboto-Bold.ttf"),),
                      ]
                      ),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today,
                            size: 20.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            snag.dueDate == null
                                ? ' No due-date assigned'
                                : ' ${DateFormat(Provider.of<CP>(context).getDateFormat()).format(snag.dueDate!)}',
                            style: const TextStyle(
                                fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                            fontFamily: "Roboto-Bold.ttf")
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.person,
                            size: 20.0,
                            color: snag.assignedEmail?.toLowerCase()==Provider.of<CP>(context).getAppUser()!.email.toLowerCase()? Colors.green[600] : Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            snag.assignedName == null || snag.assignedName!.isEmpty ? ' Not assigned  ' : ' ${snag.assignedName!}  ',
                              style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.normal,
                                  fontFamily: "Roboto-Bold.ttf")),
                          Icon(
                            Icons.add_alert,
                            size: 20.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            snag.priority == 0 ? ' Low' : snag.priority == 1 ? ' Medium' : ' High',
                              style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.normal,
                                  fontFamily: "Roboto-Bold.ttf")
                          ),
                          Text(
                            !snag.snagStatus && !snag.snagConfirmedStatus ? ' (closed)' : '',
                              style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: snag.priority >1 ? FontStyle.italic:FontStyle.normal,
                                  fontFamily: "Roboto-Bold.ttf")
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Container(
                width: 10.0,
                decoration: BoxDecoration(
                  // snagConfirmedStatus will be false once it is closed confirmed
                  color: !snag.snagConfirmedStatus? Colors.white : snag.dueDate == null? Colors.white : snag.dueDate!.difference(DateTime.now()).inDays >= Provider.of<CP>(context).greenCondition
                      ? greenCardView // LESS THAN 5 DAYS && GREATER THAN 2
                      : snag.dueDate!.difference(DateTime.now()).inDays <=
                      Provider.of<CP>(context).greenCondition &&
                      snag.dueDate!.difference(DateTime.now()).inDays >=
                          Provider.of<CP>(context).orangeCondition
                      ? orangeCardView // LESS THAN 2 DAYS
                      : snag.dueDate!.difference(DateTime.now()).inDays <=
                      Provider.of<CP>(context).orangeCondition
                      ? redCardView
                      : Colors.white,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(5.0), bottomRight: Radius.circular(5.0))
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
