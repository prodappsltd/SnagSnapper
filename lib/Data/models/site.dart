import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Site model for offline-first site management
/// Implements PRD Section 4.2.1 specifications (updated with field review)
/// 
/// Core data model for construction site management with the following features:
/// - Offline-first architecture with local SQLite storage
/// - Three-level permission system (VIEW, FIXER, CONTRIBUTOR)
/// - Dynamic category management for snags
/// - Soft deletion with 7-day grace period
/// - Automatic sync tracking and versioning
/// 
/// Note: Owner is identified by comparing ownerEmail with current user email,
/// not through the permission system.
@immutable
class Site {
  // ============== Identity Fields ==============
  /// Unique identifier for the site (UUID v4, locally generated)
  final String id;
  
  /// Firebase UID of the site owner
  final String ownerUID;
  
  /// Email address of the site owner (used for ownership checks)
  final String ownerEmail;
  
  // ============== Core Business Fields ==============
  /// Site name (Required, UI visible)
  final String name;
  
  /// Client company or individual name (Optional, UI visible)
  final String? companyName;
  
  /// Physical address or location of the site (Optional, UI visible)
  final String? address;
  
  /// Primary contact person for this site (Optional, UI visible)
  final String? contactPerson;
  
  /// Contact person's phone number (Optional, UI visible)
  final String? contactPhone;
  
  /// Site creation/start date (Auto-set on creation, not UI visible)
  final DateTime date;
  
  /// Expected completion date (Optional, UI visible)
  final DateTime? expectedCompletion;
  
  // ============== Media Storage ==============
  /// Local file path for site image (System-managed)
  final String? imageLocalPath;
  
  /// Firebase Storage path for site image (System-managed)
  final String? imageFirebasePath;
  
  // ============== Settings ==============
  /// Image quality for PDF reports: 0=Low, 1=Medium, 2=High (UI visible)
  final int pictureQuality;
  
  /// Archive status to hide completed/old sites (Not visible in create, editable later)
  final bool archive;
  
  // ============== Sharing & Permissions ==============
  /// Map of user emails to their permission levels
  /// Permissions: 'VIEW', 'FIXER', 'CONTRIBUTOR'
  /// Note: Owner is NOT stored here, identified by ownerEmail match
  final Map<String, String> sharedWith;
  
  // ============== Statistics ==============
  /// Total number of snags in this site (Auto-calculated)
  final int totalSnags;
  
  /// Number of open/unresolved snags (Auto-calculated)
  final int openSnags;
  
  /// Number of closed/resolved snags (Auto-calculated)
  final int closedSnags;
  
  // ============== Categories ==============
  /// Dynamic categories for organizing snags
  /// Key: Category ID (int), Value: Category name (String)
  /// Example: {1: 'Electrical', 2: 'Plumbing', 3: 'Painting'}
  /// Created dynamically when snags are added with new categories
  final Map<int, String> snagCategories;
  
  // ============== Sync Management ==============
  /// Flag indicating site data has changed and needs sync
  final bool needsSiteSync;
  
  /// Flag indicating site image has changed and needs sync
  final bool needsImageSync;
  
  /// Flag indicating snags under this site need sync
  final bool needsSnagsSync;
  
  /// Timestamp of last successful sync to Firebase
  final DateTime? lastSyncTime;
  
  // ============== Update Tracking ==============
  /// Timestamp when any snag in this site was last modified
  final DateTime? lastSnagUpdate;
  
  /// List of snag IDs that have pending updates (for shared sites)
  final List<String> updatedSnags;
  
  /// Count of pending updates (for shared sites)
  final int updateCount;
  
  // ============== Deletion Management ==============
  /// Soft delete flag (true when site is marked for deletion)
  final bool markedForDeletion;
  
  /// Timestamp when site was marked for deletion
  final DateTime? deletionDate;
  
  /// Date when site will be permanently deleted (deletionDate + 7 days)
  final DateTime? scheduledDeletionDate;
  
  // ============== Versioning ==============
  /// Local database version number (incremented on each local save)
  final int localVersion;
  
  /// Firebase version number (updated during sync)
  final int firebaseVersion;
  
  // ============== Metadata ==============
  /// Timestamp when record was last updated in database
  final DateTime updatedAt;

