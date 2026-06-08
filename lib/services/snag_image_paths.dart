/// Helper class for computing snag image storage paths.
///
/// Provides static methods for generating local and Firebase storage paths
/// for snag images. Supports both problem photos (documenting defects) and
/// fix photos (documenting repairs).
///
/// Path Patterns (Profile-centric structure):
/// - Local: `SnagSnapper/{userId}/Sites/{siteId}/Snags/{snagId}/[fix/]{index}.jpg`
/// - Firebase: `Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/[fix/]{index}.jpg`
///
/// SYNC: Firebase path must match storage.rules
/// Index is 0-5 (6 slots per category).
class SnagImagePaths {
  SnagImagePaths._(); // Prevent instantiation

  /// Compute relative local path for a snag image.
  ///
  /// This returns a relative path (starting with `SnagSnapper/`) that can be
  /// stored in the database and converted to absolute path using
  /// `ImageStorageService.relativeToAbsolute()`.
  ///
  /// Parameters:
  /// - [userId]: Current user's ID (for local storage organization)
  /// - [siteId]: Site this snag belongs to
  /// - [snagId]: Unique snag identifier
  /// - [index]: Slot index (0-5)
  /// - [isFix]: If true, returns path for fix photos; otherwise problem photos
  static String localPath({
    required String userId,
    required String siteId,
    required String snagId,
    required int index,
    bool isFix = false,
  }) {
    assert(index >= 0 && index <= 5, 'Index must be 0-5');
    final fixSegment = isFix ? '/fix' : '';
    return 'SnagSnapper/$userId/Sites/$siteId/Snags/$snagId$fixSegment/$index.jpg';
  }

  /// Compute Firebase Storage path for a snag image.
  ///
  /// This returns the full Firebase Storage path where the image will be
  /// uploaded. Uses ownerUID (not current user) to ensure all shared users
  /// access the same location.
  ///
  /// Path: Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/[fix/]{index}.jpg
  ///
  /// Parameters:
  /// - [ownerUID]: Site owner's UID (determines Firebase storage location)
  /// - [siteId]: Site this snag belongs to
  /// - [snagId]: Unique snag identifier
  /// - [index]: Slot index (0-5)
  /// - [isFix]: If true, returns path for fix photos; otherwise problem photos
  static String firebasePath({
    required String ownerUID,
    required String siteId,
    required String snagId,
    required int index,
    bool isFix = false,
  }) {
    assert(index >= 0 && index <= 5, 'Index must be 0-5');
    final fixSegment = isFix ? '/fix' : '';
    return 'Profile/$ownerUID/Sites/$siteId/Snags/$snagId$fixSegment/$index.jpg';
  }

  /// Extract the slot index from a local or Firebase path.
  ///
  /// Returns the index (0-5) extracted from the filename, or -1 if invalid.
  static int extractIndex(String path) {
    // Path ends with {index}.jpg
    final filename = path.split('/').last;
    final match = RegExp(r'^(\d)\.jpg$').firstMatch(filename);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return -1;
  }

  /// Check if a path is for a fix image.
  static bool isFixPath(String path) {
    return path.contains('/fix/');
  }
}
