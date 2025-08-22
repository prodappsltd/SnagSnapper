import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/colleague.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/services/sync/conflict_resolver.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum SyncFlag {
  profile,
  image,
  signature,
}

class ProfileSyncHandler {
  final AppDatabase database;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImageStorageService imageStorage;
  final ConflictResolver _conflictResolver = ConflictResolver();

  ProfileSyncHandler({
    required this.database,
    required this.firestore,
    required this.storage,
    required this.imageStorage,
  });

  Future<bool> syncProfileData(String userId) async {
    try {
      // Debug: Log sync attempt
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileData: Starting sync for user $userId');
      }
      
      final localUser = await database.profileDao.getProfile(userId);
      if (localUser == null) {
        // No local profile exists - try to download from Firebase
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileData: No local profile found, attempting to download from Firebase...');
        }
        final firebaseProfile = await _downloadProfile(userId);
        
        if (firebaseProfile != null) {
          // Save the downloaded profile to local database
          await database.profileDao.insertProfile(firebaseProfile);
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileData: Profile downloaded and saved successfully');
          }
          
          // Download image if Firebase has one
          if (firebaseProfile.imageFirebasePath != null) {
            if (kDebugMode) {
              print('ProfileSyncHandler: Downloading profile image from Firebase Storage...');
            }
            await downloadProfileImage(userId, firebaseProfile.imageFirebasePath!);
          }
          
          // Download signature if Firebase has one
          if (firebaseProfile.signatureFirebasePath != null) {
            if (kDebugMode) {
              print('ProfileSyncHandler: Downloading signature from Firebase Storage...');
            }
            await downloadSignatureImage(userId, firebaseProfile.signatureFirebasePath!);
          }
          
          return true;
        }
        