  const Site({
    required this.id,
    required this.ownerUID,
    required this.ownerEmail,
    required this.name,
    this.companyName,
    this.address,
    this.contactPerson,
    this.contactPhone,
    required this.date,
    this.expectedCompletion,
    this.imageLocalPath,
    this.imageFirebasePath,
    this.pictureQuality = 1, // Default to medium quality
    this.archive = false,
    Map<String, String>? sharedWith,
    this.totalSnags = 0,
    this.openSnags = 0,
    this.closedSnags = 0,
    Map<int, String>? snagCategories,
    this.needsSiteSync = false,
    this.needsImageSync = false,
    this.needsSnagsSync = false,
    this.lastSyncTime,
    this.lastSnagUpdate,
    List<String>? updatedSnags,
    this.updateCount = 0,
    this.markedForDeletion = false,
    this.deletionDate,
    this.scheduledDeletionDate,
    this.localVersion = 1,
    this.firebaseVersion = 0,
    required this.updatedAt,
  }) : sharedWith = sharedWith ?? const {},
       snagCategories = snagCategories ?? const {},
       updatedSnags = updatedSnags ?? const [];

  /// Factory constructor for creating a new site with default values
  /// 
  /// This is used when creating a new site in the app.
  /// Automatically sets:
  /// - date to current time
  /// - updatedAt to current time
  /// - needsSiteSync to true (for initial sync)
  /// - empty sharedWith map (no initial sharing)
  /// - empty snagCategories (will be populated as snags are created)
  factory Site.create({
    required String id,
    required String ownerUID,
    required String ownerEmail,
    required String name,
    String? companyName,
    String? address,
    String? contactPerson,
    String? contactPhone,
    DateTime? expectedCompletion,
    int pictureQuality = 1,
  }) {
    final now = DateTime.now();
    return Site(
      id: id,
      ownerUID: ownerUID,
      ownerEmail: ownerEmail,
      name: name,
      companyName: companyName,
      address: address,
      contactPerson: contactPerson,
      contactPhone: contactPhone,
      date: now,
      expectedCompletion: expectedCompletion,
      pictureQuality: pictureQuality,
      snagCategories: const {}, // Start with empty categories
      updatedAt: now,
      needsSiteSync: true, // Mark for initial sync
      sharedWith: const {}, // No sharing initially (owner is not a permission)
    );
  }

