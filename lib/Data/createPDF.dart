import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
// TODO: OLD Site model deleted - migrate to NEW Site model
// import 'package:snagsnapper/Data/site.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:snagsnapper/Data/models/app_user.dart';
import 'dart:io';

import 'package:uuid/uuid.dart';

class CreatePDF {
  final BuildContext _context;
  final Site _site;
  final List<Snag> _snags;
  final AppUser _user;
  final Color _color;

  pw.MemoryImage? _logo;
  late pw.MemoryImage _noPiclogo;
  late pw.MemoryImage snagSnapperLogoImage;
  late pw.MemoryImage iOSLogoImage;
  late pw.MemoryImage androidLogoImage;

  int counter = 1;
  late PdfColor mainOrng;
  CreatePDF(this._context, this._site, this._snags, this._user, this._color);

  Future<String> createPDF() async {
    mainOrng = PdfColor.fromInt(_color.value);
    final doc = pw.Document(title: 'Site Report', author: _user.name);
    // TODO: Migrate to NEW Site model - use imageLocalPath instead of image (base64)
    // OLD code used: _site.image (base64 string)
    // NEW model uses: _site.imageLocalPath (file path)
    if (_site.imageLocalPath != null && _site.imageLocalPath!.isNotEmpty) {
      final file = File(_site.imageLocalPath!);
      if (file.existsSync()) {
        _logo = pw.MemoryImage(file.readAsBytesSync());
      }
    }

    snagSnapperLogoImage = pw.MemoryImage(
      //doc.document,
      //bytes:
      (await rootBundle.load('images/1024LowPoly.png')).buffer.asUint8List(),
    );
    iOSLogoImage = pw.MemoryImage(
      (await rootBundle.load('images/apple.png')).buffer.asUint8List(),
    );
    androidLogoImage = pw.MemoryImage(
      (await rootBundle.load('images/android.png')).buffer.asUint8List(),
    );
    _noPiclogo = pw.MemoryImage(
      //doc.document,
      //bytes:
      (await rootBundle.load('images/noPic.png')).buffer.asUint8List(),
    );

    doc.addPage(pw.MultiPage(
        pageTheme: await _buildTheme(),
        footer: _buildFooter,
        build: (pw.Context context) {
          return <pw.Widget>[
            _getFirstPage(doc),
            pw.Column(children: _getSnags(doc)),
          ];
        }));

    Directory docAppDirectory = await getApplicationDocumentsDirectory();
    //Directory docTempDirectory = await getTemporaryDirectory();
    String path = docAppDirectory.path;
    await Directory('$path/${_site.id}').create().then((value) async {
      DateTime time = DateTime.now();
      String temp = DateFormat('dd-MMMM-yyyy_HH:mm_ss').format(time);
      String name = '$temp.pdf';
      if (kDebugMode) print('File Created with name: $name');
      File file = File('$path/${_site.id}/$name');
      path = '$path/${_site.id}/$name';
      if (kDebugMode) print('File in CreatePDF: $path');
      await file.writeAsBytes(await doc.save());
      if (kDebugMode) print('File Exists : ${await file.exists()}');
    });
    return path;
  }

