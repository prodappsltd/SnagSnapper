import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../app_database.dart';
import '../tables/snags_table.dart';
import '../../models/snag.dart';
import '../../models/image_slot.dart';

part 'snag_dao.g.dart';

/// Data Access Object for Snag operations
///
/// Handles all database operations for snags including:
/// - CRUD operations
/// - Sync flag management
/// - Image slot updates
/// - Status changes
///
/// See: Claude/02-MODULES/Snags/SNAG_IMAGE_HANDLING_PLAN.md
@DriftAccessor(tables: [Snags])
class SnagDao extends DatabaseAccessor<AppDatabase> with _$SnagDaoMixin {
  SnagDao(AppDatabase db) : super(db);

  // ============== CREATE Operations ==============

  /// Insert a new snag into the database
  Future<String> insertSnag(Snag snag) async {
    try {
      final entry = _snagToEntry(snag);
      await into(snags).insert(entry);

      if (kDebugMode) {
        print('SnagDao: Inserted snag ${snag.id}');
      }

      return snag.id;
    } catch (e) {
      if (kDebugMode) {
        print('SnagDao: Error inserting snag ${snag.id}: $e');
      }
      rethrow;
    }
  }

  /// Upsert a snag (insert if new, update if exists)
  Future<bool> upsertSnag(Snag snag) async {
    try {
      final entry = _snagToEntry(snag);
      await into(snags).insertOnConflictUpdate(entry);

      if (kDebugMode) {
        print('SnagDao: Upserted snag ${snag.id}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('SnagDao: Error upserting snag ${snag.id}: $e');
      }
      return false;
    }
  }

  // ============== READ Operations ==============

  /// Get a single snag by ID
  Future<Snag?> getSnagById(String id) async {
    final query = select(snags)..where((t) => t.id.equals(id));
    final entry = await query.getSingleOrNull();
    return entry != null ? _entryToSnag(entry) : null;
  }

  /// Get all snags for a site
  Future<List<Snag>> getSnagsBySite(String siteUID) async {
    final query = select(snags)
      ..where((t) => t.siteUID.equals(siteUID))
      ..orderBy([(t) => OrderingTerm.desc(t.creationDate)]);

    final entries = await query.get();
    return entries.map((e) => _entryToSnag(e)).toList();
  }

  /// Get snags that need syncing
  Future<List<Snag>> getSnagsNeedingSync() async {
    final query = select(snags)
      ..where((t) =>
          t.needsSnagSync.equals(true) |
          t.needsImagesSync.equals(true));

    final entries = await query.get();
    return entries.map((e) => _entryToSnag(e)).toList();
  }

  /// Get snags for a site that need syncing
  Future<List<Snag>> getSnagsNeedingSyncBySite(String siteUID) async {
    final query = select(snags)
      ..where((t) =>
          t.siteUID.equals(siteUID) &
          (t.needsSnagSync.equals(true) | t.needsImagesSync.equals(true)));

    final entries = await query.get();
    return entries.map((e) => _entryToSnag(e)).toList();
  }

  // ============== UPDATE Operations ==============

  /// Update an existing snag
  Future<bool> updateSnag(Snag snag) async {
    try {
      final updatedSnag = snag.copyWith(
        localVersion: snag.localVersion + 1,
        updatedAt: DateTime.now(),
        needsSnagSync: true,
      );

      final entry = _snagToEntry(updatedSnag);
      final result = await update(snags).replace(entry);

      if (kDebugMode) {
        print('SnagDao: Updated snag ${snag.id}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('SnagDao: Error updating snag ${snag.id}: $e');
      }
      rethrow;
    }
  }

  /// Update only the images list for a snag (for instant image operations)
  Future<void> updateSnagImages(String snagId, List<ImageSlot> images) async {
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        images: Value(jsonEncode(ImageSlot.listToJson(images))),
        needsImagesSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (kDebugMode) {
      print('SnagDao: Updated images for snag $snagId');
    }
  }

  /// Update only the fix images list for a snag
  Future<void> updateSnagFixImages(String snagId, List<ImageSlot> fixImages) async {
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        fixImages: Value(jsonEncode(ImageSlot.listToJson(fixImages))),
        needsImagesSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (kDebugMode) {
      print('SnagDao: Updated fix images for snag $snagId');
    }
  }

  /// Update a single image slot (for sync handler)
  Future<void> updateImageSlot(String snagId, int slotIndex, ImageSlot slot) async {
    final snag = await getSnagById(snagId);
    if (snag == null) return;

    final updatedImages = List<ImageSlot>.from(snag.images);
    if (slotIndex >= 0 && slotIndex < 6) {
      updatedImages[slotIndex] = slot;
      await updateSnagImages(snagId, updatedImages);
    }
  }

  /// Update a single fix image slot
  Future<void> updateFixImageSlot(String snagId, int slotIndex, ImageSlot slot) async {
    final snag = await getSnagById(snagId);
    if (snag == null) return;

    final updatedFixImages = List<ImageSlot>.from(snag.fixImages);
    if (slotIndex >= 0 && slotIndex < 6) {
      updatedFixImages[slotIndex] = slot;
      await updateSnagFixImages(snagId, updatedFixImages);
    }
  }

  // ============== Status Operations ==============

  /// Mark snag as completed by fixer
  Future<void> markSnagCompleted(String snagId, String fixerEmail) async {
    final now = DateTime.now();
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        snagStatus: const Value(false),
        completedDate: Value(now),
        lastModifiedBy: Value(fixerEmail),
        lastModifiedDate: Value(now),
        needsSnagSync: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Confirm snag closure by owner
  Future<void> confirmSnagClosed(String snagId, String ownerEmail) async {
    final now = DateTime.now();
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        snagConfirmedStatus: const Value(false),
        lastModifiedBy: Value(ownerEmail),
        lastModifiedDate: Value(now),
        needsSnagSync: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Reject fix and reopen snag
  Future<void> rejectSnagFix(String snagId, String ownerEmail, String reason) async {
    final snag = await getSnagById(snagId);
    if (snag == null) return;

    final now = DateTime.now();
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        snagStatus: const Value(true),
        snagConfirmedStatus: const Value(true),
        rejectionReason: Value(reason),
        rejectionCount: Value(snag.rejectionCount + 1),
        lastModifiedBy: Value(ownerEmail),
        lastModifiedDate: Value(now),
        needsSnagSync: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  // ============== Sync Flag Operations ==============

  /// Clear snag sync flag after successful sync
  Future<void> clearSnagSyncFlag(String snagId) async {
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        needsSnagSync: const Value(false),
        lastSyncTime: Value(DateTime.now()),
      ),
    );
  }

  /// Clear images sync flag after successful sync
  Future<void> clearImagesSyncFlag(String snagId) async {
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        needsImagesSync: const Value(false),
        lastSyncTime: Value(DateTime.now()),
      ),
    );
  }

  /// Clear all sync flags
  Future<void> clearAllSyncFlags(String snagId) async {
    await (update(snags)..where((t) => t.id.equals(snagId))).write(
      SnagsCompanion(
        needsSnagSync: const Value(false),
        needsImagesSync: const Value(false),
        lastSyncTime: Value(DateTime.now()),
      ),
    );
  }

  // ============== DELETE Operations ==============

  /// Delete a snag permanently
  Future<int> deleteSnag(String snagId) async {
    try {
      final count = await (delete(snags)..where((t) => t.id.equals(snagId))).go();

      if (kDebugMode) {
        print('SnagDao: Deleted snag $snagId');
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        print('SnagDao: Error deleting snag $snagId: $e');
      }
      rethrow;
    }
  }

  /// Delete all snags for a site
  Future<int> deleteSnagsBySite(String siteUID) async {
    try {
      final count = await (delete(snags)..where((t) => t.siteUID.equals(siteUID))).go();

      if (kDebugMode) {
        print('SnagDao: Deleted $count snags for site $siteUID');
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        print('SnagDao: Error deleting snags for site $siteUID: $e');
      }
      rethrow;
    }
  }

  // ============== Watch Streams ==============

  /// Watch all snags for a site
  Stream<List<Snag>> watchSnagsBySite(String siteUID) {
    final query = select(snags)
      ..where((t) => t.siteUID.equals(siteUID))
      ..orderBy([(t) => OrderingTerm.desc(t.creationDate)]);

    return query.watch().map((entries) =>
      entries.map((e) => _entryToSnag(e)).toList()
    );
  }

  /// Watch a single snag
  Stream<Snag?> watchSnag(String snagId) {
    final query = select(snags)..where((t) => t.id.equals(snagId));
    return query.watchSingleOrNull().map((entry) =>
      entry != null ? _entryToSnag(entry) : null
    );
  }

  /// Watch snags needing sync
  Stream<List<Snag>> watchSnagsNeedingSync() {
    final query = select(snags)
      ..where((t) =>
          t.needsSnagSync.equals(true) |
          t.needsImagesSync.equals(true));

    return query.watch().map((entries) =>
      entries.map((e) => _entryToSnag(e)).toList()
    );
  }

  // ============== Helper Methods ==============

  /// Convert Snag model to database entry
  SnagsCompanion _snagToEntry(Snag snag) {
    return SnagsCompanion(
      id: Value(snag.id),
      siteUID: Value(snag.siteUID),
      ownerEmail: Value(snag.ownerEmail),
      creatorEmail: Value(snag.creatorEmail),
      title: Value(snag.title),
      description: Value(snag.description),
      location: Value(snag.location),
      asset: Value(snag.asset),
      priority: Value(snag.priority),
      dueDate: Value(snag.dueDate),
      creationDate: Value(snag.creationDate),
      snagCategory: Value(snag.snagCategory),
      assignedEmail: Value(snag.assignedEmail),
      assignedName: Value(snag.assignedName),
      images: Value(jsonEncode(ImageSlot.listToJson(snag.images))),
      snagFixDescription: Value(snag.snagFixDescription),
      fixImages: Value(jsonEncode(ImageSlot.listToJson(snag.fixImages))),
      snagStatus: Value(snag.snagStatus),
      snagConfirmedStatus: Value(snag.snagConfirmedStatus),
      lastModifiedBy: Value(snag.lastModifiedBy),
      lastModifiedDate: Value(snag.lastModifiedDate),
      completedDate: Value(snag.completedDate),
      rejectionReason: Value(snag.rejectionReason),
      rejectionCount: Value(snag.rejectionCount),
      costEstimate: Value(snag.costEstimate),
      needsSnagSync: Value(snag.needsSnagSync),
      needsImagesSync: Value(snag.needsImagesSync),
      lastSyncTime: Value(snag.lastSyncTime),
      localVersion: Value(snag.localVersion),
      firebaseVersion: Value(snag.firebaseVersion),
      createdAt: Value(snag.createdAt),
      updatedAt: Value(snag.updatedAt),
    );
  }

  /// Convert database entry to Snag model
  Snag _entryToSnag(SnagEntry entry) {
    // Parse ImageSlot lists from JSON
    final imagesJson = jsonDecode(entry.images) as List<dynamic>;
    final fixImagesJson = jsonDecode(entry.fixImages) as List<dynamic>;

    return Snag(
      id: entry.id,
      siteUID: entry.siteUID,
      ownerEmail: entry.ownerEmail,
      creatorEmail: entry.creatorEmail,
      title: entry.title,
      description: entry.description,
      location: entry.location,
      asset: entry.asset,
      priority: entry.priority,
      dueDate: entry.dueDate,
      creationDate: entry.creationDate,
      snagCategory: entry.snagCategory,
      assignedEmail: entry.assignedEmail,
      assignedName: entry.assignedName,
      images: ImageSlot.listFromJson(imagesJson),
      snagFixDescription: entry.snagFixDescription,
      fixImages: ImageSlot.listFromJson(fixImagesJson),
      snagStatus: entry.snagStatus,
      snagConfirmedStatus: entry.snagConfirmedStatus,
      lastModifiedBy: entry.lastModifiedBy,
      lastModifiedDate: entry.lastModifiedDate,
      completedDate: entry.completedDate,
      rejectionReason: entry.rejectionReason,
      rejectionCount: entry.rejectionCount,
      costEstimate: entry.costEstimate,
      needsSnagSync: entry.needsSnagSync,
      needsImagesSync: entry.needsImagesSync,
      lastSyncTime: entry.lastSyncTime,
      localVersion: entry.localVersion,
      firebaseVersion: entry.firebaseVersion,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  // ============== Batch Operations ==============

  /// Insert multiple snags in a batch
  Future<void> insertSnagsBatch(List<Snag> snagsList) async {
    await batch((batch) {
      for (final snag in snagsList) {
        batch.insert(snags, _snagToEntry(snag));
      }
    });
  }

  /// Get snag counts for a site (for statistics)
  Future<Map<String, int>> getSnagCountsBySite(String siteUID) async {
    final allSnags = await getSnagsBySite(siteUID);

    return {
      'total': allSnags.length,
      'open': allSnags.where((s) => s.isOpen).length,
      'closed': allSnags.where((s) => s.isClosed).length,
      'pendingConfirmation': allSnags.where((s) => s.isPendingConfirmation).length,
    };
  }
}
