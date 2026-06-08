import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/Data/models/image_slot.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/services/snag_image_paths.dart';

/// Service for handling snag image operations (pick, remove, download)
///
/// Follows offline-first patterns:
/// - INSTANT operations for existing snags (no waiting for Save button)
/// - Local storage first, Firebase sync in background
/// - Version counter in ImageSlot for race condition detection
///
/// See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md
class SnagImageService {
  static SnagImageService? _instance;

  SnagImageService._();

  static SnagImageService get instance {
    _instance ??= SnagImageService._();
    return _instance!;
  }

  /// Public constructor for testing
  SnagImageService();

  // ============== Pick Image ==============

  /// Pick and save an image for a snag slot
  ///
  /// For EXISTING snags: Updates database instantly
  /// For NEW snags: Returns updated ImageSlot (caller stores in UI state)
  ///
  /// Returns: Updated ImageSlot on success, null on cancel
  /// Throws: [ImageTooLargeException], [InvalidImageException]
  Future<ImageSlot?> pickImage({
    required ImageSource source,
    Snag? snag,
    required int slotIndex,
    required bool isFix,
    required String userId,
    required String siteId,
    required String snagId,
    required String ownerUID,
  }) async {
    assert(slotIndex >= 0 && slotIndex <= 5, 'Slot index must be 0-5');

    // 1. Pick image
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile == null) {
      if (kDebugMode) print('SnagImageService: User cancelled pick');
      return null;
    }

    // 2. Compress
    final bytes = await pickedFile.readAsBytes();
    final compressionService = ImageCompressionService.instance;
    final result = await compressionService.processSiteImageFromBytes(bytes);

    // 3. Compute paths
    final localPath = SnagImagePaths.localPath(
      userId: userId,
      siteId: siteId,
      snagId: snagId,
      index: slotIndex,
      isFix: isFix,
    );
    final firebasePath = SnagImagePaths.firebasePath(
      ownerUID: ownerUID,
      siteId: siteId,
      snagId: snagId,
      index: slotIndex,
      isFix: isFix,
    );

    // 4. Save to local storage
    await _saveToLocal(localPath, result.data);

    // 5. Update ImageSlot (setImage increments version)
    final currentSlot = snag != null
        ? (isFix ? snag.fixImages[slotIndex] : snag.images[slotIndex])
        : ImageSlot.empty;
    final updatedSlot = currentSlot.setImage(localPath, firebasePath);

    // 6. Instant DB update for existing snag
    if (snag != null) {
      await _updateSlotInDb(snag.id, slotIndex, updatedSlot, isFix);
    }

    if (kDebugMode) {
      print('SnagImageService: Picked slot $slotIndex (isFix=$isFix)');
      print('  Local: $localPath');
      print('  ${result.message}');
    }

