import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/services/image_storage_service.dart';

/// Handles synchronization of Site data between local database and Firebase.
///
/// Follows the same pattern as ProfileSyncHandler:
/// - Local database is source of truth
/// - Sync flags track what needs uploading
/// - Background sync uploads to Firebase when online
///
/// Firebase paths (Profile-centric structure):
/// - Site data: Profile/{ownerUID}/Sites/{siteID} (Firestore)
/// - Site image: Profile/{ownerUID}/Sites/{siteID}/site.jpg (Storage)
///
/// SYNC: Paths must match firestore.rules and storage.rules
class SiteSyncHandler {
  final AppDatabase database;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImageStorageService imageStorage;

  SiteSyncHandler({
    required this.database,
    required this.firestore,
    required this.storage,
    required this.imageStorage,
  }) {
    if (kDebugMode) {
      print('SiteSyncHandler: Initialized with all dependencies');
    }
  }

  // ============== Feature 1.2: syncSiteData() ==============

  /// Syncs site metadata to Firestore
  ///
  /// Steps:
  /// 1. Get site from local DB by ID
  /// 2. Check needsSiteSync flag
  /// 3. Validate site data
  /// 4. Upload to Firestore Profile/{ownerUID}/Sites/{siteID}
  /// 5. Clear needsSiteSync flag on success
  ///
  /// Returns true if sync succeeded or was not needed
  Future<bool> syncSiteData(String siteId) async {
    try {
      if (kDebugMode) {
        print('SiteSyncHandler: Starting syncSiteData for site $siteId');
      }

      // Step 1: Get site from local DB
      final site = await database.siteDao.getSiteById(siteId);
      if (site == null) {
        if (kDebugMode) {
          print('SiteSyncHandler: Site $siteId not found in local DB');
        }
        return false;
      }

      // Step 2: Check if sync is needed
      if (!site.needsSiteSync) {
        if (kDebugMode) {
          print('SiteSyncHandler: Site sync not needed (needsSiteSync=false)');
        }
        return true;
      }

      // Step 3: Validate site data
      if (!_validateSiteData(site)) {
        if (kDebugMode) {
          print('SiteSyncHandler: Site data validation failed');
          print('  - name: ${site.name}');
          print('  - ownerUID: ${site.ownerUID}');
          print('  - ownerEmail: ${site.ownerEmail}');
        }
        return false;
      }

      if (kDebugMode) {
        print('SiteSyncHandler: Site data validated');
      }

      // Step 4: Upload to Firestore with retry
      int attempts = 0;
      while (attempts < 3) {
        try {
          if (kDebugMode) {
            print('SiteSyncHandler: Upload attempt ${attempts + 1} of 3');
          }

          await _uploadSiteToFirestore(site);

          if (kDebugMode) {
            print('SiteSyncHandler: Uploaded to Firestore successfully');
          }

          // Step 5: Clear needsSiteSync flag
          await _clearSiteSyncFlag(siteId);

          if (kDebugMode) {
            print('SiteSyncHandler: Cleared needsSiteSync flag');
          }

          return true;
        } catch (e) {
          attempts++;
          if (kDebugMode) {
            print('SiteSyncHandler: Upload attempt $attempts failed: $e');
          }
          if (attempts >= 3) {
            rethrow;
          }
          await Future.delayed(Duration(seconds: attempts));
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('SiteSyncHandler: Error during syncSiteData: $e');
      }
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('SiteSyncHandler: Firebase permission denied');
        }
      }
      return false;
    }
  }

  /// Upload site data to Firestore
  Future<void> _uploadSiteToFirestore(Site site) async {
    // Path: Profile/{ownerUID}/Sites/{siteID}
    final docRef = firestore
        .collection('Profile')
        .doc(site.ownerUID)
        .collection('Sites')
        .doc(site.id);

    // Use the site's built-in toFirestore() method
    await docRef.set(site.toFirestore());
  }

  /// Validate site data before sync
  bool _validateSiteData(Site site) {
    // Check required fields
    if (site.name.isEmpty) {
      return false;
    }
    if (site.ownerUID.isEmpty) {
      return false;
    }
    if (site.ownerEmail.isEmpty) {
      return false;
    }

    // Validate email format - tightened regex synced with validators.dart
    final emailRegex = RegExp(r'^(?!.*\.\.)(?!.*\.@)(?!.*@\.)(?!.*@-)(?!.*-\.)(?!.*\.-)[a-zA-Z0-9][a-zA-Z0-9._%+-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(site.ownerEmail)) {
      return false;
    }

    return true;
  }

  /// Clear only the site sync flag
  Future<void> _clearSiteSyncFlag(String siteId) async {
    await database.siteDao.clearSiteSyncFlag(siteId);
  }

  // ============== Feature 1.3: syncSiteImage() ==============

  /// Syncs site image to Firebase Storage
  ///
  /// Handles three scenarios:
  /// 1. Upload new image
  /// 2. Delete existing image
  /// 3. Replace (delete old, upload new)
  ///
  /// Returns true if sync succeeded or was not needed
  Future<bool> syncSiteImage(String siteId) async {
    try {
      if (kDebugMode) {
        print('SiteSyncHandler: Starting syncSiteImage for site $siteId');
      }

      // Get site from local DB
      final site = await database.siteDao.getSiteById(siteId);
      if (site == null) {
        if (kDebugMode) {
          print('SiteSyncHandler: Site $siteId not found in local DB');
        }
        return false;
      }

      // Check if sync is needed
      if (!site.needsImageSync) {
        if (kDebugMode) {
          print('SiteSyncHandler: Image sync not needed (needsImageSync=false)');
        }
        return true;
      }

      final imagePath = site.imageLocalPath ?? '';

      if (kDebugMode) {
        print('SiteSyncHandler: Current state:');
        print('  - imageLocalPath: "$imagePath"');
        print('  - imageFirebasePath: ${site.imageFirebasePath}');
        print('  - imageMarkedForDeletion: ${site.imageMarkedForDeletion}');
      }

      // Scenario 3: Replace (delete old, then upload new)
      if (site.imageMarkedForDeletion && imagePath.isNotEmpty) {
        if (kDebugMode) {
          print('SiteSyncHandler: Image scenario - replace');
        }

        // Delete old from Firebase if exists
        if (site.imageFirebasePath != null && site.imageFirebasePath!.isNotEmpty) {
          await _deleteImageFromStorage(site.imageFirebasePath!);
        }

        // Clear deletion flag
        await database.siteDao.clearImageDeletionFlag(siteId);

        // Continue to upload new image below
      }

      // Scenario 2: Delete only (no new image)
      if (imagePath.isEmpty && site.imageFirebasePath != null && site.imageFirebasePath!.isNotEmpty) {
        if (kDebugMode) {
          print('SiteSyncHandler: Image scenario - delete');
        }

        await _deleteImageFromStorage(site.imageFirebasePath!);
        await database.siteDao.updateImageFirebasePath(siteId, null);
        await database.siteDao.clearImageSyncFlag(siteId);
        await database.siteDao.clearImageDeletionFlag(siteId);

        if (kDebugMode) {
          print('SiteSyncHandler: Image deleted successfully');
        }
        return true;
      }

      // Scenario 1: Upload new image
      if (imagePath.isNotEmpty) {
        if (kDebugMode) {
          print('SiteSyncHandler: Image scenario - upload');
        }

        // Check if local file exists
        final imageFile = await imageStorage.getImageFile(imagePath);
        if (!imageFile.existsSync()) {
          if (kDebugMode) {
            print('SiteSyncHandler: Local image file not found: $imagePath');
          }
          // Clear invalid path
          await database.siteDao.updateImageLocalPath(siteId, null);
          await database.siteDao.clearImageSyncFlag(siteId);
          return true;
        }

        // Upload to Firebase Storage
        // SYNC: Path must match storage.rules
        final storagePath = 'Profile/${site.ownerUID}/Sites/$siteId/site.jpg';
        final imageBytes = imageFile.readAsBytesSync();

        final storageRef = storage.ref(storagePath);
        await storageRef.putData(imageBytes);

        if (kDebugMode) {
          print('SiteSyncHandler: Uploaded to Storage: $storagePath');
        }

        // Update Firebase path in local DB
        await database.siteDao.updateImageFirebasePath(siteId, storagePath);
        await database.siteDao.clearImageSyncFlag(siteId);

        if (kDebugMode) {
          print('SiteSyncHandler: Updated imageFirebasePath in local DB');
        }

        return true;
      }

      // No image to sync (empty path, no firebase path)
      await database.siteDao.clearImageSyncFlag(siteId);
      return true;

    } catch (e) {
      if (kDebugMode) {
        print('SiteSyncHandler: Error during syncSiteImage: $e');
      }
      return false;
    }
  }

  /// Delete image from Firebase Storage
  Future<void> _deleteImageFromStorage(String storagePath) async {
    try {
      final storageRef = storage.ref(storagePath);
      await storageRef.delete();
      if (kDebugMode) {
        print('SiteSyncHandler: Deleted from Storage: $storagePath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SiteSyncHandler: Error deleting from Storage: $e');
      }
      // Continue even if deletion fails (file might not exist)
    }
  }

  // ============== Feature 1.36: Download Methods ==============

  /// Download site image from Firebase Storage
  /// Saves to local storage and returns relative path
  Future<String?> downloadSiteImage(String siteId, String firebasePath, String ownerUID) async {
    try {
      if (kDebugMode) {
        print('SiteSyncHandler: Downloading image from $firebasePath');
      }

      // Download bytes from Firebase Storage
      final storageRef = storage.ref(firebasePath);
      final Uint8List? imageData = await storageRef.getData();

      if (imageData == null) {
        if (kDebugMode) {
          print('SiteSyncHandler: No image data received');
        }
        return null;
      }

      // Save to local storage (returns relative path)
      final relativePath = await imageStorage.saveSiteImageFromBytes(
        imageData,
        ownerUID,
        siteId,
      );

      if (kDebugMode) {
        print('SiteSyncHandler: Image saved to $relativePath');
      }

      // Update local DB with relative path
      await database.siteDao.updateImageLocalPath(siteId, relativePath);

      return relativePath;
    } catch (e) {
      if (kDebugMode) {
        print('SiteSyncHandler: Error downloading site image: $e');
      }
      return null;
    }
  }

  /// Download all owned sites from Firebase to local DB
  /// Called after profile download on sign-in
  Future<int> downloadAllOwnedSites(String userUID) async {
    try {
      if (kDebugMode) {
        print('SiteSyncHandler: Downloading all owned sites for user $userUID');
      }

      // Query Firestore for all sites owned by this user
      final snapshot = await firestore
          .collection('Profile')
          .doc(userUID)
          .collection('Sites')
          .get();

      if (kDebugMode) {
        print('SiteSyncHandler: Found ${snapshot.docs.length} sites in Firebase');
      }

      int downloadedCount = 0;

      for (final doc in snapshot.docs) {
        try {
          // Create Site from Firestore data
          final site = Site.fromFirestore(doc.id, doc.data());

          if (kDebugMode) {
            print('SiteSyncHandler: Downloading site ${site.id} - ${site.name}');
          }

          // Upsert to local DB
          await database.siteDao.upsertSite(site);

          // Download image if exists
          if (site.imageFirebasePath != null && site.imageFirebasePath!.isNotEmpty) {
            await downloadSiteImage(site.id, site.imageFirebasePath!, userUID);
          }

          downloadedCount++;
        } catch (e) {
          if (kDebugMode) {
            print('SiteSyncHandler: Error downloading site ${doc.id}: $e');
          }
          // Continue with next site
        }
      }

      if (kDebugMode) {
        print('SiteSyncHandler: Downloaded $downloadedCount/${snapshot.docs.length} sites');
      }

      return downloadedCount;
    } catch (e) {
      if (kDebugMode) {
        print('SiteSyncHandler: Error downloading owned sites: $e');
      }
      return 0;
    }
  }

  // ============== Feature 1.4: downloadSite() ==============
  // TODO: Implement - download single site from Firestore

  // ============== Feature 1.5: downloadSiteImage() ==============
  // Implemented above as part of Feature 1.36

  // ============== Feature 1.6: syncAll() ==============
  // TODO: Implement - batch sync all sites needing sync
}