  /// Create a copy with updated fields
  Site copyWith({
    String? id,
    String? ownerUID,
    String? ownerEmail,
    String? name,
    String? companyName,
    String? address,
    String? contactPerson,
    String? contactPhone,
    DateTime? date,
    DateTime? expectedCompletion,
    String? imageLocalPath,
    String? imageFirebasePath,
    int? pictureQuality,
    bool? archive,
    Map<String, String>? sharedWith,
    int? totalSnags,
    int? openSnags,
    int? closedSnags,
    Map<int, String>? snagCategories,
    bool? needsSiteSync,
    bool? needsImageSync,
    bool? needsSnagsSync,
    DateTime? lastSyncTime,
    DateTime? lastSnagUpdate,
    List<String>? updatedSnags,
    int? updateCount,
    bool? markedForDeletion,
    DateTime? deletionDate,
    DateTime? scheduledDeletionDate,
    int? localVersion,
    int? firebaseVersion,
    DateTime? updatedAt,
  }) {
    return Site(
      id: id ?? this.id,
      ownerUID: ownerUID ?? this.ownerUID,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      date: date ?? this.date,
      expectedCompletion: expectedCompletion ?? this.expectedCompletion,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      imageFirebasePath: imageFirebasePath ?? this.imageFirebasePath,
      pictureQuality: pictureQuality ?? this.pictureQuality,
      archive: archive ?? this.archive,
      sharedWith: sharedWith ?? this.sharedWith,
      totalSnags: totalSnags ?? this.totalSnags,
      openSnags: openSnags ?? this.openSnags,
      closedSnags: closedSnags ?? this.closedSnags,
      snagCategories: snagCategories ?? this.snagCategories,
      needsSiteSync: needsSiteSync ?? this.needsSiteSync,
      needsImageSync: needsImageSync ?? this.needsImageSync,
      needsSnagsSync: needsSnagsSync ?? this.needsSnagsSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSnagUpdate: lastSnagUpdate ?? this.lastSnagUpdate,
      updatedSnags: updatedSnags ?? this.updatedSnags,
      updateCount: updateCount ?? this.updateCount,
      markedForDeletion: markedForDeletion ?? this.markedForDeletion,
      deletionDate: deletionDate ?? this.deletionDate,
      scheduledDeletionDate: scheduledDeletionDate ?? this.scheduledDeletionDate,
      localVersion: localVersion ?? this.localVersion,
      firebaseVersion: firebaseVersion ?? this.firebaseVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUID': ownerUID,
      'ownerEmail': ownerEmail,
      'name': name,
      'companyName': companyName,
      'address': address,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'date': date.millisecondsSinceEpoch,
      'expectedCompletion': expectedCompletion?.millisecondsSinceEpoch,
      'imageLocalPath': imageLocalPath,
      'imageFirebasePath': imageFirebasePath,
      'pictureQuality': pictureQuality,
      'archive': archive,
      'sharedWith': sharedWith,
      'totalSnags': totalSnags,
      'openSnags': openSnags,
      'closedSnags': closedSnags,
      'snagCategories': snagCategories.map((key, value) => MapEntry(key.toString(), value)), // Convert int keys to string for JSON
      'needsSiteSync': needsSiteSync,
      'needsImageSync': needsImageSync,
      'needsSnagsSync': needsSnagsSync,
      'lastSyncTime': lastSyncTime?.millisecondsSinceEpoch,
      'lastSnagUpdate': lastSnagUpdate?.millisecondsSinceEpoch,
      'updatedSnags': updatedSnags,
      'updateCount': updateCount,
      'markedForDeletion': markedForDeletion,
      'deletionDate': deletionDate?.millisecondsSinceEpoch,
      'scheduledDeletionDate': scheduledDeletionDate?.millisecondsSinceEpoch,
      'localVersion': localVersion,
      'firebaseVersion': firebaseVersion,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database)
  factory Site.fromJson(Map<String, dynamic> json) {
    // Convert string keys back to int for snagCategories
    // Handle both null and empty cases properly
    final categoriesMap = json['snagCategories'] as Map<String, dynamic>? ?? {};
    final Map<int, String> snagCategories = categoriesMap.isEmpty 
        ? {}
        : categoriesMap.map((key, value) => 
            MapEntry(int.parse(key), value as String));
    
    return Site(
      id: json['id'] as String,
      ownerUID: json['ownerUID'] as String,
      ownerEmail: json['ownerEmail'] as String,
      name: json['name'] as String,
      companyName: json['companyName'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contactPerson'] as String?,
      contactPhone: json['contactPhone'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      expectedCompletion: json['expectedCompletion'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expectedCompletion'] as int)
          : null,
      imageLocalPath: json['imageLocalPath'] as String?,
      imageFirebasePath: json['imageFirebasePath'] as String?,
      pictureQuality: json['pictureQuality'] as int? ?? 1,
      archive: json['archive'] as bool? ?? false,
      sharedWith: Map<String, String>.from(json['sharedWith'] ?? {}),
      totalSnags: json['totalSnags'] as int? ?? 0,
      openSnags: json['openSnags'] as int? ?? 0,
      closedSnags: json['closedSnags'] as int? ?? 0,
      snagCategories: snagCategories,
      needsSiteSync: json['needsSiteSync'] as bool? ?? false,
      needsImageSync: json['needsImageSync'] as bool? ?? false,
      needsSnagsSync: json['needsSnagsSync'] as bool? ?? false,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSyncTime'] as int)
          : null,
      lastSnagUpdate: json['lastSnagUpdate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSnagUpdate'] as int)
          : null,
      updatedSnags: List<String>.from(json['updatedSnags'] ?? []),
      updateCount: json['updateCount'] as int? ?? 0,
      markedForDeletion: json['markedForDeletion'] as bool? ?? false,
      deletionDate: json['deletionDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deletionDate'] as int)
          : null,
      scheduledDeletionDate: json['scheduledDeletionDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['scheduledDeletionDate'] as int)
          : null,
      localVersion: json['localVersion'] as int? ?? 1,
      firebaseVersion: json['firebaseVersion'] as int? ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'ownerUID': ownerUID,
      'ownerEmail': ownerEmail,
      'name': name,
      'companyName': companyName,
      'address': address,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'date': Timestamp.fromDate(date),
      'expectedCompletion': expectedCompletion != null 
          ? Timestamp.fromDate(expectedCompletion!) 
          : null,
      'imageFirebasePath': imageFirebasePath,
      'pictureQuality': pictureQuality,
      'archive': archive,
      'sharedWith': sharedWith,
      'totalSnags': totalSnags,
      'openSnags': openSnags,
      'closedSnags': closedSnags,
      'snagCategories': snagCategories.map((key, value) => MapEntry(key.toString(), value)), // Store as string keys in Firestore
      'lastSnagUpdate': lastSnagUpdate != null
          ? Timestamp.fromDate(lastSnagUpdate!)
          : null,
      'updatedSnags': updatedSnags,
      'updateCount': updateCount,
      'markedForDeletion': markedForDeletion,
      'deletionDate': deletionDate != null
          ? Timestamp.fromDate(deletionDate!)
          : null,
      'scheduledDeletionDate': scheduledDeletionDate != null
          ? Timestamp.fromDate(scheduledDeletionDate!)
          : null,
      'firebaseVersion': firebaseVersion + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create from Firestore document
  factory Site.fromFirestore(String id, Map<String, dynamic> data) {
    // Convert string keys back to int for snagCategories
    // Handle both null and empty cases properly
    final categoriesMap = data['snagCategories'] as Map<String, dynamic>? ?? {};
    final Map<int, String> snagCategories = categoriesMap.isEmpty
        ? {}
        : categoriesMap.map((key, value) => 
            MapEntry(int.parse(key), value as String));
    
    return Site(
      id: id,
      ownerUID: data['ownerUID'] as String,
      ownerEmail: data['ownerEmail'] as String,
      name: data['name'] as String,
      companyName: data['companyName'] as String?,
      address: data['address'] as String?,
      contactPerson: data['contactPerson'] as String?,
      contactPhone: data['contactPhone'] as String?,
      date: (data['date'] as Timestamp).toDate(),
      expectedCompletion: data['expectedCompletion'] != null
          ? (data['expectedCompletion'] as Timestamp).toDate()
          : null,
      imageFirebasePath: data['imageFirebasePath'] as String?,
      pictureQuality: data['pictureQuality'] as int? ?? 1,
      archive: data['archive'] as bool? ?? false,
      sharedWith: Map<String, String>.from(data['sharedWith'] ?? {}),
      totalSnags: data['totalSnags'] as int? ?? 0,
      openSnags: data['openSnags'] as int? ?? 0,
      closedSnags: data['closedSnags'] as int? ?? 0,
      snagCategories: snagCategories,
      lastSnagUpdate: data['lastSnagUpdate'] != null
          ? (data['lastSnagUpdate'] as Timestamp).toDate()
          : null,
      updatedSnags: List<String>.from(data['updatedSnags'] ?? []),
      updateCount: data['updateCount'] as int? ?? 0,
      markedForDeletion: data['markedForDeletion'] as bool? ?? false,
      deletionDate: data['deletionDate'] != null
          ? (data['deletionDate'] as Timestamp).toDate()
          : null,
      scheduledDeletionDate: data['scheduledDeletionDate'] != null
          ? (data['scheduledDeletionDate'] as Timestamp).toDate()
          : null,
      firebaseVersion: data['firebaseVersion'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      localVersion: 1,
    );
  }

  /// Check if the given user is the owner of this site
  /// 
  /// Returns true if the provided email matches the site owner's email
  /// (case-insensitive comparison)
  bool isOwnedBy(String userEmail) => ownerEmail.toLowerCase() == userEmail.toLowerCase();
  
  /// Get the permission level for a given user
  /// 
  /// Returns:
  /// - null if user is the owner (owners don't have permission entries)
  /// - 'VIEW', 'FIXER', or 'CONTRIBUTOR' if user has been shared with
  /// - null if user has no access to this site
  String? getPermissionFor(String userEmail) {
    if (isOwnedBy(userEmail)) return null; // Owner doesn't have a permission entry
    return sharedWith[userEmail.toLowerCase()];
  }
  
  /// Check if user can edit site details
  /// 
  /// Returns true if:
  /// - User is the owner
  /// - User has CONTRIBUTOR permission
  /// 
  /// Note: FIXER and VIEW permissions cannot edit site details
  bool canEdit(String userEmail) {
    if (isOwnedBy(userEmail)) return true;
    final permission = getPermissionFor(userEmail);
    return permission == 'CONTRIBUTOR';
  }
  
  /// Check if user can create new snags in this site
  /// 
  /// Returns true if:
  /// - User is the owner
  /// - User has CONTRIBUTOR permission
  /// 
  /// Note: FIXER can only work on assigned snags, VIEW is read-only
  bool canCreateSnags(String userEmail) {
    if (isOwnedBy(userEmail)) return true;
    final permission = getPermissionFor(userEmail);
    return permission == 'CONTRIBUTOR';
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Site &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}