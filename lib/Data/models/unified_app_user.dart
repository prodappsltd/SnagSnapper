import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/colleague.dart';

part 'unified_app_user.g.dart';

/// Unified AppUser model that works with both Firebase and local database
/// Combines functionality from both user.dart and models/app_user.dart
/// Implements offline-first architecture per PRD Section 4.2.1
@JsonSerializable()
@immutable
class UnifiedAppUser {
  // Core Fields (from both classes)
  @JsonKey(name: 'id')
  final String id; // Firebase UID (primary key)
  
  @JsonKey(name: NAME)
  final String name;
  
  @JsonKey(name: EMAIL)
  final String email;
  
  @JsonKey(name: PHONE)
  final String phone;
  
  @JsonKey(name: JOB_TITLE)
  final String jobTitle;
  
  @JsonKey(name: COMPANY_NAME)
  final String companyName;
  
  @JsonKey(name: POSTCODE_AREA)
  final String? postcodeOrArea;
  
  @JsonKey(name: DATE_FORMAT, defaultValue: 'dd-MM-yyyy')
  final String dateFormat;
  
  // Image Fields (unified approach)
  @JsonKey(name: IMAGE)
  final String? imageLocalPath; // Local path or Firebase URL
  
  @JsonKey(name: 'image_firebase_url')
  final String? imageFirebaseUrl; // Explicit Firebase URL
  
  @JsonKey(name: SIGNATURE)
  final String? signatureLocalPath; // Local path or Firebase URL
  
  @JsonKey(name: 'signature_firebase_url')
  final String? signatureFirebaseUrl; // Explicit Firebase URL
  
  // Colleagues and Sites (from old AppUser)
  @JsonKey(name: LIST_OF_COLLEAGUES)
  final List<Colleague>? listOfALLColleagues;
  
  @JsonKey(name: LIST_OF_SITE_PATHS)
  final Map<String, String>? mapOfSitePaths;
  
  // Sync Management
  @JsonKey(name: 'needsProfileSync', defaultValue: false)
  final bool needsProfileSync;
  
  @JsonKey(name: 'needsImageSync', defaultValue: false)
  final bool needsImageSync;
  
  @JsonKey(name: 'needsSignatureSync', defaultValue: false)
  final bool needsSignatureSync;
  
  @JsonKey(name: 'lastSyncTime')
  final DateTime? lastSyncTime;
  
  // Device Management
  @JsonKey(name: 'currentDeviceId')
  final String? currentDeviceId;
  
  @JsonKey(name: 'lastLoginTime')
  final DateTime? lastLoginTime;
  
  // Metadata
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  
  @JsonKey(name: 'updatedAt')
  final DateTime updatedAt;
  
  // Versioning
  @JsonKey(name: 'localVersion', defaultValue: 1)
  final int localVersion;
  
  @JsonKey(name: 'firebaseVersion', defaultValue: 0)
  final int firebaseVersion;

