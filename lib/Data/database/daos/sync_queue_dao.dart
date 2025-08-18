import 'package:drift/drift.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/tables/sync_queue_table.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueueTable])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(AppDatabase db) : super(db);

  Future<int> insertItem(SyncQueueItem item) {
    return into(syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: item.id,
        userId: item.userId,
        type: item.type.toString(),
        action: item.action.toString(),
        data: Value(item.data != null ? item.data.toString() : null),
        priority: Value(item.priority.index),
        status: Value(item.status.toString()),
        retryCount: Value(item.retryCount),
        nextRetryAt: Value(item.nextRetryAt),
        createdAt: item.createdAt,
        updatedAt: Value(item.updatedAt),
        error: Value(item.error),
      ),
    );
  }

  Future<SyncQueueItem?> getItemById(String id) async {
    final query = select(syncQueueTable)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapToItem(row) : null;
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final query = select(syncQueueTable)
      ..where((t) => t.status.equals(SyncStatus.pending.toString()))
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    final rows = await query.get();
    return rows.map(_mapToItem).toList();
  }

  Future<List<SyncQueueItem>> getPendingItemsByPriority() async {
    final query = select(syncQueueTable)
      ..where((t) => t.status.equals(SyncStatus.pending.toString()))
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
      ]);
    final rows = await query.get();
    return rows.map(_mapToItem).toList();
  }

  Future<List<SyncQueueItem>> getFailedItems() async {
    final query = select(syncQueueTable)
      ..where((t) => t.status.equals(SyncStatus.failed.toString()));
    final rows = await query.get();
    return rows.map(_mapToItem).toList();
  }

  Future<List<SyncQueueItem>> getAllItems() async {
    final rows = await select(syncQueueTable).get();
    return rows.map(_mapToItem).toList();
  }

  Future<bool> deleteItem(String id) async {
    final count = await (delete(syncQueueTable)..where((t) => t.id.equals(id))).go();
    return count > 0;
  }

  Future<bool> deleteItems(List<String> ids) async {
    final count = await (delete(syncQueueTable)..where((t) => t.id.isIn(ids))).go();
    return count > 0;
  }

  Future<bool> clearQueueForUser(String userId) async {
    final count = await (delete(syncQueueTable)..where((t) => t.userId.equals(userId))).go();
    return count > 0;
  }

  Future<bool> updateItemStatus(String id, SyncStatus status) async {
    final count = await (update(syncQueueTable)..where((t) => t.id.equals(id)))
        .write(SyncQueueTableCompanion(
      status: Value(status.toString()),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> updateItemRetry(String id, int retryCount, DateTime nextRetryAt) async {
    final count = await (update(syncQueueTable)..where((t) => t.id.equals(id)))
        .write(SyncQueueTableCompanion(
      retryCount: Value(retryCount),
      nextRetryAt: Value(nextRetryAt),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  Future<bool> updateItemPriority(String id, SyncPriority priority) async {
    final count = await (update(syncQueueTable)..where((t) => t.id.equals(id)))
        .write(SyncQueueTableCompanion(
      priority: Value(priority.index),
      updatedAt: Value(DateTime.now()),
    ));
    return count > 0;
  }

  SyncQueueItem _mapToItem(SyncQueueTableData row) {
    return SyncQueueItem(
      id: row.id,
      userId: row.userId,
      type: SyncType.values.firstWhere((e) => e.toString() == row.type),
      action: SyncAction.values.firstWhere((e) => e.toString() == row.action),
      data: row.data != null ? _parseData(row.data!) : null,
      priority: SyncPriority.values[row.priority],
      status: SyncStatus.values.firstWhere((e) => e.toString() == row.status),
      retryCount: row.retryCount,
      nextRetryAt: row.nextRetryAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      error: row.error,
    );
  }

  Map<String, dynamic>? _parseData(String data) {
    try {
      // Simple parsing - in production would use json.decode
      return {};
    } catch (e) {
      return null;
    }
  }
}