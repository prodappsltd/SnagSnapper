
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/snag.dart';

import 'Data/site.dart';

class DummyyDataa{
  List<Site> _siteList = [];
  List<Snag> _snagList = [];
  List<String> _name = ['Victoria Station','Charing Cross Station', 'London Brewery', '157 Chadview court', '61 The Pyghtle', '47 The Pyghtle'];
  List<String> _companyName = ['Cherry Ltd','B**d Ltd', 'Blah Blah', 'Fashion Court', 'Kadamchamcham', 'Singham Lingham Ltd'];
  List<String> _location = ['London','Bexley Heath', 'Romford', 'Chadwell heath', 'Surrey', 'Wellingborough', 'Kettring', 'Luton'];
  List<String> _snagLocation = ['Kitchen','Room E212', ' Back Garden', 'Bedroom window', 'Sink', 'Bathtub', 'Living room carpet', 'Boiler'];
  List<DateTime> _date = [DateTime(2020,4,27),DateTime(2020,4,30), DateTime(2020,4,01), DateTime(2020,4,15), DateTime(2020,4,28)];
  List<int> _pictureQ = [0];//,1,2];
  List<int> _priority = [0,1,2];
  List<String> _view = ['FULL','VIEW'];
  List<String> _ownerEmail = ['rfsingh81@gmail.com'];
  String _ownerName = 'Dee Singh';
  List<String> _sharedEmail = ['me@damanjit.com','3rathis@gmail.com', 'rohitbpl81@gmail.com'];
  List<String> _images = ['images/delete1.jpeg','images/delete2.jpg','images/delete3.jpeg', '']; //,'images/delete4.jpg'
  List<String> _title = ['Broken tap','messed up neighbour','drunk legend','Nothing to see here','Broken door'];
  List<String> _description = ['Broken item needs fixing. put all you\'ve got!Broken item needs fixing. put all you\'ve got!Broken item needs fixing. put all you\'ve got!','This is a complete descripton of this problem','This is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\nThis is another random descriptiond\n','You want more description?You want more description?You want more description?You want more description?You want more description?','Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!Shush is the description!'];

  final _ran = Random();

  Future<List<Site>> createSites(int num) async {

    for (int i=0; i<num; i++){
      String ownerEmail = _ownerEmail[_ran.nextInt(_ownerEmail.length)];
      Site site = Site(
        name: _name[_ran.nextInt(_name.length)],
        companyName: _companyName[_ran.nextInt(_companyName.length)],
        location: _location[_ran.nextInt(_location.length)],
        date: _date[_ran.nextInt(_date.length)],
        pictureQuality: _pictureQ[_ran.nextInt(_pictureQ.length)],
        ownerEmail: ownerEmail,
        image: await _getRandomImage(),
        uID: i.toString(),
        sharedWith: {_sharedEmail[_ran.nextInt(_sharedEmail.length)]:_view[_ran.nextInt(_view.length)],_sharedEmail[_ran.nextInt(_sharedEmail.length)]:_view[_ran.nextInt(_view.length)]},
        archive: false,
        ownerName: getOwnerName(ownerEmail),
      );
      site.sharedWith.putIfAbsent(site.ownerEmail.toLowerCase(), () => 'OWNER');


      _siteList.add(site);
    }
    return _siteList;
  }

  getOwnerName(String ownerEmail){
    switch (ownerEmail){
      case 'me@damanjit.com':
        return 'Damanjit';
        break;
      case 'rfsingh81@gmail.com':
        return 'Rfsingh';
        break;
      case '3rathis@gmail.com':
        return 'Rathees';
        break;
    }
  }


  Future<String> _getRandomImage() async {
    String path = (_images[_ran.nextInt(_images.length)]);
    ByteData bytes;
    String asBase64='';

    if (path.isNotEmpty) {
      bytes = await rootBundle.load(path);
      asBase64 = base64Encode((bytes.buffer.asUint8List()).cast<int>());
      if (kDebugMode) print('Image is: ${asBase64.length/1024}Kb');
    }
    return asBase64;
  }
}