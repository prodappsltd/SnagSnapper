
import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Data/contentProvider.dart';

class BasicDateField extends StatelessWidget {
  final String dateFormat;
  final DateTime siteDate;
  final Function(DateTime?) dateChangeFunction;
  final bool newSite;

  const BasicDateField({super.key, required this.dateFormat, required this.siteDate, required this.newSite, required this.dateChangeFunction});

  @override
  Widget build(BuildContext context) {
    return DateTimeField(
      validator: (value)=> value == null? 'Value cannot be empty':null,
      enabled: newSite? true : false,
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16.0,
        fontFamily: "Roboto-Regular.ttf",
        fontStyle: FontStyle.normal,),
      initialValue: newSite? DateTime.now() : siteDate,
      onChanged: dateChangeFunction,
      decoration: InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary,)),
      resetIcon: Icon(Icons.clear,color: newSite? Theme.of(context).colorScheme.primary: Colors.white,),
      format: DateFormat(dateFormat),
      onShowPicker: (context, currentValue) {
        return showDatePicker(
            context: context,
            firstDate: DateTime(2019),
            initialDate: newSite? DateTime.now() : siteDate,
            lastDate: DateTime(2100));
      },
    );
  }
}