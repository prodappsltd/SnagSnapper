

import 'package:json_annotation/json_annotation.dart';
import 'package:snagsnapper/Constants/constants.dart';

part 'snag.g.dart';


@JsonSerializable()
class Snag {

  Snag ({
    required this.location,
    required this.title,
    required this.priority,
    required this.description,
    required this.creatorEmail,
    this.assignedEmail,
    this.assignedName,
    required this.uID,
    required this.siteUID,
    this.dueDate,
    required this.creationDate,
    required this.ownerEmail,
    this.imageMain1,
    this.image2,
    this.image3,
    this.image4,
    required this.snagStatus, // False when closed
    required this.snagConfirmedStatus, // False when confirmed by admin as close

    this.snagFixMainImage = '',
    this.snagFixImage1 = '',
    this.snagFixImage2 = '',
    this.snagFixImage3 = '',
    this.snagFixDescription = '',

  });

  @JsonKey(name: IMAGE_MAIN1, defaultValue: '')
  String? imageMain1;
  @JsonKey(name: IMAGE2, defaultValue: '')
  String? image2;
  @JsonKey(name: IMAGE3, defaultValue: '')
  String? image3;
  @JsonKey(name: IMAGE4, defaultValue: '')
  String? image4;
  @JsonKey(name: SNAG_FIX_MAIN_IMAGE, defaultValue: '')
  String? snagFixMainImage;
  @JsonKey(name: SNAG_FIX_IMAGE_1, defaultValue: '')
  String? snagFixImage1;
  @JsonKey(name: SNAG_FIX_IMAGE_2, defaultValue: '')
  String? snagFixImage2;
  @JsonKey(name: SNAG_FIX_IMAGE_3, defaultValue: '')
  String? snagFixImage3;
  @JsonKey(name: LOCATION)
  String location;
  @JsonKey(name: SNAG_STATUS,defaultValue: true)
  bool snagStatus; // TRUE if it open. Once it is closed, it goes false
  @JsonKey(name: SNAG_CONFIRMED_STATUS, defaultValue: true)
  bool snagConfirmedStatus; // Once snagStatus Goes false and THIS goes false then SNAG is closed.
  @JsonKey(name: TITLE)
  String title;
  @JsonKey(name: DESCRIPTION)
  String description;
  @JsonKey(name: SNAG_FIX_DESCRIPTION, defaultValue: '')
  String? snagFixDescription;
  @JsonKey(name: UID)
  String uID;
  @JsonKey(name: SITE_UID)
  String siteUID;
  @JsonKey(name: DUE_DATE)
  DateTime? dueDate;
  @JsonKey(name: DATE_CREATED)
  DateTime creationDate;
  @JsonKey(name: CREATOR_EMAIL)
  String creatorEmail;
  @JsonKey(name: ASSIGNED_EMAIL, defaultValue: '')
  String? assignedEmail;
  @JsonKey(name: OWNER_EMAIL)
  String ownerEmail; // Site owner
  @JsonKey(name: ASSIGNED_NAME, defaultValue: '')
  String? assignedName;
  @JsonKey(name: PRIORITY)
  int priority;
  @JsonKey(name: SHARED_WITH, defaultValue: [])
  List<String> sharedWith = [];

  /// A necessary factory constructor for creating a new User instance
  /// from a map. Pass the map to the generated `_$UserFromJson()` constructor.
  /// The constructor is named after the source class, in this case, User.
  factory Snag.fromJson(Map<String, dynamic> json) => _$SnagFromJson(json);

  /// `toJson` is the convention for a class to declare support for serialization
  /// to JSON. The implementation simply calls the private, generated
  /// helper method `_$UserToJson`.
  Map<String, dynamic> toJson() => _$SnagToJson(this);
}