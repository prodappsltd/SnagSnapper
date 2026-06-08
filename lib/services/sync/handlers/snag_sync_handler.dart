import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/image_slot.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/services/snag_image_service.dart';

/// Handles synchronization of Snag data and images between local database and Firebase.
///
/// Key features:
/// - Per-slot sync (6 problem slots + 6 fix slots)
/// - Version comparison to detect user changes during sync (race condition fix)
/// - Individual error handling per slot (one failure doesn't block others)
///
/// Firebase paths (Profile-centric structure):
/// - Snag data: Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId} (Firestore)
/// - Problem photos: Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/{index}.jpg (Storage)
/// - Fix photos: Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}/fix/{index}.jpg (Storage)
///
/// SYNC: Paths must match firestore.rules and storage.rules
///
/// See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md
class SnagSyncHandler {
  final AppDatabase database;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final SnagImageService snagImageService;

  SnagSyncHandler({
    required this.database,
    required this.firestore,
    required this.storage,
    required this.snagImageService,
  }) {
    if (kDebugMode) {
      print('SnagSyncHandler: Initialized');
    }
  }

  // ============== Public Sync Methods ==============

  /// Syncs snag text data to Firestore
  ///
  /// Steps:
  /// 1. Get snag from local DB by ID
  /// 2. Get parent site to obtain ownerUID
  /// 3. Check needsSnagSync flag
  /// 4. Validate snag data
  /// 5. Upload to Firestore Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}
  /// 6. Clear needsSnagSync flag on success
  ///
  /// Returns true if sync succeeded or was not needed
  Future<bool> syncSnagData(String snagId) async {
    try {
      if (kDebugMode) {
        print('SnagSyncHandler: Starting syncSnagData for snag $snagId');
      }

      // Step 1: Get snag from local DB
      final snag = await database.snagDao.getSnagById(snagId);
      if (snag == null) {
        if (kDebugMode) {
          print('SnagSyncHandler: Snag $snagId not found in local DB');
        }
        return false;
      }

      // Step 2: Check if sync is needed
      if (!snag.needsSnagSync) {
        if (kDebugMode) {
          print('SnagSyncHandler: Snag sync not needed (needsSnagSync=false)');
        }
        return true;
      }

      // Step 3: Get parent site to obtain ownerUID
      final site = await database.siteDao.getSiteById(snag.siteUID);
      if (site == null) {
        if (kDebugMode) {
          print('SnagSyncHandler: Parent site ${snag.siteUID} not found');
        }
        return false;
      }

      // Step 4: Validate snag data
      if (!_validateSnagData(snag)) {
        if (kDebugMode) {
          print('SnagSyncHandler: Snag data validation failed');
          print('  - title: ${snag.title}');
          print('  - siteUID: ${snag.siteUID}');
          print('  - ownerEmail: ${snag.ownerEmail}');
        }
        return false;
      }

      if (kDebugMode) {
        print('SnagSyncHandler: Validated, uploading to Firestore...');
      }

      // Step 5: Upload to Firestore with retry (3 attempts, exponential backoff)
      int attempts = 0;
      while (attempts < 3) {
        try {
          if (kDebugMode) {
            print('SnagSyncHandler: Upload attempt ${attempts + 1} of 3');
          }

          await _uploadSnagToFirestore(snag, site.ownerUID);

          if (kDebugMode) {
            print('SnagSyncHandler: Uploaded to Firestore successfully');
          }

          // Step 6: Clear needsSnagSync flag
          await database.snagDao.clearSnagSyncFlag(snagId);

          if (kDebugMode) {
            print('SnagSyncHandler: Cleared needsSnagSync flag');
          }

          return true;
        } catch (e) {
          attempts++;
          if (kDebugMode) {
            print('SnagSyncHandler: Upload attempt $attempts failed: $e');
          }
          if (attempts >= 3) {
            rethrow;
          }
          // Exponential backoff: 1s, 2s, 3s
          await Future.delayed(Duration(seconds: attempts));
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('SnagSyncHandler: Error during syncSnagData: $e');
      }
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('SnagSyncHandler: Firebase permission denied');
        }
      }
      return false;
    }
  }

  /// Upload snag data to Firestore
  Future<void> _uploadSnagToFirestore(Snag snag, String ownerUID) async {
    // Path: Profile/{ownerUID}/Sites/{siteId}/Snags/{snagId}
    // SYNC: Must match firestore.rules path structure
    final path = 'Profile/$ownerUID/Sites/${snag.siteUID}/Snags/${snag.id}';
    if (kDebugMode) {
      print('SnagSyncHandler: Writing to path: $path');
    }

    final docRef = firestore
        .collection('Profile')
        .doc(ownerUID)
        .collection('Sites')
        .doc(snag.siteUID)
        .collection('Snags')
        .doc(snag.id);

    // Use the snag's built-in toFirestore() method
    await docRef.set(snag.toFirestore());

    // Wait for pending writes to ensure server sync (not just local cache)
    await firestore.waitForPendingWrites();

    // Verify write reached server by reading back with server source
    final serverDoc = await docRef.get(const GetOptions(source: Source.server));
    if (!serverDoc.exists) {
      throw Exception('Server verification failed: document not found after write');
    }
    if (kDebugMode) {
      print('SnagSyncHandler: Server verification passed - document exists');
    }
  }

  /// Validate snag data before sync
  /// SYNC: Must match isValidSnagData() in firestore.rules
  bool _validateSnagData(Snag snag) {
    // Title must be empty (field is unused)
    if (snag.title.isNotEmpty) {
      return false;
    }
    // Check required fields
    if (snag.siteUID.isEmpty || snag.siteUID.length > 50) {
      return false;
    }
    if (snag.ownerEmail.isEmpty || snag.ownerEmail.length > 254) {
      return false;
    }
    if (snag.creatorEmail.isEmpty || snag.creatorEmail.length > 254) {
      return false;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(snag.ownerEmail)) {
      return false;
    }
    if (!emailRegex.hasMatch(snag.creatorEmail)) {
      return false;
    }

    return true;
  }

  /// Sync all problem images for a snag (6 slots)
  /// Returns true if all slots synced successfully
  Future<bool> syncSnagImages(String snagId) async {
    return _syncSlots(snagId: snagId, isFix: false);
  }

  /// Sync all fix images for a snag (6 slots)
  /// Returns true if all slots synced successfully
  Future<bool> syncSnagFixImages(String snagId) async {
    return _syncSlots(snagId: snagId, isFix: true);
  }

  // ============== Core Sync Logic ==============

  /// Sync slots for either problem or fix images
  Future<bool> _syncSlots({
    required String snagId,
    required bool isFix,
  }) async {
    try {
      // 1. Get snag from DB
      final snag = await database.snagDao.getSnagById(snagId);
      if (snag == null) {
        if (kDebugMode) print('SnagSyncHandler: Snag $snagId not found');
        return false;
      }

      final slots = isFix ? snag.fixImages : snag.images;
      final label = isFix ? 'fix' : 'problem';

      // Check if any slot needs sync
      if (!slots.any((s) => s.needsAttention)) {
        if (kDebugMode) print('SnagSyncHandler: No $label slots need sync');
        return true;
      }

      if (kDebugMode) {
        print('SnagSyncHandler: Syncing $label images for snag $snagId');
      }

      // 2. Track original versions for race condition detection
      final originalVersions = slots.map((s) => s.version).toList();
      final syncedSlots = List<ImageSlot>.from(slots);
      bool anyChanges = false;

      // 3. Sync each slot that needs attention
      for (int i = 0; i < 6; i++) {
        final slot = slots[i];
        if (!slot.needsAttention) continue;

        final success = await _syncSingleSlot(
          slot: slot,
          index: i,
        );

        if (success) {
          syncedSlots[i] = slot.markSynced();
          anyChanges = true;
        }
        // On failure, slot keeps its flags for retry next cycle
      }

      // 4. Race condition check: re-fetch and compare versions
      if (anyChanges) {
        final currentSnag = await database.snagDao.getSnagById(snagId);
        if (currentSnag == null) return true; // Snag deleted, nothing to update

        final currentSlots = isFix ? currentSnag.fixImages : currentSnag.images;
        final mergedSlots = List<ImageSlot>.from(currentSlots);

        for (int i = 0; i < 6; i++) {
          // Only apply our update if version unchanged (no user activity during sync)
          if (currentSlots[i].version == originalVersions[i]) {
            mergedSlots[i] = syncedSlots[i];
          }
          // Else: user changed slot during sync, keep their version
        }

        // 5. Save merged slots to DB
        if (isFix) {
          await database.snagDao.updateSnagFixImages(snagId, mergedSlots);
        } else {
          await database.snagDao.updateSnagImages(snagId, mergedSlots);
        }

        if (kDebugMode) {
          print('SnagSyncHandler: Saved merged $label slots for snag $snagId');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('SnagSyncHandler: Error syncing slots: $e');
      return false;
    }
  }

  /// Sync a single slot (upload or delete)
  Future<bool> _syncSingleSlot({
    required ImageSlot slot,
    required int index,
  }) async {
    try {
      final firebasePath = slot.firebasePath;

      // Scenario 1: Delete (no local image, marked for deletion)
      if (!slot.hasImage && slot.markedForDeletion) {
        if (firebasePath != null) {
          await _deleteFromStorage(firebasePath);
        }
        if (kDebugMode) print('SnagSyncHandler: Deleted slot $index');
        return true;
      }

      // Scenario 2: Upload (has local image, needs sync)
      if (slot.hasImage && slot.needsSync) {
        if (firebasePath == null) {
          if (kDebugMode) print('SnagSyncHandler: Missing firebasePath for slot $index');
          return false;
        }
        await _uploadToStorage(
          localPath: slot.localPath!,
          firebasePath: firebasePath,
        );
        if (kDebugMode) print('SnagSyncHandler: Uploaded slot $index');
        return true;
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('SnagSyncHandler: Error syncing slot $index: $e');
      return false;
    }
  }

  // ============== Firebase Storage Operations ==============

  Future<void> _uploadToStorage({
    required String localPath,
    required String firebasePath,
  }) async {
    if (kDebugMode) {
      print('SnagSyncHandler: Uploading to Storage path: $firebasePath');
    }

    final absolutePath = await snagImageService.getAbsolutePath(localPath);
    final file = File(absolutePath);

    if (!await file.exists()) {
      throw Exception('Local file not found: $absolutePath');
    }

    final bytes = await file.readAsBytes();
    final storageRef = storage.ref(firebasePath);
    final uploadTask = await storageRef.putData(bytes);

    // Verify upload succeeded
    if (uploadTask.state != TaskState.success) {
      throw Exception('Storage upload failed with state: ${uploadTask.state}');
    }

    // Double-check by getting download URL (confirms file exists on server)
    final downloadUrl = await storageRef.getDownloadURL();
    if (kDebugMode) {
      print('SnagSyncHandler: Storage upload verified - URL: $downloadUrl');
    }
  }

  Future<void> _deleteFromStorage(String firebasePath) async {
    try {
      final storageRef = storage.ref(firebasePath);
      await storageRef.delete();
    } catch (e) {
      // Ignore "not found" errors - file may already be deleted
      if (e is FirebaseException && e.code == 'object-not-found') {
        if (kDebugMode) print('SnagSyncHandler: File already deleted: $firebasePath');
        return;
      }
      rethrow;
    }
  }
}
