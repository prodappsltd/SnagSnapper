import 'package:snagsnapper/Data/models/sync_status.dart';

enum SyncType {
  profile,
  image,
  signature,
  settings,
}

enum SyncAction {
  upload,
  download,
  delete,
}

enum SyncPriority {
  low,
  normal,
  high,
}

class SyncQueueItem {
  final String id;
  final String userId;
  final SyncType type;
  final SyncAction action;
  final Map<String, dynamic>? data;
  final SyncPriority priority;
  final SyncStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? error;

  SyncQueueItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.action,
    this.data,
    this.priority = SyncPriority.normal,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.nextRetryAt,
    required this.createdAt,
    this.updatedAt,
    this.error,
  });

  SyncQueueItem copyWith({
    String? id,
    String? userId,
    SyncType? type,
    SyncAction? action,
    Map<String, dynamic>? data,
    SyncPriority? priority,
    SyncStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? error,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      action: action ?? this.action,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      error: error ?? this.error,
    );
  }
}

class SyncBatch {
  final List<SyncQueueItem> items;
  final SyncType type;
  final SyncAction action;

  SyncBatch({
    required this.items,
    required this.type,
    required this.action,
  });
}

class QueueStatus {
  final int totalItems;
  final int profileItems;
  final int imageItems;
  final int pendingItems;
  final int syncingItems;
  final int failedItems;
  final bool isEmpty;
  final int processedCount;
  final Duration? averageWaitTime;
  final Duration? oldestItemAge;

  QueueStatus({
    this.totalItems = 0,
    this.profileItems = 0,
    this.imageItems = 0,
    this.pendingItems = 0,
    this.syncingItems = 0,
    this.failedItems = 0,
    this.processedCount = 0,
    this.averageWaitTime,
    this.oldestItemAge,
  }) : isEmpty = totalItems == 0;
}

enum QueueState {
  empty,
  hasItems,
  processing,
  error,
}

class ProcessingResult {
  final int processed;
  final int succeeded;
  final int failed;
  final Duration duration;

  ProcessingResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.duration,
  });
}

class QueueStatistics {
  final int totalItems;
  final int pendingItems;
  final int syncingItems;
  final int failedItems;
  final Duration? averageWaitTime;
  final Duration? oldestItemAge;

  QueueStatistics({
    required this.totalItems,
    required this.pendingItems,
    required this.syncingItems,
    required this.failedItems,
    this.averageWaitTime,
    this.oldestItemAge,
  });
}