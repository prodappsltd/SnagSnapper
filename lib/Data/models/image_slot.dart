import 'package:flutter/foundation.dart';

/// Represents a single image slot for Snag photos
///
/// Used for both problem photos (documenting defects) and fix photos (documenting repairs).
/// Each snag has 6 problem photo slots and 6 fix photo slots.
///
/// Key features:
/// - Tracks local and Firebase paths separately
/// - Sync flags for offline-first architecture
/// - Version counter for race condition detection during sync
///
/// See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md
@immutable
class ImageSlot {
  /// Relative path to local file (null = empty slot)
  final String? localPath;

  /// Firebase Storage path (kept for deletion reference even after local removal)
  final String? firebasePath;

  /// True when this slot needs upload or delete sync
  final bool needsSync;

  /// True when Firebase image should be deleted
  /// Preserved on Pick after Remove to handle overwrite scenario
  final bool markedForDeletion;

  /// Incremented on every Pick and Remove operation
  /// Used to detect user changes during sync (race condition prevention)
  final int version;

  const ImageSlot({
    this.localPath,
    this.firebasePath,
    this.needsSync = false,
    this.markedForDeletion = false,
    this.version = 0,
  });

  // ============== Getters ==============

  /// True if slot has a local image file
  bool get hasImage => localPath != null && localPath!.isNotEmpty;

  /// True if slot is completely empty (no image, no pending actions)
  bool get isEmpty => !hasImage && !markedForDeletion;

  /// True if slot needs attention during sync (upload or delete)
  bool get needsAttention => needsSync || markedForDeletion;

  // ============== State Transition Methods ==============

  /// Create copy with updated fields
  ///
  /// Use [clearLocal] to set localPath to null.
  /// Use [clearFirebase] to set firebasePath to null.
  ImageSlot copyWith({
    String? localPath,
    String? firebasePath,
    bool? needsSync,
    bool? markedForDeletion,
    int? version,
    bool clearLocal = false,
    bool clearFirebase = false,
  }) {
    return ImageSlot(
      localPath: clearLocal ? null : (localPath ?? this.localPath),
      firebasePath: clearFirebase ? null : (firebasePath ?? this.firebasePath),
      needsSync: needsSync ?? this.needsSync,
      markedForDeletion: markedForDeletion ?? this.markedForDeletion,
      version: version ?? this.version,
    );
  }

  /// Clear local path for image removal
  ///
  /// - Sets localPath to null
  /// - Keeps firebasePath for deletion reference
  /// - Sets needsSync and markedForDeletion to true
  /// - Increments version for race condition detection
  ImageSlot clearLocalPath() {
    return ImageSlot(
      localPath: null,
      firebasePath: firebasePath,
      needsSync: true,
      markedForDeletion: true,
      version: version + 1,
    );
  }

  /// Set new image in this slot
  ///
  /// - Sets localPath and firebasePath
  /// - Sets needsSync to true
  /// - Preserves markedForDeletion (handles Remove -> Pick scenario)
  /// - Increments version for race condition detection
  ImageSlot setImage(String newLocalPath, String newFirebasePath) {
    return ImageSlot(
      localPath: newLocalPath,
      firebasePath: newFirebasePath,
      needsSync: true,
      markedForDeletion: markedForDeletion,
      version: version + 1,
    );
  }

  /// Mark slot as synced after successful sync
  ///
  /// - Clears needsSync and markedForDeletion flags
  /// - Clears firebasePath if image was deleted (no local image)
  /// - Preserves version (don't reset)
  ImageSlot markSynced() {
    return ImageSlot(
      localPath: localPath,
      firebasePath: hasImage ? firebasePath : null,
      needsSync: false,
      markedForDeletion: false,
      version: version,
    );
  }

  // ============== Static Helpers ==============

  /// Empty slot constant
  static const ImageSlot empty = ImageSlot();

  /// Create list of 6 empty slots
  static List<ImageSlot> emptyList() => List.generate(6, (_) => empty);

  // ============== JSON Serialization ==============

  /// Convert to JSON for database/Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'localPath': localPath,
      'firebasePath': firebasePath,
      'needsSync': needsSync,
      'markedForDeletion': markedForDeletion,
      'version': version,
    };
  }

  /// Create from JSON (database/Firestore)
  factory ImageSlot.fromJson(Map<String, dynamic> json) {
    return ImageSlot(
      localPath: json['localPath'] as String?,
      firebasePath: json['firebasePath'] as String?,
      needsSync: json['needsSync'] as bool? ?? false,
      markedForDeletion: json['markedForDeletion'] as bool? ?? false,
      version: json['version'] as int? ?? 0,
    );
  }

  /// Convert list of ImageSlots to JSON list
  static List<Map<String, dynamic>> listToJson(List<ImageSlot> slots) {
    return slots.map((slot) => slot.toJson()).toList();
  }

  /// Create list of ImageSlots from JSON list
  static List<ImageSlot> listFromJson(List<dynamic>? jsonList) {
    if (jsonList == null || jsonList.isEmpty) {
      return emptyList();
    }

    // Ensure we always have exactly 6 slots
    final slots = <ImageSlot>[];
    for (int i = 0; i < 6; i++) {
      if (i < jsonList.length && jsonList[i] != null) {
        slots.add(ImageSlot.fromJson(jsonList[i] as Map<String, dynamic>));
      } else {
        slots.add(empty);
      }
    }
    return slots;
  }

}