        // No profile in Firebase either
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileData: No profile found in Firebase either');
        }
        return false;
      }

      // Check if sync is needed
      if (!localUser.needsProfileSync) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileData: Profile sync not needed (needsProfileSync=false)');
        }
        return true;
      }

      // Debug: Log that sync is needed
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileData: Profile needs sync (needsProfileSync=true)');
      }

      // Validate data before sync
      if (!_validateUserData(localUser)) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileData: User data validation failed');
          print('  - Email: ${localUser.email}');
          print('  - Name: ${localUser.name}');
          print('  - Company: ${localUser.companyName}');
        }
        return false;
      }

      // Debug: Log validation success
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileData: User data validated successfully');
      }

      // Try to upload with retry
      int attempts = 0;
      while (attempts < 3) {
        try {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileData: Upload attempt ${attempts + 1} of 3');
          }
          
          await _uploadProfile(localUser);
          
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileData: Upload successful, clearing sync flag');
          }
          
          // ONLY update sync-related fields - don't touch the actual data!
          await database.profileDao.clearProfileSyncFlag(userId);
          
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileData: Profile sync completed successfully');
          }
          
          return true;
        } catch (e) {
          attempts++;
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileData: Upload attempt $attempts failed: $e');
          }
          if (attempts >= 3) {
            throw e;
          }
          await Future.delayed(Duration(seconds: attempts));
        }
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileData: Error during sync: $e');
      }
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileData: Firebase permission denied');
        }
        return false;
      }
      return false;
    }
  }

  Future<void> _uploadProfile(AppUser user) async {
    final docRef = firestore.collection('Profile').doc(user.id);
    
    // Convert colleagues list to Firestore-compatible format
    List<Map<String, dynamic>>? colleaguesData;
    if (user.listOfALLColleagues != null) {
      colleaguesData = user.listOfALLColleagues!
          .map((colleague) => colleague.toJson())
          .toList();
    }
    
    // Debug logging to see what's being uploaded
    if (kDebugMode) {
      print('🔍 ProfileSyncHandler._uploadProfile: Uploading profile data:');
      print('  - userId: ${user.id}');
      print('  - imagePath: ${user.imageFirebasePath}');
      print('  - signaturePath: ${user.signatureFirebasePath}');
      print('  - colleagues count: ${colleaguesData?.length ?? 0}');
    }
    
    await docRef.set({
      'name': user.name,
      'email': user.email,
      'companyName': user.companyName,
      'phone': user.phone,
      'jobTitle': user.jobTitle,
      'postcodeOrArea': user.postcodeOrArea,
      'dateFormat': user.dateFormat,
      'imagePath': user.imageFirebasePath,  // Store Firebase Storage path (not URL)
      'signaturePath': user.signatureFirebasePath,  // Store Firebase Storage path (not URL)
      'colleagues': colleaguesData,  // Store colleagues list
      'version': user.localVersion ?? 1,
      'updatedAt': Timestamp.now(),
      'createdAt': Timestamp.fromDate(user.createdAt),
    });
  }

  Future<AppUser?> _downloadProfile(String userId) async {
    try {
      // Fetch from the 'Profile' collection
      final profileDoc = await firestore.collection('Profile').doc(userId).get();
      
      if (profileDoc.exists) {
        final data = profileDoc.data()!;
        print('Found profile in Profile collection');
        return _createAppUserFromFirestore(userId, data);
      }
      
      print('No profile found in Firebase for user $userId');
      return null;
    } catch (e) {
      print('Error downloading profile: $e');
      return null;
    }
  }
  
  AppUser _createAppUserFromFirestore(String userId, Map<String, dynamic> data) {
    final now = DateTime.now();
    
    // Parse colleagues list from Firestore
    List<Colleague>? colleagues;
    if (data['colleagues'] != null) {
      colleagues = (data['colleagues'] as List<dynamic>)
          .map((colleagueData) => Colleague.fromJson(colleagueData as Map<String, dynamic>))
          .toList();
    }
    
    return AppUser(
      id: userId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      companyName: data['companyName'] ?? '',
      postcodeOrArea: data['postcodeOrArea'],
      dateFormat: data['dateFormat'] ?? 'dd-MM-yyyy',
      imageLocalPath: null, // Will be downloaded separately
      imageFirebasePath: data['imagePath'],
      signatureLocalPath: null, // Will be downloaded separately
      signatureFirebasePath: data['signaturePath'],
      listOfALLColleagues: colleagues,  // Restore colleagues list
      needsProfileSync: false, // Just downloaded, no need to sync back
      needsImageSync: false, // Will be downloaded separately, not uploaded
      needsSignatureSync: false, // Will be downloaded separately, not uploaded
      lastSyncTime: now,
      currentDeviceId: null, // Will be set on login
      lastLoginTime: now,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? now,
      localVersion: data['version'] ?? 1,
      firebaseVersion: data['version'] ?? 1,
    );
  }

  Future<AppUser?> downloadProfile(String userId) async {
    try {
      final docSnapshot = await firestore
          .collection('Profile')
          .doc(userId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data()!;
      
      // Parse colleagues list from Firebase
      List<Colleague>? colleagues;
      if (data['colleagues'] != null) {
        colleagues = (data['colleagues'] as List<dynamic>)
            .map((colleagueData) => Colleague.fromJson(colleagueData as Map<String, dynamic>))
            .toList();
      }
      
      // Map Firebase data to AppUser
      return AppUser(
        id: userId,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        companyName: data['companyName'] ?? '',
        phone: data['phone'],
        jobTitle: data['jobTitle'],
        postcodeOrArea: data['postcodeOrArea'],
        dateFormat: data['dateFormat'] ?? 'dd-MM-yyyy',
        imageFirebasePath: data['imagePath'],  // Use correct field name
        signatureFirebasePath: data['signaturePath'],  // Use correct field name
        listOfALLColleagues: colleagues,  // Include colleagues!
        firebaseVersion: data['version'] ?? 1,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSyncHandler.downloadProfile: Error downloading profile: $e');
      }
      return null;
    }
  }

  Future<bool> syncProfileImage(String userId, String imagePath) async {
    try {
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileImage: Starting image sync for user $userId, path: "$imagePath"');
      }
      
      final localUser = await database.profileDao.getProfile(userId);
      if (localUser == null || !localUser.needsImageSync) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Image sync not needed (user null: ${localUser == null}, needsImageSync: ${localUser?.needsImageSync ?? false})');
        }
        return true;
      }

      // Log current state for debugging
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileImage: Current state:');
        print('  - Local path: "$imagePath" (empty: ${imagePath.isEmpty})');
        print('  - Firebase Path: ${localUser.imageFirebasePath}');
        print('  - imageMarkedForDeletion: ${localUser.imageMarkedForDeletion}');
        print('  - needsImageSync: ${localUser.needsImageSync}');
      }
      
      // CRITICAL: Check if this is a delete-then-add scenario
      // If imageMarkedForDeletion is true AND we have a local path,
      // we must delete from Firebase first, then upload the new image
      if (localUser.imageMarkedForDeletion && imagePath.isNotEmpty) {
        if (kDebugMode) {
          print('🔍 ProfileSyncHandler.syncProfileImage: Delete-then-add scenario detected');
          print('  - imageMarkedForDeletion: ${localUser.imageMarkedForDeletion}');
          print('  - imageLocalPath: "$imagePath" (not empty)');
          print('  - imageFirebasePath: ${localUser.imageFirebasePath}');
          print('  - ACTION: Will delete old Firebase image first, then upload new one');
        }
        
        // Step 1: Delete from Firebase if exists
        if (localUser.imageFirebasePath != null && localUser.imageFirebasePath!.isNotEmpty) {
          try {
            final storageRef = storage.ref(localUser.imageFirebasePath!);
            await storageRef.delete();
            if (kDebugMode) {
              print('ProfileSyncHandler.syncProfileImage: Deleted old image from Firebase');
            }
          } catch (e) {
            if (kDebugMode) {
              print('ProfileSyncHandler.syncProfileImage: Could not delete old image: $e');
            }
            // Continue even if deletion fails
          }
        }
        
        // Step 2: Clear deletion flag now that we've handled it
        await database.profileDao.clearImageDeletionFlag(userId);
        
        // Step 3: Continue with upload (will happen below)
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Proceeding with new image upload');
        }
      }
      
      // Check if this is a deletion sync: localPath is null/empty but Firebase URL exists
      if (imagePath.isEmpty && localUser.imageFirebasePath != null && localUser.imageFirebasePath!.isNotEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Deletion sync - local path empty but Firebase URL exists');
        }
        
        // Delete from Firebase Storage
        try {
          // Use stored path since we verified it exists in the if condition above
          final storageRef = storage.ref(localUser.imageFirebasePath!);
          await storageRef.delete();
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Successfully deleted image from Firebase Storage');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Error deleting from Firebase Storage: $e');
          }
          // Continue even if deletion fails (image might not exist in Firebase)
        }
        
        // CRITICAL: Re-fetch the current state before updating to prevent race conditions
        // User might have added a new image while we were processing the deletion
        final currentUser = await database.profileDao.getProfile(userId);
        if (currentUser != null && currentUser.imageLocalPath != null && currentUser.imageLocalPath!.isNotEmpty) {
          if (kDebugMode) {
            print('🔴 ProfileSyncHandler.syncProfileImage: RACE CONDITION PREVENTED!');
            print('  - User added new image while deletion was processing');
            print('  - Current imageLocalPath: ${currentUser.imageLocalPath}');
            print('  - Skipping database update to preserve new image');
          }
          // Don't update the database with null - user has added a new image
          // But we need to clear the deletion flag if set, and keep needsImageSync true
          // because the new image still needs to be uploaded
          if (currentUser.imageMarkedForDeletion) {
            await database.profileDao.clearImageDeletionFlag(userId);
          }
          
          // IMPORTANT: The new image still needs to be synced to Firebase
          // Since we prevented deletion, we should now try to upload the new image
          if (kDebugMode) {
            print('  ⚠️ New image detected - switching from deletion to upload');
            print('  Recursively calling sync with new image path');
          }
          
          // Recursively call ourselves with the new image path to handle the upload
          // This ensures the new image gets uploaded in the same sync cycle
          return await syncProfileImage(userId, currentUser.imageLocalPath!);
        }
        
        // Safe to proceed with deletion - only update Firebase path and sync flag
        await database.profileDao.updateImageFirebasePath(userId, null);
        await database.profileDao.clearImageSyncFlag(userId);
        
        // Also clear the image URL in Firebase Firestore
        await firestore.collection('Profile').doc(userId).update({
          'imagePath': null,
          'updatedAt': Timestamp.now(),
        });
        
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Image deletion synced successfully');
          print('  - Cleared Firebase URL in both local DB and Firestore');
        }
        
        return true;
      }
      
      // If path is empty but no Firebase URL, check if file exists in Storage anyway
      if (imagePath.isEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: No local image, checking for orphaned Firebase Storage file');
        }
        
        // Try to delete from Firebase Storage in case file exists there
        try {
          final storageRef = storage.ref('users/$userId/profile.jpg');
          await storageRef.delete();
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Deleted orphaned image from Firebase Storage');
          }
        } catch (e) {
          // File doesn't exist or error deleting - that's fine
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: No orphaned file to delete or error: $e');
          }
        }
        
        // Clear any URLs in Firestore
        try {
          await firestore.collection('Profile').doc(userId).update({
            'imagePath': null,
            'updatedAt': Timestamp.now(),
          });
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Cleared imagePath in Firestore');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Error updating Firestore: $e');
          }
        }
        
        // CRITICAL: Re-check current state before updating to prevent race conditions
        final currentUser = await database.profileDao.getProfile(userId);
        if (currentUser != null && currentUser.imageLocalPath != null && currentUser.imageLocalPath!.isNotEmpty) {
          if (kDebugMode) {
            print('🔴 ProfileSyncHandler.syncProfileImage: RACE CONDITION PREVENTED (orphan cleanup)!');
            print('  - User added new image while we were cleaning up orphaned files');
            print('  - Current imageLocalPath: ${currentUser.imageLocalPath}');
            print('  - Switching to upload the new image');
          }
          
          // Recursively call ourselves with the new image path to handle the upload
          return await syncProfileImage(userId, currentUser.imageLocalPath!);
        }
        
        // Clear ONLY the sync flag
        await database.profileDao.clearImageSyncFlag(userId);
        
        return true;
      }
      
      // Check if local file exists for upload
      final imageFile = await imageStorage.getImageFile(imagePath);
      if (!imageFile.existsSync()) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Local file does not exist at path: $imagePath');
        }
        // File doesn't exist - clear the local path and sync flag
        // This is an exception where we need to update the data (clear invalid path)
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            imageLocalPath: null,
            needsImageSync: false,
          ),
        );
        return true;
      }

      // Read and potentially compress image in isolate
      Uint8List imageBytes = imageFile.readAsBytesSync();
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileImage: Image size: ${imageBytes.length} bytes');
      }
      
      if (imageBytes.length > 1000000) { // > 1MB
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Compressing image (> 1MB)...');
        }
        final compressionService = ImageCompressionService.instance;
        imageBytes = await compressionService.compressImageBytes(
          imageBytes,
          maxWidth: 1024,
          maxHeight: 1024,
          quality: 90,  // Updated per PRD
        );
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Compressed size: ${imageBytes.length} bytes');
        }
      }

      // Upload with retry
      int attempts = 0;
      while (attempts < 2) {
        try {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Upload attempt ${attempts + 1} of 2');
          }
          
          final storageRef = storage.ref('users/$userId/profile.jpg');
          
          SettableMetadata? metadata;
          if (imageBytes.length > 5000000) { // > 5MB
            metadata = SettableMetadata(
              customMetadata: {'resumable': 'true'},
            );
          }
          
          final uploadTask = metadata != null 
              ? storageRef.putData(imageBytes, metadata)
              : storageRef.putData(imageBytes);
          
          final snapshot = await uploadTask;
          // We don't need the download URL - only store the path
          final storagePath = 'users/$userId/profile.jpg';
          
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Upload successful, path: $storagePath');
          }

          // Update ONLY the Firebase path and sync flag
          await database.profileDao.updateImageFirebasePath(userId, storagePath);
          await database.profileDao.clearImageSyncFlag(userId);
          
          // Also update Firebase Firestore with the storage path (NOT URL)
          await firestore.collection('Profile').doc(userId).update({
            'imagePath': storagePath,
            'updatedAt': Timestamp.now(),
          });
          
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Image sync completed successfully');
            print('  - Updated Firestore with image URL');
          }

          return true;
        } catch (e) {
          attempts++;
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Upload attempt $attempts failed: $e');
          }
          if (attempts >= 2) {
            return false;
          }
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSyncHandler.syncProfileImage: Error during image sync: $e');
      }
      return false;
    }
  }

  Future<bool> syncSignatureImage(String userId, String signaturePath) async {
    try {
      if (kDebugMode) {
        print('ProfileSyncHandler.syncSignatureImage: Starting signature sync for user $userId, path: "$signaturePath"');
      }
      
      final localUser = await database.profileDao.getProfile(userId);
      if (localUser == null || !localUser.needsSignatureSync) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Signature sync not needed');
        }
        return true;
      }

      // CRITICAL: Check if this is a delete-then-add scenario for signature
      if (localUser.signatureMarkedForDeletion && signaturePath.isNotEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Delete-then-add scenario detected');
        }
        
        // Delete from Firebase if exists
        if (localUser.signatureFirebasePath != null && localUser.signatureFirebasePath!.isNotEmpty) {
          try {
            final storageRef = storage.ref(localUser.signatureFirebasePath!);
            await storageRef.delete();
            if (kDebugMode) {
              print('ProfileSyncHandler.syncSignatureImage: Deleted old signature from Firebase');
            }
          } catch (e) {
            if (kDebugMode) {
              print('ProfileSyncHandler.syncSignatureImage: Could not delete old signature: $e');
            }
          }
        }
        
        // Clear deletion flag
        await database.profileDao.clearSignatureDeletionFlag(userId);
      }

      // Check if this is a deletion sync: localPath is null/empty but Firebase URL exists
      if (signaturePath.isEmpty && localUser.signatureFirebasePath != null && localUser.signatureFirebasePath!.isNotEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Deletion sync - local path empty but Firebase URL exists');
          print('  - Firebase Path: ${localUser.signatureFirebasePath}');
        }
        
        // Delete from Firebase Storage
        try {
          // Use stored path since we verified it exists in the if condition above
          final storageRef = storage.ref(localUser.signatureFirebasePath!);
          await storageRef.delete();
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Successfully deleted signature from Firebase Storage');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Error deleting from Firebase Storage: $e');
          }
          // Continue even if deletion fails (signature might not exist in Firebase)
        }
        
        // CRITICAL: Re-fetch the current state before updating to prevent race conditions
        // User might have added a new signature while we were processing the deletion
        final currentUser = await database.profileDao.getProfile(userId);
        if (currentUser != null && currentUser.signatureLocalPath != null && currentUser.signatureLocalPath!.isNotEmpty) {
          if (kDebugMode) {
            print('🔴 ProfileSyncHandler.syncSignatureImage: RACE CONDITION PREVENTED!');
            print('  - User added new signature while deletion was processing');
            print('  - Current signatureLocalPath: ${currentUser.signatureLocalPath}');
            print('  - Skipping database update to preserve new signature');
          }
          // Don't update the database - user has added a new signature
          // Just clear the deletion flag if it's still set
          if (currentUser.signatureMarkedForDeletion) {
            await database.profileDao.clearSignatureDeletionFlag(userId);
          }
          
          // Recursively call ourselves with the new signature path to handle the upload
          if (kDebugMode) {
            print('  ⚠️ New signature detected - switching from deletion to upload');
          }
          return await syncSignatureImage(userId, currentUser.signatureLocalPath!);
        }
        
        // Safe to proceed with deletion - only update Firebase path and sync flag
        await database.profileDao.updateSignatureFirebasePath(userId, null);
        await database.profileDao.clearSignatureSyncFlag(userId);
        
        // Also clear the signature URL in Firebase Firestore
        await firestore.collection('Profile').doc(userId).update({
          'signaturePath': null,
          'updatedAt': Timestamp.now(),
        });
        
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Signature deletion synced successfully');
          print('  - Cleared Firebase URL in both local DB and Firestore');
        }
        
        return true;
      }
      
      // If path is empty but no Firebase URL, check if file exists in Storage anyway
      if (signaturePath.isEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: No local signature, checking for orphaned Firebase Storage file');
        }
        
        // Try to delete from Firebase Storage in case file exists there
        try {
          final storageRef = storage.ref('users/$userId/signature.jpg');  // JPEG format per PRD
          await storageRef.delete();
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Deleted orphaned signature from Firebase Storage');
          }
        } catch (e) {
          // File doesn't exist or error deleting - that's fine
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: No orphaned file to delete or error: $e');
          }
        }
        
        // Clear any URLs in Firestore
        try {
          await firestore.collection('Profile').doc(userId).update({
            'signaturePath': null,
            'updatedAt': Timestamp.now(),
          });
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Cleared signaturePath in Firestore');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Error updating Firestore: $e');
          }
        }
        
        // Clear ONLY the sync flag
        await database.profileDao.clearSignatureSyncFlag(userId);
        
        return true;
      }
      
      // Check if local file exists for upload
      final signatureFile = await imageStorage.getImageFile(signaturePath);
      if (!signatureFile.existsSync()) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Local file does not exist at path: $signaturePath');
        }
        // File doesn't exist - clear the local path and sync flag
        // This is an exception where we need to update the data (clear invalid path)
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            signatureLocalPath: null,
            needsSignatureSync: false,
          ),
        );
        return true;
      }

      final imageBytes = signatureFile.readAsBytesSync();
      
      final storagePath = 'users/$userId/signature.jpg';  // JPEG format per PRD
      final storageRef = storage.ref(storagePath);
      final uploadTask = storageRef.putData(imageBytes);
      final snapshot = await uploadTask;
      // We don't need the download URL - only store the path

      // Update ONLY the Firebase path and sync flag
      await database.profileDao.updateSignatureFirebasePath(userId, storagePath);
      await database.profileDao.clearSignatureSyncFlag(userId);
      
      // Also update Firebase Firestore with the storage path (NOT URL)
      await firestore.collection('Profile').doc(userId).update({
        'signaturePath': storagePath,
        'updatedAt': Timestamp.now(),
      });
      
      if (kDebugMode) {
        print('ProfileSyncHandler.syncSignatureImage: Updated Firestore with signature URL');
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Resize if too large
    if (image.width > 1920 || image.height > 1920) {
      final resized = img.copyResize(
        image,
        width: image.width > image.height ? 1920 : null,
        height: image.height > image.width ? 1920 : null,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));  // Updated per PRD
    }

    // Just compress
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));  // Updated per PRD
  }

  bool _validateUserData(AppUser user) {
    // Check for invalid email
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(user.email)) {
      return false;
    }

    // Check required fields
    if (user.name.isEmpty || user.companyName.isEmpty) {
      return false;
    }

    return true;
  }

  Future<void> markForSync(String userId, List<SyncFlag> flags) async {
    for (final flag in flags) {
      switch (flag) {
        case SyncFlag.profile:
          await database.profileDao.setNeedsProfileSync(userId);
          break;
        case SyncFlag.image:
          await database.profileDao.setNeedsImageSync(userId);
          break;
        case SyncFlag.signature:
          await database.profileDao.setNeedsSignatureSync(userId);
          break;
      }
    }
  }

  Future<void> handleConflict(
    String userId,
    AppUser localUser,
    Map<String, dynamic> remoteData,
  ) async {
    final result = await _conflictResolver.resolveConflict(localUser, remoteData);
    
    if (result.shouldUpload) {
      await database.profileDao.setNeedsProfileSync(userId);
    } else {
      // Update local with resolved data
      await database.profileDao.updateProfile(userId, result.resolvedUser);
    }
  }

  Future<bool> downloadProfileImage(String userId, String firebasePath) async {
    try {
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadProfileImage: Downloading from $firebasePath');
      }
      
      // Get reference to Firebase Storage file
      final storageRef = storage.ref(firebasePath);
      
      // Download the image data
      final Uint8List? imageData = await storageRef.getData();
      if (imageData == null) {
        if (kDebugMode) {
          print('ProfileSyncHandler._downloadProfileImage: No data received');
        }
        return false;
      }
      
      // Save to local storage using ImageStorageService
      // First create a temporary file from the downloaded data
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_profile_$userId.jpg');
      await tempFile.writeAsBytes(imageData);
      
      // Now save using the image storage service
      final localPath = await imageStorage.saveProfileImage(
        tempFile,
        userId,
      );
      
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadProfileImage: Saved to local path: $localPath');
      }
      
      // Update ONLY the local path - don't touch other data
      await database.profileDao.updateImageLocalPath(userId, localPath);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadProfileImage: Error downloading image: $e');
      }
      return false;
    }
  }
  
  Future<bool> downloadSignatureImage(String userId, String firebasePath) async {
    try {
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadSignatureImage: Downloading from $firebasePath');
      }
      
      // Get reference to Firebase Storage file
      final storageRef = storage.ref(firebasePath);
      
      // Download the signature data
      final Uint8List? signatureData = await storageRef.getData();
      if (signatureData == null) {
        if (kDebugMode) {
          print('ProfileSyncHandler._downloadSignatureImage: No data received');
        }
        return false;
      }
      
      // Save to local storage - signatures are stored in a specific location
      final signatureService = SignatureService();
      final localPath = await signatureService.saveSignature(
        userId,
        signatureData,
      );
      
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadSignatureImage: Saved to local path: $localPath');
      }
      
      // Update ONLY the local path - don't touch other data
      await database.profileDao.updateSignatureLocalPath(userId, localPath);
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileSyncHandler._downloadSignatureImage: Error downloading signature: $e');
      }
      return false;
    }
  }

  Future<void> syncAll(String userId) async {
    var localUser = await database.profileDao.getProfile(userId);
    if (localUser == null) return;

    // ROBUST PRE-SYNC VALIDATION: Ensure Firebase paths are set before syncing
    bool pathsUpdated = false;
    
    // Check if we have a local image but no Firebase path (shouldn't happen with new code, but safety net)
    if (localUser.imageLocalPath != null && 
        localUser.imageLocalPath!.isNotEmpty && 
        localUser.imageFirebasePath == null) {
      if (kDebugMode) {
        print('🔧 ProfileSyncHandler: Pre-sync fix - Setting missing imageFirebasePath');
      }
      localUser = localUser.copyWith(
        imageFirebasePath: () => 'users/$userId/profile.jpg',
      );
      pathsUpdated = true;
    }
    
    // Check if we have a local signature but no Firebase path
    if (localUser.signatureLocalPath != null && 
        localUser.signatureLocalPath!.isNotEmpty && 
        localUser.signatureFirebasePath == null) {
      if (kDebugMode) {
        print('🔧 ProfileSyncHandler: Pre-sync fix - Setting missing signatureFirebasePath');
      }
      localUser = localUser.copyWith(
        signatureFirebasePath: () => 'users/$userId/signature.jpg',
      );
      pathsUpdated = true;
    }
    
    // Update local database with corrected paths if needed
    if (pathsUpdated) {
      await database.profileDao.updateProfile(userId, localUser);
      if (kDebugMode) {
        print('✅ ProfileSyncHandler: Pre-sync validation completed - paths corrected');
      }
    }

    // Now sync profile data FIRST (with paths already set)
    if (localUser.needsProfileSync) {
      await syncProfileData(userId);
    }

    // Then sync actual files
    if (localUser.needsImageSync && localUser.imageLocalPath != null) {
      await syncProfileImage(userId, localUser.imageLocalPath!);
    }

    if (localUser.needsSignatureSync && localUser.signatureLocalPath != null) {
      await syncSignatureImage(userId, localUser.signatureLocalPath!);
    }
  }

  Future<bool> syncBatch(List<SyncQueueItem> items) async {
    // For now, process individually
    // In production, would batch Firestore operations
    for (final item in items) {
      await syncProfileData(item.userId);
    }
    return true;
  }
}