  pw.Widget _buildFooter(pw.Context context) {
    if (context.pageNumber == 1) return pw.Container();
    return pw.Column(children: <pw.Widget>[
      pw.SizedBox(height: 1, child: pw.Container(color: mainOrng)),
      pw.SizedBox(height: 5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(children: <pw.Widget>[
            pw.Container(
              height: 50,
              width: 50,
              decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5.0)),
//                color: PdfColors.green900,
                  image: pw.DecorationImage(
                      alignment: pw.Alignment.center, image: snagSnapperLogoImage, fit: pw.BoxFit.cover)),
//            pw.BarcodeWidget(
//              barcode: pw.Barcode.qrCode(),
//              data: 'Created On SnagSnapper',
//            ),
            ),


          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                height: 20,
                width: 80,
                alignment: pw.Alignment.centerLeft,
                //margin: pw.EdgeInsets.only(left: 10.0),
                child: pw.Text(' SnagSnapper'),
              ),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Container(
                  height: 20,
                  width: 20,
                  margin: const pw.EdgeInsets.only(right: 8.0),
                  decoration: pw.BoxDecoration(
                      //borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5.0)),
//                color: PdfColors.green900,
                      image: pw.DecorationImage(alignment: pw.Alignment.center, image: iOSLogoImage, fit: pw.BoxFit.cover)),
                ),
                pw.Container(width: 2.0, height: 25.0, color: mainOrng),
                pw.Container(
                  height: 20,
                  width: 20,
                  margin: const pw.EdgeInsets.only(left: 8.0),
                  decoration: pw.BoxDecoration(
                      //borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5.0)),
//                color: PdfColors.green900,
                      image: pw.DecorationImage(alignment: pw.Alignment.center, image: androidLogoImage, fit: pw.BoxFit.cover)),
                ),
              ])
            ]),


            ]
          ),




          pw.Text(
            'Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey,
            ),
          ),
        ],
      )
    ]);
  }

  _buildTheme() async {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        //base: Font.ttf(await rootBundle.load("fonts/Roboto-Regular.ttf")),
      ),
      orientation: pw.PageOrientation.portrait,
      margin: const pw.EdgeInsets.all(15.0),
    );
  }

  _getFirstPage(doc) {
    return pw.Column(children: <pw.Widget>[
      pw.Container(
        decoration: _logo != null
            ? pw.BoxDecoration(
            //color: PdfColors.green100,
            image: pw.DecorationImage(
                alignment: pw.Alignment.center,
                image: _logo!,
                fit: pw.BoxFit.contain),)
            :const pw.BoxDecoration(),
        height: 250.0,
        width: 250.0,
      ),
      pw.SizedBox(height: 50.0),
      pw.Divider(thickness: 3.0, color: mainOrng, endIndent: 80.0),
      pw.Container(
        height: 200,
        margin: const pw.EdgeInsets.only(bottom: 16.0),
        padding: const pw.EdgeInsets.only(left: 16.0, top: 8.0),
        //color: PdfColors.green100,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: <pw.Widget>[
            pw.Expanded(
              child: pw.Row(children: <pw.Widget>[
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: <pw.Widget>[
                      pw.Text('Site name: ', style: const pw.TextStyle(fontSize: 16.0)),
                      pw.SizedBox(height: 4.0),
                      pw.Flexible(
                        child: pw.Container(
                            width: 450.0,
                            child: pw.Text(_site.name,
                                style: pw.TextStyle(fontSize: 30.0, fontWeight: pw.FontWeight.bold))),
                      ),
                    ])
              ]),
            ),
            pw.SizedBox(height: 16.0),
            pw.Row(children: <pw.Widget>[
              pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Location: ', style: const pw.TextStyle(fontSize: 16.0)),
                    pw.SizedBox(height: 4.0),
                    pw.Container(
                        width: 350.0, child: pw.Text(_site.address ?? '', style: const pw.TextStyle(fontSize: 20.0))),
                  ])
            ]),
          ],
        ),
      ),
      pw.Container(
        height: 100,
        decoration: pw.BoxDecoration(border: pw.Border(
            left: pw.BorderSide(color: mainOrng, width: 3),
            right: pw.BorderSide(color: mainOrng, width: 3),
            top: pw.BorderSide(color: mainOrng, width: 3),
            bottom: pw.BorderSide(color: mainOrng, width: 3),
        ), borderRadius: const pw.BorderRadius.all(Radius.circular(10.0))),
        padding: const pw.EdgeInsets.only(top: 16.0),
        //color: PdfColors.green500,
        alignment: pw.Alignment.center,
        child: pw.Row(children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(children: <pw.Widget>[
              pw.Text('${_snags.length}', style: const pw.TextStyle(color: PdfColors.black, fontSize: 30.0)),
              pw.SizedBox(height: 10.0),
              pw.Text('Snags Identified', style: const pw.TextStyle(color: PdfColors.black, fontSize: 20.0)),
            ]),
          ),
          pw.SizedBox(width: 3, height: 50, child: pw.Container(color: mainOrng)),
          pw.Expanded(
            child: pw.Column(children: <pw.Widget>[
              pw.Text((_snags.length - getClosedSnags()).toString(),
                  style: const pw.TextStyle(color: PdfColors.black, fontSize: 30.0)),
              pw.SizedBox(height: 10.0),
              pw.Text('Snags in Progress', style: const pw.TextStyle(color: PdfColors.black, fontSize: 20.0)),
            ]),
          ),
          pw.SizedBox(width: 3, height: 50, child: pw.Container(color: mainOrng)),
          pw.Expanded(
            child: pw.Column(children: <pw.Widget>[
              pw.Text(getClosedSnags().toString(), style: const pw.TextStyle(color: PdfColors.black, fontSize: 30.0)),
              pw.SizedBox(height: 10.0),
              pw.Text('Snags Closed', style: const pw.TextStyle(color: PdfColors.black, fontSize: 20.0)),
            ]),
          ),
        ]),
      ),
      pw.Divider(thickness: 3, color: mainOrng, indent: 125, endIndent: 125),
      pw.SizedBox(height: 50.0),
      pw.Container(
        height: 110,
        padding: const pw.EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        //color: PdfColors.green100,
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('Prepared by:'),
                    // TODO: ownerName removed from NEW Site model - using user name instead
                    pw.Text(_user.name, style: const pw.TextStyle(fontSize: 16.0)),
                    pw.Text(_user.phone, style: const pw.TextStyle(fontSize: 16.0)),
                  ]),
              pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: <pw.Widget>[
                  pw.Container(
                    padding: const pw.EdgeInsets.only(right: 16.0),
                    // TODO: Update to use signatureLocalPath when implementing PDF module
                    // The new AppUser model stores file paths, not base64 data
                    // Need to read image from file and convert to base64 for PDF generation
                    decoration: const pw.BoxDecoration(),
                    // decoration: _user.signatureLocalPath != null && _user.signatureLocalPath!.isNotEmpty
                    //     ? pw.BoxDecoration(
                    //       //color: PdfColors.green500,
                    //         image: pw.DecorationImage(
                    //           alignment: pw.Alignment.center,
                    //           image: pw.MemoryImage(
                    //             base64Decode(_user.signature), // Need to read from file
                    //           ),
                    //           fit: pw.BoxFit.contain))
                    // : const pw.BoxDecoration(),
                    height: 50.0,
                    width: 150.0,
                  ),
                  pw.Text('Signature...................................', style: const pw.TextStyle(fontSize: 16.0)),
                ],
              ),
            ]),
      )
    ]);
  }

  _getSnags(doc) {
    List<pw.Widget> widgets = [];
    for (var snag in _snags) {
      // Check if fix images exist (NEW model uses fixImages array)
      final hasFixImage1 = snag.fixImages.length > 1 && snag.fixImages[1].hasImage;
      final hasFixImage2 = snag.fixImages.length > 2 && snag.fixImages[2].hasImage;

      if (!hasFixImage1 && !hasFixImage2) {
        widgets.add(_getSingleSnag(snag, doc));
      } else {
        if (kDebugMode) print(' Snag with three PIC ROW: ${snag.location}');
        widgets.add(_getSingleSnag(snag,doc));
        widgets.add(_getThreePicRow(snag,doc));
      }
    }
    return widgets;
  }

  _getSingleSnag(Snag snag, doc) {
    // Check for fix main image (NEW model uses fixImages[0])
    final hasFixMainImage = snag.fixImages.isNotEmpty && snag.fixImages[0].hasImage;
    // TODO: M8 Migration - Load fix image from file path instead of base64
    // For now, show placeholder when fix images exist (file-based loading needed)

    return pw.Container(
        height: 180,
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8.0),
        child: pw.Row(
          children: <pw.Widget>[
            // For picture
            pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  height: 180,
                  width: hasFixMainImage ? 180 : 0,
                  decoration: hasFixMainImage
                      ? pw.BoxDecoration(
                        color: PdfColors.green500,
                        // TODO: Load image from file path: snag.fixImages[0].localPath
                        )
                  :const pw.BoxDecoration(),
                ),
              ],
            ),
            // For text
            pw.Expanded(
                child: pw.Column(
              children: <pw.Widget>[
                pw.Container(
                    padding: const pw.EdgeInsets.only(left: 8.0),
                    height: 30,
                    color: PdfColors.white,
                    child: pw.Column(children: <pw.Widget>[
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: <pw.Widget>[
                            pw.Row(children: <pw.Widget>[
                              pw.Text('Location: ${snag.location}'),
                            ]),
                            pw.Row(children: <pw.Widget>[
                              pw.Text('Raised Date: ${DateFormat(Provider.of<CP>(_context, listen: false).getDateFormat()).format(snag.creationDate)}'),
                            ]),
                          ]),
                      pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: <pw.Widget>[
                            pw.Row(children: <pw.Widget>[
                              pw.Text('Assigned to: ${snag.assignedName == null || snag.assignedName!.isEmpty? ' -- ':snag.assignedName}'),
                            ]),
                            pw.Row(children: <pw.Widget>[
                              pw.Text('- ${counter++} -',),
                            ]),
                            pw.Row(children: <pw.Widget>[
                              pw.Text('Priority: ${snag.priority == 1 ? 'Low' : snag.priority == 2 ? 'Medium' : 'High'}'),
                            ]),
                          ])
                    ]),
                ),
                pw.SizedBox(height: 5.0),
                pw.Expanded(
                    child: pw.Flexible(
                  child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border(
                        left: pw.BorderSide(color: mainOrng, width: 1),
                        right: pw.BorderSide(color: mainOrng, width: 1),
                        top: pw.BorderSide(color: mainOrng, width: 1),
                        bottom: pw.BorderSide(color: mainOrng, width: 1),
                      ), borderRadius: const pw.BorderRadius.all(Radius.circular(10.0))),
                      //width: 380,
                      alignment: pw.Alignment.topLeft,
                      padding: const pw.EdgeInsets.only(top: 5.0, left: 5.0),
                      margin: const pw.EdgeInsets.only(left: 5.0),
                      child: pw.Text(snag.description ?? '')),
                )),
                pw.SizedBox(height: 0.0),
                pw.Container(
                    padding: const pw.EdgeInsets.only(left: 8.0),
                    height: 30,
                    //width: 370,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: <pw.Widget>[
                      pw.Row(children: <pw.Widget>[
                        // TIMEZONE: Display UTC midnight as local date
                        pw.Text('Due Date: ${snag.dueDate == null ? '--' : DateFormat(Provider.of<CP>(_context).getDateFormat()).format(snag.dueDate!.toLocal())}',),
                      ]),
                      pw.Row(children: <pw.Widget>[
                        pw.Text('Status: ${!snag.snagConfirmedStatus && !snag.snagStatus ? 'CLOSED' : 'OPEN'}',
                        style: pw.TextStyle(color: !snag.snagConfirmedStatus && !snag.snagStatus ? PdfColors.green700 : PdfColors.black)),
                      ]),
                    ])
                ),
              ],
            )),
          ],
        ));
  }

  _getThreePicRow(Snag snag, doc) {
    return pw.Container(
        height: 180,
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom:8.0),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            // For picture - TODO: M8 Migration - Load fix images from file paths
            // NEW model: snag.fixImages[1], [2], [3] have localPath for file-based images
            pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  height: 180,
                  width: 180,
                  decoration:pw.BoxDecoration(
                      image: pw.DecorationImage(
                          alignment: pw.Alignment.center,
                          // TODO: Load from snag.fixImages[1].localPath if hasImage
                          image: _noPiclogo,
                          fit: pw.BoxFit.cover)),
                ),
              ],
            ),
            pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  height: 180,
                  width: 180,
                  decoration: pw.BoxDecoration(
                      image: pw.DecorationImage(
                          alignment: pw.Alignment.center,
                          // TODO: Load from snag.fixImages[2].localPath if hasImage
                          image: _noPiclogo,
                          fit: pw.BoxFit.cover)),
                ),
              ],
            ),
            pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Container(
                  height: 180,
                  width: 180,
                  decoration: pw.BoxDecoration(
                      image: pw.DecorationImage(
                          alignment: pw.Alignment.center,
                          // TODO: Load from snag.fixImages[3].localPath if hasImage
                          image: _noPiclogo,
                          fit: pw.BoxFit.cover)),
                ),
              ],
            ),
            // For text
          ],
        ));
  }

  int getClosedSnags() {
    int counter = 0;
    _snags.forEach((snag) {
      if (!snag.snagStatus && !snag.snagConfirmedStatus) counter++;
    });
    return counter;
  }
}

class _UrlText extends pw.StatelessWidget {
  _UrlText(this.text, this.url);

  final String text;
  final String url;

  @override
  pw.Widget build(pw.Context context) {
    return pw.UrlLink(
      destination: url,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            color: PdfColors.blue700,
          )),
    );
  }
}