  const UnifiedAppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.companyName,
    this.postcodeOrArea,
    this.dateFormat = 'dd-MM-yyyy',
    this.imageLocalPath,
    this.imageFirebaseUrl,
    this.signatureLocalPath,
    this.signatureFirebaseUrl,
    this.listOfALLColleagues,
    this.mapOfSitePaths,
    this.needsProfileSync = false,
    this.needsImageSync = false,
    this.needsSignatureSync = false,
    this.lastSyncTime,
    this.currentDeviceId,
    this.lastLoginTime,
    required this.createdAt,
    required this.updatedAt,
    this.localVersion = 1,
    this.firebaseVersion = 0,
  });

  /// Factory constructor for JSON deserialization (Firebase)
  factory UnifiedAppUser.fromJson(Map<String, dynamic> json) => 
      _$UnifiedAppUserFromJson(json);

  /// Convert to JSON for Firebase
  Map<String, dynamic> toJson() => _$UnifiedAppUserToJson(this);

  /// Create from database map (local SQLite)
  factory UnifiedAppUser.fromDatabase(Map<String, dynamic> map) {
    // Handle colleagues list from database JSON
    List<Colleague>? colleagues;
    if (map['colleagues_json'] != null) {
      final colleaguesData = map['colleagues_json'] as String;
      // Parse JSON string to list
      // TODO: Implement proper JSON parsing for colleagues
    }
    
    // Handle sites map from database JSON
    Map<String, String>? sitePaths;
    if (map['site_paths_json'] != null) {
      final sitesData = map['site_paths_json'] as String;
      // Parse JSON string to map
      // TODO: Implement proper JSON parsing for sites
    }
    
    return UnifiedAppUser(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      jobTitle: map['job_title'] as String? ?? '',
      companyName: map['company_name'] as String? ?? '',
      postcodeOrArea: map['postcode_area'] as String?,
      dateFormat: map['date_format'] as String? ?? 'dd-MM-yyyy',
      imageLocalPath: map['image_local_path'] as String?,
      imageFirebaseUrl: map['image_firebase_url'] as String?,
      signatureLocalPath: map['signature_local_path'] as String?,
      signatureFirebaseUrl: map['signature_firebase_url'] as String?,
      listOfALLColleagues: colleagues,
      mapOfSitePaths: sitePaths,
      needsProfileSync: (map['needs_profile_sync'] as int? ?? 0) == 1,
      needsImageSync: (map['needs_image_sync'] as int? ?? 0) == 1,
      needsSignatureSync: (map['needs_signature_sync'] as int? ?? 0) == 1,
      lastSyncTime: map['last_sync_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_time'] as int)
          : null,
      currentDeviceId: map['current_device_id'] as String?,
      lastLoginTime: map['last_login_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_time'] as int)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : DateTime.now(),
      localVersion: map['local_version'] as int? ?? 1,
      firebaseVersion: map['firebase_version'] as int? ?? 0,
    );
  }

  /// Convert to database map (local SQLite)
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'job_title': jobTitle,
      'company_name': companyName,
      'postcode_area': postcodeOrArea,
      'date_format': dateFormat,
      'image_local_path': imageLocalPath,
      'image_firebase_url': imageFirebaseUrl,
      'signature_local_path': signatureLocalPath,
      'signature_firebase_url': signatureFirebaseUrl,
      'colleagues_json': listOfALLColleagues != null 
          ? _colleaguesToJson(listOfALLColleagues!)
          : null,
      'site_paths_json': mapOfSitePaths != null
          ? _sitePathsToJson(mapOfSitePaths!)
          : null,
      'needs_profile_sync': needsProfileSync ? 1 : 0,
      'needs_image_sync': needsImageSync ? 1 : 0,
      'needs_signature_sync': needsSignatureSync ? 1 : 0,
      'last_sync_time': lastSyncTime?.millisecondsSinceEpoch,
      'current_device_id': currentDeviceId,
      'last_login_time': lastLoginTime?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'local_version': localVersion,
      'firebase_version': firebaseVersion,
    };
  }

  /// Create from old AppUser (for migration)
  factory UnifiedAppUser.fromOldAppUser(dynamic oldUser, String userId) {
    final now = DateTime.now();
    return UnifiedAppUser(
      id: userId,
      name: oldUser.name ?? '',
      email: oldUser.email ?? '',
      phone: oldUser.phone ?? '',
      jobTitle: oldUser.jobTitle ?? '',
      companyName: oldUser.companyName ?? '',
      postcodeOrArea: oldUser.postcodeOrArea,
      dateFormat: oldUser.dateFormat ?? 'dd-MM-yyyy',
      imageLocalPath: oldUser.image,
      signatureLocalPath: oldUser.signature,
      listOfALLColleagues: oldUser.listOfALLColleagues,
      mapOfSitePaths: oldUser.mapOfSitePaths,
      needsProfileSync: oldUser.needsProfileSync ?? false,
      needsImageSync: oldUser.needsImageSync ?? false,
      needsSignatureSync: oldUser.needsSignatureSync ?? false,
      lastSyncTime: oldUser.lastSyncTime,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Convert to old AppUser format (for compatibility)
  dynamic toOldAppUser() {
    // This would need the old AppUser class imported
    // For now, return a map that matches old structure
    return {
      NAME: name,
      EMAIL: email,
      PHONE: phone,
      JOB_TITLE: jobTitle,
      COMPANY_NAME: companyName,
      POSTCODE_AREA: postcodeOrArea,
      DATE_FORMAT: dateFormat,
      IMAGE: imageLocalPath ?? '',
      SIGNATURE: signatureLocalPath ?? '',
      LIST_OF_COLLEAGUES: listOfALLColleagues,
      LIST_OF_SITE_PATHS: mapOfSitePaths,
      'needsProfileSync': needsProfileSync,
      'needsImageSync': needsImageSync,
      'needsSignatureSync': needsSignatureSync,
      'lastSyncTime': lastSyncTime,
    };
  }

  /// copyWith method for immutable updates
  UnifiedAppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? companyName,
    String? postcodeOrArea,
    String? dateFormat,
    String? imageLocalPath,
    String? imageFirebaseUrl,
    String? signatureLocalPath,
    String? signatureFirebaseUrl,
    List<Colleague>? listOfALLColleagues,
    Map<String, String>? mapOfSitePaths,
    bool? needsProfileSync,
    bool? needsImageSync,
    bool? needsSignatureSync,
    DateTime? lastSyncTime,
    String? currentDeviceId,
    DateTime? lastLoginTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? localVersion,
    int? firebaseVersion,
  }) {
    return UnifiedAppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      postcodeOrArea: postcodeOrArea ?? this.postcodeOrArea,
      dateFormat: dateFormat ?? this.dateFormat,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      imageFirebaseUrl: imageFirebaseUrl ?? this.imageFirebaseUrl,
      signatureLocalPath: signatureLocalPath ?? this.signatureLocalPath,
      signatureFirebaseUrl: signatureFirebaseUrl ?? this.signatureFirebaseUrl,
      listOfALLColleagues: listOfALLColleagues ?? this.listOfALLColleagues,
      mapOfSitePaths: mapOfSitePaths ?? this.mapOfSitePaths,
      needsProfileSync: needsProfileSync ?? this.needsProfileSync,
      needsImageSync: needsImageSync ?? this.needsImageSync,
      needsSignatureSync: needsSignatureSync ?? this.needsSignatureSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Auto-update on change
      localVersion: localVersion ?? this.localVersion,
      firebaseVersion: firebaseVersion ?? this.firebaseVersion,
    );
  }

  // Helper methods for JSON conversion
  String _colleaguesToJson(List<Colleague> colleagues) {
    // TODO: Implement JSON serialization for colleagues
    return '[]';
  }
  
  String _sitePathsToJson(Map<String, String> sites) {
    // TODO: Implement JSON serialization for site paths
    return '{}';
  }
}