import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Snag model for offline-first snag management
/// Implements PRD Section 4.2.2 specifications
/// Core data model for construction defect tracking
@immutable
class Snag {
  // Identity
  final String id; // UUID v4 (locally generated)
  final String siteUID; // Parent site ID
  final String ownerEmail; // Site owner email
  final String creatorEmail; // Who created the snag
  
  // Core Fields (Owner-editable, Colleague read-only)
  final String title; // Required - Snag title
  final String? description; // Optional - Problem description
  final String? location; // Optional - Location in site
  final int? priority; // Optional - Priority level (1-5)
  final DateTime? dueDate; // Optional - Due date
  final DateTime creationDate; // Auto-set creation date
  final String? snagCategory; // Optional - Category from site list
  
  // Assignment (Owner-only)
  final String? assignedEmail; // Assigned colleague email
  final String? assignedName; // Assigned colleague name
  
  // Problem Documentation (Owner-only)
  final String? imageMain1LocalPath;
  final String? imageMain1FirebasePath;
  final String? image2LocalPath;
  final String? image2FirebasePath;
  final String? image3LocalPath;
  final String? image3FirebasePath;
  final String? image4LocalPath;
  final String? image4FirebasePath;
  
  // Fix Documentation (Colleague-editable when assigned)
  final String? snagFixDescription; // How it was fixed
  final String? snagFixMainImageLocalPath;
  final String? snagFixMainImageFirebasePath;
  final String? snagFixImage1LocalPath;
  final String? snagFixImage1FirebasePath;
  final String? snagFixImage2LocalPath;
  final String? snagFixImage2FirebasePath;
  final String? snagFixImage3LocalPath;
  final String? snagFixImage3FirebasePath;
  
  // Status (Two-boolean system)
  final bool snagStatus; // true=open, false=completed by FIXER
  final bool snagConfirmedStatus; // true=pending, false=confirmed closed by owner
  
  // Tracking Fields
  final String? lastModifiedBy; // Email of last modifier
  final DateTime? lastModifiedDate; // When last modified
  final DateTime? completedDate; // When FIXER marked complete
  final String? rejectionReason; // Why owner rejected fix
  final int rejectionCount; // Number of rejections
  final double? costEstimate; // Optional cost estimate
  
  // Sync Management
  final bool needsSnagSync; // Snag data changed
  final bool needsImagesSync; // Images changed
  final DateTime? lastSyncTime;
  
