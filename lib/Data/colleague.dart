
import 'package:json_annotation/json_annotation.dart';
import 'package:snagsnapper/Constants/constants.dart';


part 'colleague.g.dart';


@JsonSerializable()
class Colleague {
  @JsonKey(name: NAME)
  String name;
  @JsonKey(name: EMAIL)
  String email;
  @JsonKey(name: PHONE)
  String? phone;
  @JsonKey(name: UID)
  String uniqueID;

  Colleague({
    required this.name,
    required this.email,
    this.phone,
    required this.uniqueID,
  });

  /// A necessary factory constructor for creating a new User instance
  /// from a map. Pass the map to the generated `_$UserFromJson()` constructor.
  /// The constructor is named after the source class, in this case, User.
  factory Colleague.fromJson(Map<String, dynamic> json) => _$ColleagueFromJson(json);

  /// `toJson` is the convention for a class to declare support for serialization
  /// to JSON. The implementation simply calls the private, generated
  /// helper method `_$UserToJson`.
  Map<String, dynamic> toJson() => _$ColleagueToJson(this);

}