
import 'package:json_annotation/json_annotation.dart';
import 'package:snagsnapper/Constants/constants.dart';

part 'site.g.dart';


@JsonSerializable()
class Site {
  Site ({
  required this.name,
  required this.companyName,
  required this.location,
  required this.date,
  required this.pictureQuality,
  required this.image,
  required this.ownerEmail,
  required this.uID,
  required this.sharedWith,
  required this.ownerName,
  required this.archive
  });

  @JsonKey(name: NAME)
  String name;
  @JsonKey(name: COMPANY_NAME)
  String companyName;
  @JsonKey(name: IMAGE, defaultValue: '')
  String image;
  @JsonKey(name: LOCATION)
  String location;
  @JsonKey(name: DATE)
  DateTime date;
  @JsonKey(name: UID)
  String uID;
  @JsonKey(name: OWNER_EMAIL)
  String ownerEmail;
  @JsonKey(name: OWNER_NAME)
  String ownerName;
  @JsonKey(name: ARCHIVE, defaultValue: false)
  bool archive;
  @JsonKey(name: SHARED_WITH)
  Map<String, String> sharedWith;
  @JsonKey(name: PICTURE_QUALITY, defaultValue: 0)
  int pictureQuality;

  /// A necessary factory constructor for creating a new User instance
  /// from a map. Pass the map to the generated `_$UserFromJson()` constructor.
  /// The constructor is named after the source class, in this case, User.
  factory Site.fromJson(Map<String, dynamic> json) => _$SiteFromJson(json);

  /// `toJson` is the convention for a class to declare support for serialization
  /// to JSON. The implementation simply calls the private, generated
  /// helper method `_$UserToJson`.
  Map<String, dynamic> toJson() => _$SiteToJson(this);
}