  // Versioning
  final int localVersion;
  final int firebaseVersion;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const Snag({
    required this.id,
    required this.siteUID,
    required this.ownerEmail,
    required this.creatorEmail,
    required this.title,
    this.description,
    this.location,
    this.priority,
    this.dueDate,
    required this.creationDate,
    this.snagCategory,
    this.assignedEmail,
    this.assignedName,
    this.imageMain1LocalPath,
    this.imageMain1FirebasePath,
    this.image2LocalPath,
    this.image2FirebasePath,
    this.image3LocalPath,
    this.image3FirebasePath,
    this.image4LocalPath,
    this.image4FirebasePath,
    this.snagFixDescription,
    this.snagFixMainImageLocalPath,
    this.snagFixMainImageFirebasePath,
    this.snagFixImage1LocalPath,
    this.snagFixImage1FirebasePath,
    this.snagFixImage2LocalPath,
    this.snagFixImage2FirebasePath,
    this.snagFixImage3LocalPath,
    this.snagFixImage3FirebasePath,
    this.snagStatus = true, // Default to open
    this.snagConfirmedStatus = true, // Default to pending
    this.lastModifiedBy,
    this.lastModifiedDate,
    this.completedDate,
    this.rejectionReason,
    this.rejectionCount = 0,
    this.costEstimate,
    this.needsSnagSync = false,
    this.needsImagesSync = false,
    this.lastSyncTime,
    this.localVersion = 1,
    this.firebaseVersion = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new snag with default values
  factory Snag.create({
    required String id,
    required String siteUID,
    required String ownerEmail,
    required String creatorEmail,
    required String title,
    String? description,
    String? location,
    int? priority,
    DateTime? dueDate,
    String? snagCategory,
  }) {
    final now = DateTime.now();
    return Snag(
      id: id,
      siteUID: siteUID,
      ownerEmail: ownerEmail,
      creatorEmail: creatorEmail,
      title: title,
      description: description,
      location: location,
      priority: priority,
      dueDate: dueDate,
      creationDate: now,
      snagCategory: snagCategory,
      createdAt: now,
      updatedAt: now,
      needsSnagSync: true, // Mark for initial sync
    );
  }

  /// Create a copy with updated fields
  Snag copyWith({
    String? id,
    String? siteUID,
    String? ownerEmail,
    String? creatorEmail,
    String? title,
    String? description,
    String? location,
    int? priority,
    DateTime? dueDate,
    DateTime? creationDate,
    String? snagCategory,
    String? assignedEmail,
    String? assignedName,
    String? imageMain1LocalPath,
    String? imageMain1FirebasePath,
    String? image2LocalPath,
    String? image2FirebasePath,
    String? image3LocalPath,
    String? image3FirebasePath,
    String? image4LocalPath,
    String? image4FirebasePath,
    String? snagFixDescription,
    String? snagFixMainImageLocalPath,
    String? snagFixMainImageFirebasePath,
    String? snagFixImage1LocalPath,
    String? snagFixImage1FirebasePath,
    String? snagFixImage2LocalPath,
    String? snagFixImage2FirebasePath,
    String? snagFixImage3LocalPath,
    String? snagFixImage3FirebasePath,
    bool? snagStatus,
    bool? snagConfirmedStatus,
    String? lastModifiedBy,
    DateTime? lastModifiedDate,
    DateTime? completedDate,
    String? rejectionReason,
    int? rejectionCount,
    double? costEstimate,
    bool? needsSnagSync,
    bool? needsImagesSync,
    DateTime? lastSyncTime,
    int? localVersion,
    int? firebaseVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Snag(
      id: id ?? this.id,
      siteUID: siteUID ?? this.siteUID,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      creationDate: creationDate ?? this.creationDate,
      snagCategory: snagCategory ?? this.snagCategory,
      assignedEmail: assignedEmail ?? this.assignedEmail,
      assignedName: assignedName ?? this.assignedName,
      imageMain1LocalPath: imageMain1LocalPath ?? this.imageMain1LocalPath,
      imageMain1FirebasePath: imageMain1FirebasePath ?? this.imageMain1FirebasePath,
      image2LocalPath: image2LocalPath ?? this.image2LocalPath,
      image2FirebasePath: image2FirebasePath ?? this.image2FirebasePath,
      image3LocalPath: image3LocalPath ?? this.image3LocalPath,
      image3FirebasePath: image3FirebasePath ?? this.image3FirebasePath,
      image4LocalPath: image4LocalPath ?? this.image4LocalPath,
      image4FirebasePath: image4FirebasePath ?? this.image4FirebasePath,
      snagFixDescription: snagFixDescription ?? this.snagFixDescription,
      snagFixMainImageLocalPath: snagFixMainImageLocalPath ?? this.snagFixMainImageLocalPath,
      snagFixMainImageFirebasePath: snagFixMainImageFirebasePath ?? this.snagFixMainImageFirebasePath,
      snagFixImage1LocalPath: snagFixImage1LocalPath ?? this.snagFixImage1LocalPath,
      snagFixImage1FirebasePath: snagFixImage1FirebasePath ?? this.snagFixImage1FirebasePath,
      snagFixImage2LocalPath: snagFixImage2LocalPath ?? this.snagFixImage2LocalPath,
      snagFixImage2FirebasePath: snagFixImage2FirebasePath ?? this.snagFixImage2FirebasePath,
      snagFixImage3LocalPath: snagFixImage3LocalPath ?? this.snagFixImage3LocalPath,
      snagFixImage3FirebasePath: snagFixImage3FirebasePath ?? this.snagFixImage3FirebasePath,
      snagStatus: snagStatus ?? this.snagStatus,
      snagConfirmedStatus: snagConfirmedStatus ?? this.snagConfirmedStatus,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      lastModifiedDate: lastModifiedDate ?? this.lastModifiedDate,
      completedDate: completedDate ?? this.completedDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectionCount: rejectionCount ?? this.rejectionCount,
      costEstimate: costEstimate ?? this.costEstimate,
      needsSnagSync: needsSnagSync ?? this.needsSnagSync,
      needsImagesSync: needsImagesSync ?? this.needsImagesSync,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      localVersion: localVersion ?? this.localVersion,
      firebaseVersion: firebaseVersion ?? this.firebaseVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if snag is open (not completed)
  bool get isOpen => snagStatus;
  
  /// Check if snag is completed by fixer but pending owner confirmation
  bool get isPendingConfirmation => !snagStatus && snagConfirmedStatus;
  
  /// Check if snag is fully closed (confirmed by owner)
  bool get isClosed => !snagStatus && !snagConfirmedStatus;
  
  /// Check if snag is assigned to someone
  bool get isAssigned => assignedEmail != null && assignedEmail!.isNotEmpty;

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteUID': siteUID,
      'ownerEmail': ownerEmail,
      'creatorEmail': creatorEmail,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'creationDate': creationDate.millisecondsSinceEpoch,
      'snagCategory': snagCategory,
      'assignedEmail': assignedEmail,
      'assignedName': assignedName,
      'imageMain1LocalPath': imageMain1LocalPath,
      'imageMain1FirebasePath': imageMain1FirebasePath,
      'image2LocalPath': image2LocalPath,
      'image2FirebasePath': image2FirebasePath,
      'image3LocalPath': image3LocalPath,
      'image3FirebasePath': image3FirebasePath,
      'image4LocalPath': image4LocalPath,
      'image4FirebasePath': image4FirebasePath,
      'snagFixDescription': snagFixDescription,
      'snagFixMainImageLocalPath': snagFixMainImageLocalPath,
      'snagFixMainImageFirebasePath': snagFixMainImageFirebasePath,
      'snagFixImage1LocalPath': snagFixImage1LocalPath,
      'snagFixImage1FirebasePath': snagFixImage1FirebasePath,
      'snagFixImage2LocalPath': snagFixImage2LocalPath,
      'snagFixImage2FirebasePath': snagFixImage2FirebasePath,
      'snagFixImage3LocalPath': snagFixImage3LocalPath,
      'snagFixImage3FirebasePath': snagFixImage3FirebasePath,
      'snagStatus': snagStatus,
      'snagConfirmedStatus': snagConfirmedStatus,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedDate': lastModifiedDate?.millisecondsSinceEpoch,
      'completedDate': completedDate?.millisecondsSinceEpoch,
      'rejectionReason': rejectionReason,
      'rejectionCount': rejectionCount,
      'costEstimate': costEstimate,
      'needsSnagSync': needsSnagSync,
      'needsImagesSync': needsImagesSync,
      'lastSyncTime': lastSyncTime?.millisecondsSinceEpoch,
      'localVersion': localVersion,
      'firebaseVersion': firebaseVersion,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON (database)
  factory Snag.fromJson(Map<String, dynamic> json) {
    return Snag(
      id: json['id'] as String,
      siteUID: json['siteUID'] as String,
      ownerEmail: json['ownerEmail'] as String,
      creatorEmail: json['creatorEmail'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      priority: json['priority'] as int?,
      dueDate: json['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['dueDate'] as int)
          : null,
      creationDate: DateTime.fromMillisecondsSinceEpoch(json['creationDate'] as int),
      snagCategory: json['snagCategory'] as String?,
      assignedEmail: json['assignedEmail'] as String?,
      assignedName: json['assignedName'] as String?,
      imageMain1LocalPath: json['imageMain1LocalPath'] as String?,
      imageMain1FirebasePath: json['imageMain1FirebasePath'] as String?,
      image2LocalPath: json['image2LocalPath'] as String?,
      image2FirebasePath: json['image2FirebasePath'] as String?,
      image3LocalPath: json['image3LocalPath'] as String?,
      image3FirebasePath: json['image3FirebasePath'] as String?,
      image4LocalPath: json['image4LocalPath'] as String?,
      image4FirebasePath: json['image4FirebasePath'] as String?,
      snagFixDescription: json['snagFixDescription'] as String?,
      snagFixMainImageLocalPath: json['snagFixMainImageLocalPath'] as String?,
      snagFixMainImageFirebasePath: json['snagFixMainImageFirebasePath'] as String?,
      snagFixImage1LocalPath: json['snagFixImage1LocalPath'] as String?,
      snagFixImage1FirebasePath: json['snagFixImage1FirebasePath'] as String?,
      snagFixImage2LocalPath: json['snagFixImage2LocalPath'] as String?,
      snagFixImage2FirebasePath: json['snagFixImage2FirebasePath'] as String?,
      snagFixImage3LocalPath: json['snagFixImage3LocalPath'] as String?,
      snagFixImage3FirebasePath: json['snagFixImage3FirebasePath'] as String?,
      snagStatus: json['snagStatus'] as bool? ?? true,
      snagConfirmedStatus: json['snagConfirmedStatus'] as bool? ?? true,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      lastModifiedDate: json['lastModifiedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastModifiedDate'] as int)
          : null,
      completedDate: json['completedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedDate'] as int)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      rejectionCount: json['rejectionCount'] as int? ?? 0,
      costEstimate: json['costEstimate'] as double?,
      needsSnagSync: json['needsSnagSync'] as bool? ?? false,
      needsImagesSync: json['needsImagesSync'] as bool? ?? false,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSyncTime'] as int)
          : null,
      localVersion: json['localVersion'] as int? ?? 1,
      firebaseVersion: json['firebaseVersion'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'siteUID': siteUID,
      'ownerEmail': ownerEmail,
      'creatorEmail': creatorEmail,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'creationDate': Timestamp.fromDate(creationDate),
      'snagCategory': snagCategory,
      'assignedEmail': assignedEmail,
      'assignedName': assignedName,
      'imageMain1FirebasePath': imageMain1FirebasePath,
      'image2FirebasePath': image2FirebasePath,
      'image3FirebasePath': image3FirebasePath,
      'image4FirebasePath': image4FirebasePath,
      'snagFixDescription': snagFixDescription,
      'snagFixMainImageFirebasePath': snagFixMainImageFirebasePath,
      'snagFixImage1FirebasePath': snagFixImage1FirebasePath,
      'snagFixImage2FirebasePath': snagFixImage2FirebasePath,
      'snagFixImage3FirebasePath': snagFixImage3FirebasePath,
      'snagStatus': snagStatus,
      'snagConfirmedStatus': snagConfirmedStatus,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedDate': lastModifiedDate != null
          ? Timestamp.fromDate(lastModifiedDate!)
          : null,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'rejectionReason': rejectionReason,
      'rejectionCount': rejectionCount,
      'costEstimate': costEstimate,
      'firebaseVersion': firebaseVersion + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create from Firestore document
  factory Snag.fromFirestore(String id, Map<String, dynamic> data) {
    return Snag(
      id: id,
      siteUID: data['siteUID'] as String,
      ownerEmail: data['ownerEmail'] as String,
      creatorEmail: data['creatorEmail'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      location: data['location'] as String?,
      priority: data['priority'] as int?,
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      creationDate: (data['creationDate'] as Timestamp).toDate(),
      snagCategory: data['snagCategory'] as String?,
      assignedEmail: data['assignedEmail'] as String?,
      assignedName: data['assignedName'] as String?,
      imageMain1FirebasePath: data['imageMain1FirebasePath'] as String?,
      image2FirebasePath: data['image2FirebasePath'] as String?,
      image3FirebasePath: data['image3FirebasePath'] as String?,
      image4FirebasePath: data['image4FirebasePath'] as String?,
      snagFixDescription: data['snagFixDescription'] as String?,
      snagFixMainImageFirebasePath: data['snagFixMainImageFirebasePath'] as String?,
      snagFixImage1FirebasePath: data['snagFixImage1FirebasePath'] as String?,
      snagFixImage2FirebasePath: data['snagFixImage2FirebasePath'] as String?,
      snagFixImage3FirebasePath: data['snagFixImage3FirebasePath'] as String?,
      snagStatus: data['snagStatus'] as bool? ?? true,
      snagConfirmedStatus: data['snagConfirmedStatus'] as bool? ?? true,
      lastModifiedBy: data['lastModifiedBy'] as String?,
      lastModifiedDate: data['lastModifiedDate'] != null
          ? (data['lastModifiedDate'] as Timestamp).toDate()
          : null,
      completedDate: data['completedDate'] != null
          ? (data['completedDate'] as Timestamp).toDate()
          : null,
      rejectionReason: data['rejectionReason'] as String?,
      rejectionCount: data['rejectionCount'] as int? ?? 0,
      costEstimate: data['costEstimate'] as double?,
      firebaseVersion: data['firebaseVersion'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      localVersion: 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snag &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}