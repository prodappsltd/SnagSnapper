import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/sites_table.dart';
import '../../models/site.dart';

part 'site_dao.g.dart';

/// Data Access Object for Site operations
/// 
/// Handles all database operations for sites including:
/// - CRUD operations
/// - Sync flag management
/// - Permission queries
/// - Statistics updates
@DriftAccessor(tables: [Sites])
class SiteDao extends DatabaseAccessor<AppDatabase> with _$SiteDaoMixin {
  SiteDao(AppDatabase db) : super(db);

  // ============== CREATE Operations ==============
  
  /// Insert a new site into the database
  /// Returns the inserted site's ID
  Future<String> insertSite(Site site) async {
    try {
      final entry = _siteToEntry(site);
      await into(sites).insert(entry);
      
      if (kDebugMode) {
        print('SiteDao: Successfully inserted site ${site.id}');
      }
      
      return site.id;
    } catch (e) {
      if (kDebugMode) {
        print('SiteDao: Error inserting site ${site.id}: $e');
      }
      rethrow;
    }
  }

  // ============== READ Operations ==============
  
  /// Get all sites for the current user (owned and shared)
  /// Returns sites ordered by updatedAt descending (newest first)
  Future<List<Site>> getAllSites(String userEmail) async {
    final query = select(sites)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    
    final entries = await query.get();
    
    // Filter sites where user is owner or in sharedWith
    return entries
        .where((entry) => 
            entry.ownerEmail == userEmail ||
            _isUserInSharedWith(entry.sharedWith, userEmail))
        .map((entry) => _entryToSite(entry))
        .toList();
  }
  
  /// Get only owned sites for the current user
  Future<List<Site>> getOwnedSites(String userEmail) async {
    final query = select(sites)
      ..where((t) => t.ownerEmail.equals(userEmail))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    
    final entries = await query.get();
    return entries.map((entry) => _entryToSite(entry)).toList();
  }
  
  /// Get only shared sites for the current user
  Future<List<Site>> getSharedSites(String userEmail) async {
    final query = select(sites)
      ..where((t) => t.ownerEmail.equals(userEmail).not())
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    
    final entries = await query.get();
    
    // Filter sites where user is in sharedWith
    return entries
        .where((entry) => _isUserInSharedWith(entry.sharedWith, userEmail))
        .map((entry) => _entryToSite(entry))
        .toList();
  }
  
