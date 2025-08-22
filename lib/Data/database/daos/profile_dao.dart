import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/profile_table.dart';
import '../../models/app_user.dart';
import '../../colleague.dart';

part 'profile_dao.g.dart';

/// Data Access Object for Profile operations
/// Implements all CRUD operations and sync management for profiles
@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(AppDatabase db) : super(db);

  /// Insert a new profile
  /// Returns true if successful, false otherwise
  Future<bool> insertProfile(AppUser user) async {
    if (kDebugMode) {
      print('🔍 ProfileDao: Inserting profile with flags:');
      print('  - needsProfileSync: ${user.needsProfileSync}');
      print('  - needsImageSync: ${user.needsImageSync}');
      print('  - needsSignatureSync: ${user.needsSignatureSync}');
      print('  - imageMarkedForDeletion: ${user.imageMarkedForDeletion}');
      print('  - signatureMarkedForDeletion: ${user.signatureMarkedForDeletion}');
    }
    
    try {
      // Validate the user data before inserting
      AppUser.validate(
        name: user.name,
        email: user.email,
        phone: user.phone,
        jobTitle: user.jobTitle,
        companyName: user.companyName,
        imageLocalPath: user.imageLocalPath,
        signatureLocalPath: user.signatureLocalPath,
        dateFormat: user.dateFormat,
      );

      // Convert colleagues list to JSON string
      String? colleaguesJson;
      if (user.listOfALLColleagues != null && user.listOfALLColleagues!.isNotEmpty) {
        colleaguesJson = json.encode(
          user.listOfALLColleagues!.map((c) => c.toJson()).toList()
        );
      }
      
      // Convert AppUser to ProfilesCompanion for Drift
      final companion = ProfilesCompanion(
        id: Value(user.id),
        name: Value(user.name),
        email: Value(user.email),
        phone: Value(user.phone),
        jobTitle: Value(user.jobTitle),
        companyName: Value(user.companyName),
        postcodeArea: Value(user.postcodeOrArea),
        dateFormat: Value(user.dateFormat),
        imageLocalPath: Value(user.imageLocalPath),
        imageFirebasePath: Value(user.imageFirebasePath),
        signatureLocalPath: Value(user.signatureLocalPath),
        signatureFirebasePath: Value(user.signatureFirebasePath),
        colleagues: Value(colleaguesJson),
        imageMarkedForDeletion: Value(user.imageMarkedForDeletion),
        signatureMarkedForDeletion: Value(user.signatureMarkedForDeletion),
        needsProfileSync: Value(user.needsProfileSync),
        needsImageSync: Value(user.needsImageSync),
        needsSignatureSync: Value(user.needsSignatureSync),
        lastSyncTime: Value(user.lastSyncTime),
        currentDeviceId: Value(user.currentDeviceId),
        lastLoginTime: Value(user.lastLoginTime),
        createdAt: Value(user.createdAt),
        updatedAt: Value(user.updatedAt),
        localVersion: Value(user.localVersion),
        firebaseVersion: Value(user.firebaseVersion),
      );

      // Insert into database
      await into(profiles).insert(companion);
      
      if (kDebugMode) {
        print('🔍 ProfileDao: Insert complete for user ${user.id}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error inserting profile: $e');
      }
      return false;
    }
  }

  /// Get profile by user ID
  /// Returns AppUser if found, null otherwise
  Future<AppUser?> getProfile(String userId) async {
    try {
      // Query for the profile
      final query = select(profiles)..where((tbl) => tbl.id.equals(userId));
      final result = await query.getSingleOrNull();
      
      if (result == null) {
        if (kDebugMode) {
          print('ProfileDao: No profile found for user $userId');
        }
        return null;
      }

      // Convert ProfileEntry to AppUser
      return _profileEntryToAppUser(result);
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error getting profile: $e');
      }
      return null;
    }
  }

  /// Update existing profile
  /// Returns true if successful, false otherwise
  Future<bool> updateProfile(String userId, AppUser updatedUser) async {
    try {
      // Validate the updated data
      AppUser.validate(
        name: updatedUser.name,
        email: updatedUser.email,
        phone: updatedUser.phone,
        jobTitle: updatedUser.jobTitle,
        companyName: updatedUser.companyName,
        imageLocalPath: updatedUser.imageLocalPath,
        signatureLocalPath: updatedUser.signatureLocalPath,
        dateFormat: updatedUser.dateFormat,
      );

      // Convert colleagues list to JSON string
      String? colleaguesJson;
      if (updatedUser.listOfALLColleagues != null && updatedUser.listOfALLColleagues!.isNotEmpty) {
        colleaguesJson = json.encode(
          updatedUser.listOfALLColleagues!.map((c) => c.toJson()).toList()
        );
        if (kDebugMode) {
          print('ProfileDao.updateProfile: Saving ${updatedUser.listOfALLColleagues!.length} colleagues');
          print('ProfileDao.updateProfile: Colleagues JSON: $colleaguesJson');
        }
      } else {
        if (kDebugMode) {
          print('ProfileDao.updateProfile: No colleagues to save');
        }
      }

      // Create update companion
      final companion = ProfilesCompanion(
        name: Value(updatedUser.name),
        email: Value(updatedUser.email),
        phone: Value(updatedUser.phone),
        jobTitle: Value(updatedUser.jobTitle),
        companyName: Value(updatedUser.companyName),
        postcodeArea: Value(updatedUser.postcodeOrArea),
        dateFormat: Value(updatedUser.dateFormat),
        imageLocalPath: Value(updatedUser.imageLocalPath),
        imageFirebasePath: Value(updatedUser.imageFirebasePath),
        signatureLocalPath: Value(updatedUser.signatureLocalPath),
        signatureFirebasePath: Value(updatedUser.signatureFirebasePath),
        colleagues: Value(colleaguesJson),
        imageMarkedForDeletion: Value(updatedUser.imageMarkedForDeletion),
        signatureMarkedForDeletion: Value(updatedUser.signatureMarkedForDeletion),
        needsProfileSync: Value(updatedUser.needsProfileSync),
        needsImageSync: Value(updatedUser.needsImageSync),
        needsSignatureSync: Value(updatedUser.needsSignatureSync),
        lastSyncTime: Value(updatedUser.lastSyncTime),
        currentDeviceId: Value(updatedUser.currentDeviceId),
        lastLoginTime: Value(updatedUser.lastLoginTime),
        updatedAt: Value(DateTime.now()),
        localVersion: Value(updatedUser.localVersion),
        firebaseVersion: Value(updatedUser.firebaseVersion),
      );

      // Update the profile
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(companion);
      
      if (kDebugMode) {
        print('ProfileDao: Profile updated for user $userId (rows affected: $rowsAffected)');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating profile: $e');
      }
      return false;
    }
  }

  /// Delete profile by user ID
  /// Returns true if successful, false otherwise
  Future<bool> deleteProfile(String userId) async {
    try {
      // Delete the profile
      final rowsDeleted = await (delete(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .go();
      
      if (kDebugMode) {
        print('ProfileDao: Profile deleted for user $userId (rows deleted: $rowsDeleted)');
      }
      
      return rowsDeleted > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error deleting profile: $e');
      }
      return false;
    }
  }

  /// Check if profile exists
  /// Returns true if exists, false otherwise
  Future<bool> profileExists(String userId) async {
    try {
      final query = select(profiles)..where((tbl) => tbl.id.equals(userId));
      final result = await query.getSingleOrNull();
      return result != null;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error checking profile existence: $e');
      }
      return false;
    }
  }

  /// Set needsProfileSync flag for a user
  Future<bool> setNeedsProfileSync(String userId) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsProfileSync: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Set needsProfileSync for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error setting needsProfileSync: $e');
      }
      return false;
    }
  }

  /// Set needsImageSync flag for a user
  Future<bool> setNeedsImageSync(String userId) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsImageSync: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Set needsImageSync for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error setting needsImageSync: $e');
      }
      return false;
    }
  }

  /// Set needsSignatureSync flag for a user
  Future<bool> setNeedsSignatureSync(String userId) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsSignatureSync: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Set needsSignatureSync for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error setting needsSignatureSync: $e');
      }
      return false;
    }
  }

  /// Clear all sync flags for a user
  /// Called after successful sync
  /// Clear only the profile sync flag (not image/signature sync flags)
  Future<bool> clearProfileSyncFlag(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsProfileSync: const Value(false),
          lastSyncTime: Value(now),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared profile sync flag for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing profile sync flag: $e');
      }
      return false;
    }
  }

  /// Clear only the image sync flag
  Future<bool> clearImageSyncFlag(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsImageSync: const Value(false),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared image sync flag for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing image sync flag: $e');
      }
      return false;
    }
  }

  /// Clear only the signature sync flag
  Future<bool> clearSignatureSyncFlag(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsSignatureSync: const Value(false),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared signature sync flag for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing signature sync flag: $e');
      }
      return false;
    }
  }

  /// Update only the image Firebase path
  Future<bool> updateImageFirebasePath(String userId, String? firebasePath) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          imageFirebasePath: Value(firebasePath),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated image Firebase path for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating image Firebase path: $e');
      }
      return false;
    }
  }

  /// Update only the signature Firebase path
  Future<bool> updateSignatureFirebasePath(String userId, String? firebasePath) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          signatureFirebasePath: Value(firebasePath),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated signature Firebase path for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating signature Firebase path: $e');
      }
      return false;
    }
  }

  /// Update only the image local path (after download)
  Future<bool> updateImageLocalPath(String userId, String? localPath) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          imageLocalPath: Value(localPath),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated image local path for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating image local path: $e');
      }
      return false;
    }
  }

  /// Update only the signature local path (after download)
  Future<bool> updateSignatureLocalPath(String userId, String? localPath) async {
    try {
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          signatureLocalPath: Value(localPath),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated signature local path for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating signature local path: $e');
      }
      return false;
    }
  }

  Future<bool> clearSyncFlags(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          needsProfileSync: const Value(false),
          needsImageSync: const Value(false),
          needsSignatureSync: const Value(false),
          lastSyncTime: Value(now),
          syncStatus: const Value('synced'),
          syncErrorMessage: const Value.absent(),
          syncRetryCount: const Value(0),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared sync flags for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing sync flags: $e');
      }
      return false;
    }
  }

  /// Set image marked for deletion flag
  /// Called when image is deleted offline
  Future<bool> setImageMarkedForDeletion(String userId, bool value) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          imageMarkedForDeletion: Value(value),
          needsImageSync: const Value(true),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Set imageMarkedForDeletion=$value for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error setting imageMarkedForDeletion: $e');
      }
      return false;
    }
  }

  /// Set signature marked for deletion flag
  /// Called when signature is deleted offline
  Future<bool> setSignatureMarkedForDeletion(String userId, bool value) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          signatureMarkedForDeletion: Value(value),
          needsSignatureSync: const Value(true),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Set signatureMarkedForDeletion=$value for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error setting signatureMarkedForDeletion: $e');
      }
      return false;
    }
  }

  /// Clear image deletion flag after successful sync
  Future<bool> clearImageDeletionFlag(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          imageMarkedForDeletion: const Value(false),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared imageMarkedForDeletion for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing imageMarkedForDeletion: $e');
      }
      return false;
    }
  }

  /// Clear signature deletion flag after successful sync
  Future<bool> clearSignatureDeletionFlag(String userId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          signatureMarkedForDeletion: const Value(false),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Cleared signatureMarkedForDeletion for user $userId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error clearing signatureMarkedForDeletion: $e');
      }
      return false;
    }
  }

  /// Get all profiles that need syncing
  /// Returns list of AppUser objects with sync flags set
  Future<List<AppUser>> getProfilesNeedingSync() async {
    try {
      // Query for profiles with any sync flag set
      final query = select(profiles)
        ..where((tbl) => 
          tbl.needsProfileSync.equals(true) |
          tbl.needsImageSync.equals(true) |
          tbl.needsSignatureSync.equals(true)
        );
      
      final results = await query.get();
      
      if (kDebugMode) {
        print('ProfileDao: Found ${results.length} profiles needing sync');
      }
      
      // Convert ProfileEntry objects to AppUser
      return results.map((entry) => _profileEntryToAppUser(entry)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error getting profiles needing sync: $e');
      }
      return [];
    }
  }

  /// Update device information for a user
  /// Called on login to track current device
  Future<bool> updateDeviceInfo(String userId, String deviceId) async {
    try {
      final now = DateTime.now();
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          currentDeviceId: Value(deviceId),
          lastLoginTime: Value(now),
          updatedAt: Value(now),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated device info for user $userId to device $deviceId');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating device info: $e');
      }
      return false;
    }
  }

  /// Check if the provided device ID matches the stored device ID
  /// Returns true if matches, false otherwise
  Future<bool> checkDeviceMatch(String userId, String deviceId) async {
    try {
      final profile = await getProfile(userId);
      if (profile == null) {
        return false;
      }
      
      final matches = profile.currentDeviceId == deviceId;
      
      if (kDebugMode) {
        print('ProfileDao: Device match check for user $userId: $matches');
      }
      
      return matches;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error checking device match: $e');
      }
      return false;
    }
  }

  /// Get count of all profiles in database
  /// Useful for analytics and debugging
  Future<int> getProfileCount() async {
    try {
      final countQuery = profiles.count();
      final count = await countQuery.getSingle();
      
      if (kDebugMode) {
        print('ProfileDao: Total profile count: $count');
      }
      
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error getting profile count: $e');
      }
      return 0;
    }
  }

  /// Execute operation in transaction
  /// Ensures atomicity of multiple operations
  Future<T> inTransaction<T>(Future<T> Function() action) async {
    return await db.transaction(() async {
      return await action();
    });
  }

  /// Update sync error information
  /// Called when sync fails to track retry attempts
  Future<bool> updateSyncError(String userId, String errorMessage) async {
    try {
      // Get current retry count
      final profile = await getProfile(userId);
      if (profile == null) return false;
      
      final newRetryCount = (profile.localVersion) + 1; // Using localVersion as proxy for retry count in this example
      
      final rowsAffected = await (update(profiles)
        ..where((tbl) => tbl.id.equals(userId)))
        .write(ProfilesCompanion(
          syncStatus: const Value('error'),
          syncErrorMessage: Value(errorMessage),
          syncRetryCount: Value(newRetryCount),
          updatedAt: Value(DateTime.now()),
        ));
      
      if (kDebugMode) {
        print('ProfileDao: Updated sync error for user $userId: $errorMessage');
      }
      
      return rowsAffected > 0;
    } catch (e) {
      if (kDebugMode) {
        print('ProfileDao: Error updating sync error: $e');
      }
      return false;
    }
  }

  /// Private helper to convert ProfileEntry to AppUser
  /// Handles the conversion between database model and domain model
  AppUser _profileEntryToAppUser(ProfileEntry entry) {
    // Parse colleagues from JSON string
    List<Colleague>? colleagues;
    if (entry.colleagues != null && entry.colleagues!.isNotEmpty) {
      try {
        final List<dynamic> colleaguesJson = json.decode(entry.colleagues!);
        colleagues = colleaguesJson
            .map((json) => Colleague.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          print('ProfileDao: Error parsing colleagues JSON: $e');
        }
      }
    }
    
    return AppUser(
      id: entry.id,
      name: entry.name,
      email: entry.email,
      phone: entry.phone ?? '',
      jobTitle: entry.jobTitle ?? '',
      companyName: entry.companyName,
      postcodeOrArea: entry.postcodeArea,
      dateFormat: entry.dateFormat,
      imageLocalPath: entry.imageLocalPath,
      imageFirebasePath: entry.imageFirebasePath,
      signatureLocalPath: entry.signatureLocalPath,
      signatureFirebasePath: entry.signatureFirebasePath,
      listOfALLColleagues: colleagues,
      imageMarkedForDeletion: entry.imageMarkedForDeletion,
      signatureMarkedForDeletion: entry.signatureMarkedForDeletion,
      needsProfileSync: entry.needsProfileSync,
      needsImageSync: entry.needsImageSync,
      needsSignatureSync: entry.needsSignatureSync,
      lastSyncTime: entry.lastSyncTime,
      currentDeviceId: entry.currentDeviceId,
      lastLoginTime: entry.lastLoginTime,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      localVersion: entry.localVersion,
      firebaseVersion: entry.firebaseVersion,
    );
  }

  /// Watch profile changes for a specific user
  /// Returns a stream that emits when profile changes
  Stream<AppUser?> watchProfile(String userId) {
    final query = select(profiles)..where((tbl) => tbl.id.equals(userId));
    
    return query.watchSingleOrNull().map((entry) {
      if (entry == null) return null;
      return _profileEntryToAppUser(entry);
    });
  }

  /// Watch all profiles needing sync
  /// Returns a stream that emits when sync status changes
  Stream<List<AppUser>> watchProfilesNeedingSync() {
    final query = select(profiles)
      ..where((tbl) => 
        tbl.needsProfileSync.equals(true) |
        tbl.needsImageSync.equals(true) |
        tbl.needsSignatureSync.equals(true)
      );
    
    return query.watch().map((entries) {
      return entries.map((entry) => _profileEntryToAppUser(entry)).toList();
    });
  }
}