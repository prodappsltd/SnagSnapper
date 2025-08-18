
import 'package:json_annotation/json_annotation.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/colleague.dart';

import '../Constants/constants.dart';

/// This allows the `User` class to access private members in
/// the generated file. The value for this is *.g.dart, where
/// the star denotes the source file name.

part 'user.g.dart';


@JsonSerializable()
class AppUser {
  AppUser ({
    this.name = '',
    this.dateFormat = '',
    this.jobTitle = '',
    this.companyName = '',
    this.postcodeOrArea = '',
    this.email = '',
    this.phone = '',
    this.image = '',
    this.listOfALLColleagues,
    this.signature = '',
    this.mapOfSitePaths,
    this.needsProfileSync = false,
    this.needsImageSync = false,
    this.needsSignatureSync = false,
    this.lastSyncTime,
  });

  @JsonKey(name: NAME)
  String name;
  @JsonKey(name: DATE_FORMAT,defaultValue: 'dd-MM-yyyy')
  String dateFormat;
  @JsonKey(name: JOB_TITLE)
  String jobTitle;
  @JsonKey(name: COMPANY_NAME)
  String companyName;
  @JsonKey(name: POSTCODE_AREA)
  String postcodeOrArea;
  @JsonKey(name: EMAIL)
  String email;
  @JsonKey(name: PHONE)
  String phone;
  @JsonKey(name: IMAGE)
  String image;
  @JsonKey(name: SIGNATURE)
  String signature;
  @JsonKey(name: LIST_OF_COLLEAGUES)
  List<Colleague>? listOfALLColleagues;
  /// Map of <SiteID, OwnerID>
  @JsonKey(name: LIST_OF_SITE_PATHS)
  Map<String,String>? mapOfSitePaths;
  
  /// Sync flags for offline-first architecture
  /// Tracks if profile data needs to be synced to Firebase
  @JsonKey(name: 'needsProfileSync', defaultValue: false)
  bool needsProfileSync = false;
  
  /// Tracks if profile image needs to be synced to Firebase Storage
  @JsonKey(name: 'needsImageSync', defaultValue: false)
  bool needsImageSync = false;
  
  /// Tracks if signature image needs to be synced to Firebase Storage
  @JsonKey(name: 'needsSignatureSync', defaultValue: false)
  bool needsSignatureSync = false;
  
  /// Last successful sync timestamp for conflict resolution
  @JsonKey(name: 'lastSyncTime')
  DateTime? lastSyncTime;

  /// A necessary factory constructor for creating a new User instance
  /// from a map. Pass the map to the generated `_$UserFromJson()` constructor.
  /// The constructor is named after the source class, in this case, User.
  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  /// `toJson` is the convention for a class to declare support for serialization
  /// to JSON. The implementation simply calls the private, generated
  /// helper method `_$UserToJson`.
  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}