  /// Get sites that are not archived
  Future<List<Site>> getActiveSites(String userEmail) async {
    final query = select(sites)
      ..where((t) => t.archive.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    
    final entries = await query.get();
    
    // Filter for user access
    return entries
        .where((entry) => 
            entry.ownerEmail == userEmail ||
            _isUserInSharedWith(entry.sharedWith, userEmail))
        .map((entry) => _entryToSite(entry))
        .toList();
  }
  
  /// Get a single site by ID
  Future<Site?> getSiteById(String id) async {
    final query = select(sites)..where((t) => t.id.equals(id));
    final entry = await query.getSingleOrNull();
    return entry != null ? _entryToSite(entry) : null;
  }
  
  /// Get sites that need syncing
  Future<List<Site>> getSitesNeedingSync() async {
    final query = select(sites)
      ..where((t) => 
          t.needsSiteSync.equals(true) | 
          t.needsImageSync.equals(true) | 
          t.needsSnagsSync.equals(true));
    
    final entries = await query.get();
    return entries.map((entry) => _entryToSite(entry)).toList();
  }

  // ============== UPDATE Operations ==============
  
  /// Update an existing site
  Future<bool> updateSite(Site site) async {
    try {
      // Increment local version for tracking
      final updatedSite = site.copyWith(
        localVersion: site.localVersion + 1,
        updatedAt: DateTime.now(),
        needsSiteSync: true, // Mark for sync
      );
      
      final entry = _siteToEntry(updatedSite);
      final result = await update(sites).replace(entry);
      
      if (kDebugMode) {
        print('SiteDao: Updated site ${site.id}, result: $result');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('SiteDao: Error updating site ${site.id}: $e');
      }
      rethrow;
    }
  }
  
  /// Update site statistics (snag counts)
  Future<void> updateSiteStatistics(
    String siteId, {
    int? totalSnags,
    int? openSnags,
    int? closedSnags,
  }) async {
    await (update(sites)..where((t) => t.id.equals(siteId))).write(
      SitesCompanion(
        totalSnags: totalSnags != null ? Value(totalSnags) : const Value.absent(),
        openSnags: openSnags != null ? Value(openSnags) : const Value.absent(),
        closedSnags: closedSnags != null ? Value(closedSnags) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  /// Add or update a category for a site
  Future<void> addSiteCategory(String siteId, int categoryId, String categoryName) async {
    try {
      final site = await getSiteById(siteId);
      if (site == null) {
        if (kDebugMode) {
          print('SiteDao: Cannot add category - site $siteId not found');
        }
        return;
      }
      
      final updatedCategories = Map<int, String>.from(site.snagCategories);
      updatedCategories[categoryId] = categoryName;
      
      await updateSite(site.copyWith(
        snagCategories: updatedCategories,
      ));
      
      if (kDebugMode) {
        print('SiteDao: Added category $categoryId:$categoryName to site $siteId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SiteDao: Error adding category to site $siteId: $e');
      }
      rethrow;
    }
  }
  
  /// Clear sync flags after successful sync
  Future<void> clearSyncFlags(String siteId) async {
    await (update(sites)..where((t) => t.id.equals(siteId))).write(
      SitesCompanion(
        needsSiteSync: const Value(false),
        needsImageSync: const Value(false),
        needsSnagsSync: const Value(false),
        lastSyncTime: Value(DateTime.now()),
      ),
    );
  }
  
  /// Mark site for deletion (soft delete)
  Future<void> markSiteForDeletion(String siteId) async {
    final now = DateTime.now();
    await (update(sites)..where((t) => t.id.equals(siteId))).write(
      SitesCompanion(
        markedForDeletion: const Value(true),
        deletionDate: Value(now),
        scheduledDeletionDate: Value(now.add(const Duration(days: 7))),
        needsSiteSync: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }
  
  /// Archive/unarchive a site
  Future<void> archiveSite(String siteId, bool archived) async {
    await (update(sites)..where((t) => t.id.equals(siteId))).write(
      SitesCompanion(
        archive: Value(archived),
        needsSiteSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ============== DELETE Operations ==============
  
  /// Permanently delete a site from local database
  /// WARNING: This is permanent deletion, use markSiteForDeletion for soft delete
  Future<int> deleteSite(String siteId) async {
    try {
      final count = await (delete(sites)..where((t) => t.id.equals(siteId))).go();
      
      if (kDebugMode) {
        print('SiteDao: Permanently deleted site $siteId, count: $count');
      }
      
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('SiteDao: Error deleting site $siteId: $e');
      }
      rethrow;
    }
  }
  
  /// Delete all sites marked for deletion past their scheduled date
  Future<int> deleteExpiredSites() async {
    try {
      final now = DateTime.now();
      final count = await (delete(sites)
        ..where((t) => 
            t.markedForDeletion.equals(true) & 
            t.scheduledDeletionDate.isSmallerOrEqualValue(now)))
        .go();
      
      if (kDebugMode && count > 0) {
        print('SiteDao: Deleted $count expired sites');
      }
      
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('SiteDao: Error deleting expired sites: $e');
      }
      rethrow;
    }
  }

  // ============== Permission Management ==============
  
  /// Update sharing permissions for a site
  Future<void> updateSiteSharing(
    String siteId, 
    Map<String, String> newSharedWith,
  ) async {
    await (update(sites)..where((t) => t.id.equals(siteId))).write(
      SitesCompanion(
        sharedWith: Value(jsonEncode(newSharedWith)),
        needsSiteSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  
  /// Add a user to site sharing
  Future<void> addUserToSite(
    String siteId,
    String userEmail,
    String permission, // VIEW, FIXER, or CONTRIBUTOR
  ) async {
    final site = await getSiteById(siteId);
    if (site == null) return;
    
    final updatedSharing = Map<String, String>.from(site.sharedWith);
    updatedSharing[userEmail.toLowerCase()] = permission;
    
    await updateSiteSharing(siteId, updatedSharing);
  }
  
  /// Remove a user from site sharing
  Future<void> removeUserFromSite(String siteId, String userEmail) async {
    final site = await getSiteById(siteId);
    if (site == null) return;
    
    final updatedSharing = Map<String, String>.from(site.sharedWith);
    updatedSharing.remove(userEmail.toLowerCase());
    
    await updateSiteSharing(siteId, updatedSharing);
  }

  // ============== Helper Methods ==============
  
  /// Convert Site model to database entry
  SitesCompanion _siteToEntry(Site site) {
    return SitesCompanion(
      id: Value(site.id),
      ownerUID: Value(site.ownerUID),
      ownerEmail: Value(site.ownerEmail),
      name: Value(site.name),
      companyName: Value(site.companyName),
      address: Value(site.address),
      contactPerson: Value(site.contactPerson),
      contactPhone: Value(site.contactPhone),
      date: Value(site.date),
      expectedCompletion: Value(site.expectedCompletion),
      imageLocalPath: Value(site.imageLocalPath),
      imageFirebasePath: Value(site.imageFirebasePath),
      pictureQuality: Value(site.pictureQuality),
      archive: Value(site.archive),
      sharedWith: Value(jsonEncode(site.sharedWith)),
      totalSnags: Value(site.totalSnags),
      openSnags: Value(site.openSnags),
      closedSnags: Value(site.closedSnags),
      snagCategories: Value(jsonEncode(
        site.snagCategories.map((k, v) => MapEntry(k.toString(), v))
      )),
      needsSiteSync: Value(site.needsSiteSync),
      needsImageSync: Value(site.needsImageSync),
      needsSnagsSync: Value(site.needsSnagsSync),
      lastSyncTime: Value(site.lastSyncTime),
      lastSnagUpdate: Value(site.lastSnagUpdate),
      updatedSnags: Value(jsonEncode(site.updatedSnags)),
      updateCount: Value(site.updateCount),
      markedForDeletion: Value(site.markedForDeletion),
      deletionDate: Value(site.deletionDate),
      scheduledDeletionDate: Value(site.scheduledDeletionDate),
      localVersion: Value(site.localVersion),
      firebaseVersion: Value(site.firebaseVersion),
      updatedAt: Value(site.updatedAt),
    );
  }
  
  /// Convert database entry to Site model
  Site _entryToSite(SiteEntry entry) {
    // Parse JSON fields with proper error handling
    final sharedWithMap = jsonDecode(entry.sharedWith) as Map<String, dynamic>;
    final categoriesJson = jsonDecode(entry.snagCategories) as Map<String, dynamic>;
    final updatedSnagsList = jsonDecode(entry.updatedSnags) as List<dynamic>;
    
    // Convert categories from string keys to int keys
    // Handle empty map case
    final Map<int, String> categories = categoriesJson.isEmpty 
        ? {}
        : categoriesJson.map((key, value) => 
            MapEntry(int.tryParse(key) ?? 0, value as String));
    
    return Site(
      id: entry.id,
      ownerUID: entry.ownerUID,
      ownerEmail: entry.ownerEmail,
      name: entry.name,
      companyName: entry.companyName,
      address: entry.address,
      contactPerson: entry.contactPerson,
      contactPhone: entry.contactPhone,
      date: entry.date,
      expectedCompletion: entry.expectedCompletion,
      imageLocalPath: entry.imageLocalPath,
      imageFirebasePath: entry.imageFirebasePath,
      pictureQuality: entry.pictureQuality,
      archive: entry.archive,
      sharedWith: Map<String, String>.from(sharedWithMap),
      totalSnags: entry.totalSnags,
      openSnags: entry.openSnags,
      closedSnags: entry.closedSnags,
      snagCategories: categories,
      needsSiteSync: entry.needsSiteSync,
      needsImageSync: entry.needsImageSync,
      needsSnagsSync: entry.needsSnagsSync,
      lastSyncTime: entry.lastSyncTime,
      lastSnagUpdate: entry.lastSnagUpdate,
      updatedSnags: List<String>.from(updatedSnagsList),
      updateCount: entry.updateCount,
      markedForDeletion: entry.markedForDeletion,
      deletionDate: entry.deletionDate,
      scheduledDeletionDate: entry.scheduledDeletionDate,
      localVersion: entry.localVersion,
      firebaseVersion: entry.firebaseVersion,
      updatedAt: entry.updatedAt,
    );
  }
  
  /// Check if a user is in the sharedWith JSON string
  bool _isUserInSharedWith(String sharedWithJson, String userEmail) {
    try {
      final sharedWith = jsonDecode(sharedWithJson) as Map<String, dynamic>;
      return sharedWith.containsKey(userEmail.toLowerCase());
    } catch (e) {
      return false;
    }
  }
  
  // ============== Batch Operations ==============
  
  /// Insert multiple sites in a batch
  Future<void> insertSitesBatch(List<Site> sitesList) async {
    await batch((batch) {
      for (final site in sitesList) {
        batch.insert(sites, _siteToEntry(site));
      }
    });
  }
  
  /// Watch all sites for real-time updates
  Stream<List<Site>> watchAllSites(String userEmail) {
    final query = select(sites)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    
    return query.watch().map((entries) => 
      entries
        .where((entry) => 
            entry.ownerEmail == userEmail ||
            _isUserInSharedWith(entry.sharedWith, userEmail))
        .map((entry) => _entryToSite(entry))
        .toList()
    );
  }
  
  /// Watch a single site for real-time updates
  Stream<Site?> watchSite(String siteId) {
    final query = select(sites)..where((t) => t.id.equals(siteId));
    return query.watchSingleOrNull().map((entry) => 
      entry != null ? _entryToSite(entry) : null
    );
  }
}