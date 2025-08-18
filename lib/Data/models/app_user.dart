import 'package:flutter/foundation.dart';

/// AppUser model for offline-first profile management
/// Implements PRD Section 4.2.1 specifications
@immutable
class AppUser {
  // Core Fields
  final String id; // Firebase UID (primary key for both local and cloud)
  final String name;
  final String email;
  final String phone;
  final String jobTitle;
  final String companyName;
  final String? postcodeOrArea;
  final String dateFormat; // 'dd-MM-yyyy' or 'MM-dd-yyyy'

  // Image Paths (RELATIVE paths only for cross-platform compatibility)
  final String? imageLocalPath; // Relative path: SnagSnapper/{userId}/Profile/profile.jpg
  final String? imageFirebasePath; // Firebase Storage path: users/{userId}/profile.jpg
  final String? signatureLocalPath; // Relative path: SnagSnapper/{userId}/Profile/signature.jpg
  final String? signatureFirebasePath; // Firebase Storage path: users/{userId}/signature.jpg
  
  // Deletion flags for offline sync
  final bool imageMarkedForDeletion; // Track pending image deletion
  final bool signatureMarkedForDeletion; // Track pending signature deletion

  // Sync Management
  final bool needsProfileSync; // Profile data changed
  final bool needsImageSync; // Profile image changed
  final bool needsSignatureSync; // Signature changed
  final DateTime? lastSyncTime; // Last successful sync

  // Device Management
  final String? currentDeviceId; // Current device identifier
  final DateTime? lastLoginTime; // Last login timestamp

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Versioning
  final int localVersion;
  final int firebaseVersion;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.jobTitle,
    required this.companyName,
    this.postcodeOrArea,
    this.dateFormat = 'dd-MM-yyyy',
    this.imageLocalPath,
    this.imageFirebasePath,
    this.signatureLocalPath,
    this.signatureFirebasePath,
    this.imageMarkedForDeletion = false,
    this.signatureMarkedForDeletion = false,
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

