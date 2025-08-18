import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/services/image_compression_service.dart';
import 'package:snagsnapper/services/sync/conflict_resolver.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:image/image.dart' as img;

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
          
          // Update local database - clear sync flag and update versions
          await database.profileDao.updateProfile(
            userId,
            localUser.copyWith(
              needsProfileSync: false,
              firebaseVersion: localUser.localVersion,
              lastSyncTime: DateTime.now(),
            ),
          );
          
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
    
    await docRef.set({
      'name': user.name,
      'email': user.email,
      'companyName': user.companyName,
      'phone': user.phone,
      'jobTitle': user.jobTitle,
      'postcodeOrArea': user.postcodeOrArea,
      'dateFormat': user.dateFormat,
      'imageUrl': user.imageFirebaseUrl,  // Add Firebase Storage URL for image
      'signatureUrl': user.signatureFirebaseUrl,  // Add Firebase Storage URL for signature
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
    return AppUser(
      id: userId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      companyName: data['companyName'] ?? '',
      postcodeOrArea: data['postcodeOrArea'],
      dateFormat: data['dateFormat'] ?? 'dd-MM-yyyy',
      imageLocalPath: null, // Will be synced separately
      imageFirebaseUrl: data['imageUrl'],
      signatureLocalPath: null, // Will be synced separately
      signatureFirebaseUrl: data['signatureUrl'],
      needsProfileSync: false, // Just downloaded, no need to sync back
      needsImageSync: data['imageUrl'] != null, // Need to download image
      needsSignatureSync: data['signatureUrl'] != null, // Need to download signature
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
        imageFirebaseUrl: data['imageFirebaseUrl'],
        signatureFirebaseUrl: data['signatureFirebaseUrl'],
        firebaseVersion: data['version'] ?? 1,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
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
        print('  - Firebase URL: ${localUser.imageFirebaseUrl}');
        print('  - needsImageSync: ${localUser.needsImageSync}');
      }
      
      // Check if this is a deletion sync: localPath is null/empty but Firebase URL exists
      if (imagePath.isEmpty && localUser.imageFirebaseUrl != null && localUser.imageFirebaseUrl!.isNotEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Deletion sync - local path empty but Firebase URL exists');
        }
        
        // Delete from Firebase Storage
        try {
          final storageRef = storage.ref('users/$userId/profile.jpg');
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
        
        // Clear the Firebase URL and sync flag in local database
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            imageFirebaseUrl: null,
            needsImageSync: false,
          ),
        );
        
        // Also clear the image URL in Firebase Firestore
        await firestore.collection('Profile').doc(userId).update({
          'imageUrl': null,
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
            'imageUrl': null,
            'updatedAt': Timestamp.now(),
          });
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Cleared imageUrl in Firestore');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Error updating Firestore: $e');
          }
        }
        
        // Clear the sync flag
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            needsImageSync: false,
          ),
        );
        
        return true;
      }
      
      // Check if local file exists for upload
      final imageFile = await imageStorage.getImageFile(imagePath);
      if (!imageFile.existsSync()) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncProfileImage: Local file does not exist at path: $imagePath');
        }
        // Clear the sync flag since we can't sync a non-existent file
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
          quality: 85,
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
          final downloadUrl = await snapshot.ref.getDownloadURL();
          
          if (kDebugMode) {
            print('ProfileSyncHandler.syncProfileImage: Upload successful, URL: $downloadUrl');
          }

          // Update local database
          await database.profileDao.updateProfile(
            userId,
            localUser.copyWith(
              imageFirebaseUrl: downloadUrl,
              needsImageSync: false,
            ),
          );
          
          // Also update Firebase Firestore with the new image URL
          await firestore.collection('Profile').doc(userId).update({
            'imageUrl': downloadUrl,
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

      // Check if this is a deletion sync: localPath is null/empty but Firebase URL exists
      if (signaturePath.isEmpty && localUser.signatureFirebaseUrl != null && localUser.signatureFirebaseUrl!.isNotEmpty) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Deletion sync - local path empty but Firebase URL exists');
          print('  - Firebase URL: ${localUser.signatureFirebaseUrl}');
        }
        
        // Delete from Firebase Storage
        try {
          final storageRef = storage.ref('users/$userId/signature.png');
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
        
        // Clear the Firebase URL and sync flag in local database
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            signatureFirebaseUrl: null,
            needsSignatureSync: false,
          ),
        );
        
        // Also clear the signature URL in Firebase Firestore
        await firestore.collection('Profile').doc(userId).update({
          'signatureUrl': null,
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
          final storageRef = storage.ref('users/$userId/signature.png');
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
            'signatureUrl': null,
            'updatedAt': Timestamp.now(),
          });
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Cleared signatureUrl in Firestore');
          }
        } catch (e) {
          if (kDebugMode) {
            print('ProfileSyncHandler.syncSignatureImage: Error updating Firestore: $e');
          }
        }
        
        // Clear the sync flag
        await database.profileDao.updateProfile(
          userId,
          localUser.copyWith(
            needsSignatureSync: false,
          ),
        );
        
        return true;
      }
      
      // Check if local file exists for upload
      final signatureFile = await imageStorage.getImageFile(signaturePath);
      if (!signatureFile.existsSync()) {
        if (kDebugMode) {
          print('ProfileSyncHandler.syncSignatureImage: Local file does not exist at path: $signaturePath');
        }
        // Clear the sync flag since we can't sync a non-existent file
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
      
      final storageRef = storage.ref('users/$userId/signature.png');
      final uploadTask = storageRef.putData(imageBytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update local database
      await database.profileDao.updateProfile(
        userId,
        localUser.copyWith(
          signatureFirebaseUrl: downloadUrl,
          needsSignatureSync: false,
        ),
      );
      
      // Also update Firebase Firestore with the new signature URL
      await firestore.collection('Profile').doc(userId).update({
        'signatureUrl': downloadUrl,
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
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    }

    // Just compress
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
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

  Future<void> syncAll(String userId) async {
    final localUser = await database.profileDao.getProfile(userId);
    if (localUser == null) return;

    // Sync profile data
    if (localUser.needsProfileSync) {
      await syncProfileData(userId);
    }

    // Sync images
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