    return updatedSlot;
  }

  // ============== Pick Multiple Images ==============

  /// Pick multiple images from gallery for NEW snags only
  ///
  /// Fills available slots starting from slot 0, up to 6 images total.
  /// Returns: List of (slotIndex, ImageSlot) pairs for picked images
  ///
  /// For EXISTING snags, use pickImage() instead for instant DB updates.
  Future<List<(int, ImageSlot)>> pickMultipleImages({
    required String userId,
    required String siteId,
    required String snagId,
    required String ownerUID,
    required List<ImageSlot> currentSlots,
    required bool isFix,
    int maxImages = 6,
  }) async {
    // 1. Pick multiple images from gallery
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFiles.isEmpty) {
      if (kDebugMode) print('SnagImageService: User cancelled multi-pick');
      return [];
    }

    // 2. Find available slots
    final List<int> availableSlots = [];
    for (int i = 0; i < currentSlots.length && availableSlots.length < maxImages; i++) {
      if (!currentSlots[i].hasImage) {
        availableSlots.add(i);
      }
    }

    if (availableSlots.isEmpty) {
      if (kDebugMode) print('SnagImageService: No available slots');
      return [];
    }

    // 3. Process images (limited by available slots)
    final int imagesToProcess = pickedFiles.length.clamp(0, availableSlots.length);
    final List<(int, ImageSlot)> results = [];
    final compressionService = ImageCompressionService.instance;

    for (int i = 0; i < imagesToProcess; i++) {
      final slotIndex = availableSlots[i];
      final pickedFile = pickedFiles[i];

      try {
        // Compress
        final bytes = await pickedFile.readAsBytes();
        final result = await compressionService.processSiteImageFromBytes(bytes);

        // Compute paths
        final localPath = SnagImagePaths.localPath(
          userId: userId,
          siteId: siteId,
          snagId: snagId,
          index: slotIndex,
          isFix: isFix,
        );
        final firebasePath = SnagImagePaths.firebasePath(
          ownerUID: ownerUID,
          siteId: siteId,
          snagId: snagId,
          index: slotIndex,
          isFix: isFix,
        );

        // Save to local storage
        await _saveToLocal(localPath, result.data);

        // Create ImageSlot
        final updatedSlot = ImageSlot.empty.setImage(localPath, firebasePath);
        results.add((slotIndex, updatedSlot));

        if (kDebugMode) {
          print('SnagImageService: Multi-pick slot $slotIndex - ${result.message}');
        }
      } catch (e) {
        if (kDebugMode) print('SnagImageService: Error processing image $i: $e');
        // Continue with remaining images
      }
    }

    if (kDebugMode) {
      print('SnagImageService: Multi-picked ${results.length} images');
    }

    return results;
  }

  // ============== Remove Image ==============

  /// Remove an image from a snag slot
  ///
  /// For EXISTING snags: Updates database instantly
  /// For NEW snags: Returns updated ImageSlot (caller updates UI state)
  ///
  /// Returns: Updated ImageSlot with markedForDeletion=true
  Future<ImageSlot> removeImage({
    Snag? snag,
    required int slotIndex,
    required bool isFix,
  }) async {
    assert(slotIndex >= 0 && slotIndex <= 5, 'Slot index must be 0-5');

    // 1. Get current slot
    final currentSlot = snag != null
        ? (isFix ? snag.fixImages[slotIndex] : snag.images[slotIndex])
        : ImageSlot.empty;

    // 2. Early return if slot is already empty (nothing to remove)
    if (currentSlot.isEmpty) {
      if (kDebugMode) print('SnagImageService: Slot $slotIndex already empty');
      return currentSlot;
    }

    // 3. Delete local file if exists
    if (currentSlot.localPath != null) {
      await _deleteLocalFile(currentSlot.localPath!);
    }

    // 4. Update ImageSlot (clearLocalPath sets markedForDeletion, increments version)
    final updatedSlot = currentSlot.clearLocalPath();

    // 5. Instant DB update for existing snag
    if (snag != null) {
      await _updateSlotInDb(snag.id, slotIndex, updatedSlot, isFix);
    }

    if (kDebugMode) {
      print('SnagImageService: Removed slot $slotIndex (isFix=$isFix)');
    }

    return updatedSlot;
  }

  // ============== Download Image ==============

  // TODO: Implement downloadImage() when shared user functionality is ready
  // This will download images from Firebase for shared users who don't have local copies.
  // See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md - Download Flow section

  // ============== Cleanup ==============

  /// Delete all local images for a snag (when snag is deleted)
  Future<void> deleteAllSnagImages({
    required String userId,
    required String siteId,
    required String snagId,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final snagDir = Directory(
        p.join(appDir.path, 'SnagSnapper', userId, 'Sites', siteId, 'Snags', snagId),
      );

      if (await snagDir.exists()) {
        await snagDir.delete(recursive: true);
        if (kDebugMode) {
          print('SnagImageService: Deleted snag directory: ${snagDir.path}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('SnagImageService: Error deleting snag images: $e');
    }
  }

  /// Delete orphaned images for unsaved new snag (called on Back)
  Future<void> cleanupOrphanedImages({
    required String userId,
    required String siteId,
    required String snagId,
  }) async {
    await deleteAllSnagImages(userId: userId, siteId: siteId, snagId: snagId);
    if (kDebugMode) {
      print('SnagImageService: Cleaned up orphaned images for unsaved snag $snagId');
    }
  }

  // ============== Path Utilities ==============

  /// Get absolute path from relative path (for UI to display images)
  Future<String> getAbsolutePath(String relativePath) async {
    return _getAbsolutePath(relativePath);
  }

  // ============== Private Helpers ==============

  Future<String> _getAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, relativePath);
  }

  Future<void> _deleteLocalFile(String relativePath) async {
    try {
      final absolutePath = await _getAbsolutePath(relativePath);
      final file = File(absolutePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Don't throw - deletion failure is not critical
      if (kDebugMode) print('SnagImageService: Error deleting file: $e');
    }
  }

  Future<void> _saveToLocal(String relativePath, Uint8List bytes) async {
    final absolutePath = await _getAbsolutePath(relativePath);
    final file = File(absolutePath);

    // Create directory if needed
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await file.writeAsBytes(bytes);
  }

  Future<void> _updateSlotInDb(
    String snagId,
    int slotIndex,
    ImageSlot updatedSlot,
    bool isFix,
  ) async {
    final snagDao = AppDatabase.instance.snagDao;
    final snag = await snagDao.getSnagById(snagId);
    if (snag == null) return;

    if (isFix) {
      final list = List<ImageSlot>.from(snag.fixImages);
      list[slotIndex] = updatedSlot;
      await snagDao.updateSnagFixImages(snagId, list);
    } else {
      final list = List<ImageSlot>.from(snag.images);
      list[slotIndex] = updatedSlot;
      await snagDao.updateSnagImages(snagId, list);
    }
  }
}