  /// Create AppUser from database map
  factory AppUser.fromDatabase(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      jobTitle: map['job_title'] as String,
      companyName: map['company_name'] as String,
      postcodeOrArea: map['postcode_area'] as String?,
      dateFormat: map['date_format'] as String? ?? 'dd-MM-yyyy',
      imageLocalPath: map['image_local_path'] as String?,
      imageFirebasePath: map['image_firebase_path'] as String?,
      signatureLocalPath: map['signature_local_path'] as String?,
      signatureFirebasePath: map['signature_firebase_path'] as String?,
      imageMarkedForDeletion: (map['image_marked_for_deletion'] as int? ?? 0) == 1,
      signatureMarkedForDeletion: (map['signature_marked_for_deletion'] as int? ?? 0) == 1,
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      localVersion: map['local_version'] as int? ?? 1,
      firebaseVersion: map['firebase_version'] as int? ?? 0,
    );
  }

  /// Convert AppUser to database map
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
      'image_firebase_path': imageFirebasePath,
      'signature_local_path': signatureLocalPath,
      'signature_firebase_path': signatureFirebasePath,
      'image_marked_for_deletion': imageMarkedForDeletion ? 1 : 0,
      'signature_marked_for_deletion': signatureMarkedForDeletion ? 1 : 0,
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


  /// Create a copy with updated fields
  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? companyName,
    String? Function()? postcodeOrArea,
    String? dateFormat,
    String? Function()? imageLocalPath,
    String? Function()? imageFirebasePath,
    String? Function()? signatureLocalPath,
    String? Function()? signatureFirebasePath,
    bool? imageMarkedForDeletion,
    bool? signatureMarkedForDeletion,
    bool? needsProfileSync,
    bool? needsImageSync,
    bool? needsSignatureSync,
    DateTime? Function()? lastSyncTime,
    String? Function()? currentDeviceId,
    DateTime? Function()? lastLoginTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? localVersion,
    int? firebaseVersion,
  }) {
    // Check if profile data changed
    bool profileChanged = (name != null && name != this.name) ||
        (email != null && email != this.email) ||
        (phone != null && phone != this.phone) ||
        (jobTitle != null && jobTitle != this.jobTitle) ||
        (companyName != null && companyName != this.companyName) ||
        (postcodeOrArea != null && postcodeOrArea != this.postcodeOrArea) ||
        (dateFormat != null && dateFormat != this.dateFormat);
    
    // Check if image changed  
    bool imageChanged = imageLocalPath != null && imageLocalPath() != this.imageLocalPath;
    
    // Check if signature changed
    bool signatureChanged = signatureLocalPath != null && signatureLocalPath() != this.signatureLocalPath;
    
    // Check if any data changed
    bool anyChange = profileChanged || imageChanged || signatureChanged;
    
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      postcodeOrArea: postcodeOrArea != null ? postcodeOrArea() : this.postcodeOrArea,
      dateFormat: dateFormat ?? this.dateFormat,
      imageLocalPath: imageLocalPath != null ? imageLocalPath() : this.imageLocalPath,
      imageFirebasePath: imageFirebasePath != null ? imageFirebasePath() : this.imageFirebasePath,
      signatureLocalPath: signatureLocalPath != null ? signatureLocalPath() : this.signatureLocalPath,
      signatureFirebasePath: signatureFirebasePath != null ? signatureFirebasePath() : this.signatureFirebasePath,
      imageMarkedForDeletion: imageMarkedForDeletion ?? this.imageMarkedForDeletion,
      signatureMarkedForDeletion: signatureMarkedForDeletion ?? this.signatureMarkedForDeletion,
      needsProfileSync: needsProfileSync ?? (profileChanged ? true : this.needsProfileSync),
      needsImageSync: needsImageSync ?? (imageChanged ? true : this.needsImageSync),
      needsSignatureSync: needsSignatureSync ?? (signatureChanged ? true : this.needsSignatureSync),
      lastSyncTime: lastSyncTime != null ? lastSyncTime() : this.lastSyncTime,
      currentDeviceId: currentDeviceId != null ? currentDeviceId() : this.currentDeviceId,
      lastLoginTime: lastLoginTime != null ? lastLoginTime() : this.lastLoginTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? (anyChange ? DateTime.now() : this.updatedAt),
      localVersion: localVersion ?? this.localVersion,
      firebaseVersion: firebaseVersion ?? this.firebaseVersion,
    );
  }

  /// Clear all sync flags after successful sync
  AppUser clearSyncFlags() {
    return copyWith(
      needsProfileSync: false,
      needsImageSync: false,
      needsSignatureSync: false,
      lastSyncTime: () => DateTime.now(),
    );
  }

  /// Check if this is the current device
  bool isCurrentDevice(String? deviceId) {
    if (currentDeviceId == null || deviceId == null) return false;
    return currentDeviceId == deviceId;
  }

  /// Validate field values
  static void validate({
    String? name,
    String? email,
    String? phone,
    String? jobTitle,
    String? companyName,
    String? imageLocalPath,
    String? signatureLocalPath,
    String? dateFormat,
  }) {
    // Validate name
    if (name != null) {
      if (name.isEmpty) {
        throw ArgumentError('Name cannot be empty');
      }
      if (name.length < 2) {
        throw ArgumentError('Name must be at least 2 characters');
      }
      if (name.length > 50) {
        throw ArgumentError('Name must be less than 50 characters');
      }
    }

    // Validate email
    if (email != null) {
      if (email.isEmpty) {
        throw ArgumentError('Email cannot be empty');
      }
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        throw ArgumentError('Invalid email format');
      }
    }

    // Validate phone
    if (phone != null) {
      if (phone.isEmpty) {
        throw ArgumentError('Phone cannot be empty');
      }
      final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
      if (!phoneRegex.hasMatch(phone)) {
        throw ArgumentError('Phone must be 7-15 digits, optionally starting with +');
      }
    }

    // Validate job title
    if (jobTitle != null && jobTitle.isNotEmpty) {
      if (jobTitle.length > 50) {
        throw ArgumentError('Job title must be less than 50 characters');
      }
    }

    // Validate company name
    if (companyName != null) {
      if (companyName.isEmpty) {
        throw ArgumentError('Company name cannot be empty');
      }
      if (companyName.length < 2) {
        throw ArgumentError('Company name must be at least 2 characters');
      }
      if (companyName.length > 100) {
        throw ArgumentError('Company name must be less than 100 characters');
      }
    }

    // Validate image paths are relative
    if (imageLocalPath != null && imageLocalPath.isNotEmpty) {
      if (imageLocalPath.startsWith('/') || 
          imageLocalPath.startsWith('C:\\') || 
          imageLocalPath.contains(':\\')) {
        throw ArgumentError('Image path must be relative, not absolute');
      }
    }

    if (signatureLocalPath != null && signatureLocalPath.isNotEmpty) {
      if (signatureLocalPath.startsWith('/') || 
          signatureLocalPath.startsWith('C:\\') || 
          signatureLocalPath.contains(':\\')) {
        throw ArgumentError('Signature path must be relative, not absolute');
      }
    }

    // Validate date format
    if (dateFormat != null) {
      const validFormats = ['dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd'];
      if (!validFormats.contains(dateFormat)) {
        throw ArgumentError('Invalid date format. Must be one of: ${validFormats.join(', ')}');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          jobTitle == other.jobTitle &&
          companyName == other.companyName &&
          postcodeOrArea == other.postcodeOrArea &&
          dateFormat == other.dateFormat &&
          imageLocalPath == other.imageLocalPath &&
          imageFirebasePath == other.imageFirebasePath &&
          signatureLocalPath == other.signatureLocalPath &&
          signatureFirebasePath == other.signatureFirebasePath &&
          imageMarkedForDeletion == other.imageMarkedForDeletion &&
          signatureMarkedForDeletion == other.signatureMarkedForDeletion &&
          needsProfileSync == other.needsProfileSync &&
          needsImageSync == other.needsImageSync &&
          needsSignatureSync == other.needsSignatureSync &&
          currentDeviceId == other.currentDeviceId;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      jobTitle.hashCode ^
      companyName.hashCode ^
      postcodeOrArea.hashCode ^
      dateFormat.hashCode ^
      imageLocalPath.hashCode ^
      imageFirebasePath.hashCode ^
      signatureLocalPath.hashCode ^
      signatureFirebasePath.hashCode ^
      imageMarkedForDeletion.hashCode ^
      signatureMarkedForDeletion.hashCode ^
      needsProfileSync.hashCode ^
      needsImageSync.hashCode ^
      needsSignatureSync.hashCode ^
      currentDeviceId.hashCode;

  @override
  String toString() {
    return 'AppUser{id: $id, name: $name, email: $email, phone: $phone, '
        'jobTitle: $jobTitle, companyName: $companyName, '
        'needsSync: [profile: $needsProfileSync, image: $needsImageSync, signature: $needsSignatureSync]}';
  }
}