import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';
import 'package:snagsnapper/services/sync/network_monitor.dart';

class SyncQueueManager {
  final AppDatabase database;
  final ProfileSyncHandler profileHandler;
  final NetworkMonitor networkMonitor;
  final SharedPreferences prefs;

  final _stateController = StreamController<QueueState>.broadcast();
  final _processingLock = _ProcessingLock();
  
  Function? _onQueueEmpty;
  Function(ProcessingResult)? _onProcessingComplete;

  SyncQueueManager({
    required this.database,
    required this.profileHandler,
    required this.networkMonitor,
    required this.prefs,
  });

  Stream<QueueState> get stateStream => _stateController.stream;

  Future<bool> addToQueue(SyncQueueItem item) async {
    try {
      // Check for duplicates
      final existing = await database.syncQueueDao.getItemById(item.id);
      if (existing != null) {
        return false;
      }

      // Insert item
      await database.syncQueueDao.insertItem(item);
      
      // Update preferences
      await prefs.setBool('has_pending_sync', true);
      
      // Emit state change
      _stateController.add(QueueState.hasItems);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFromQueue(String itemId) async {
    try {
      final success = await database.syncQueueDao.deleteItem(itemId);
      
      if (success) {
        // Check if queue is now empty
        final items = await database.syncQueueDao.getPendingItems();
        if (items.isEmpty) {
          await prefs.setBool('has_pending_sync', false);
          _stateController.add(QueueState.empty);
          _onQueueEmpty?.call();
        }
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearQueue(String userId) async {
    await database.syncQueueDao.clearQueueForUser(userId);
    await prefs.setBool('has_pending_sync', false);
    _stateController.add(QueueState.empty);
  }

  Future<QueueStatus> getQueueStatus() async {
    final items = await database.syncQueueDao.getAllItems();
    
    int profileItems = 0;
    int imageItems = 0;
    int pendingItems = 0;
    int syncingItems = 0;
    int failedItems = 0;
    
    DateTime? oldestItem;
    Duration totalWaitTime = Duration.zero;
    
    for (final item in items) {
      if (item.type == SyncType.profile) profileItems++;
      if (item.type == SyncType.image || item.type == SyncType.signature) imageItems++;
      if (item.status == SyncStatus.pending) pendingItems++;
      if (item.status == SyncStatus.syncing) syncingItems++;
      if (item.status == SyncStatus.failed) failedItems++;
      
      if (oldestItem == null || item.createdAt.isBefore(oldestItem)) {
        oldestItem = item.createdAt;
      }
      
      totalWaitTime += DateTime.now().difference(item.createdAt);
    }
    
    return QueueStatus(
      totalItems: items.length,
      profileItems: profileItems,
      imageItems: imageItems,
      pendingItems: pendingItems,
      syncingItems: syncingItems,
      failedItems: failedItems,
      processedCount: prefs.getInt('processed_count') ?? 0,
      averageWaitTime: items.isNotEmpty 
          ? Duration(milliseconds: totalWaitTime.inMilliseconds ~/ items.length)
          : null,
      oldestItemAge: oldestItem != null 
          ? DateTime.now().difference(oldestItem)
          : null,
    );
  }

  Future<void> processQueue() async {
    // Check if already processing
    if (!await _processingLock.acquire()) {
      return;
    }

    try {
      // Check network
      if (!await networkMonitor.isOnline()) {
        return;
      }

      final items = await database.syncQueueDao.getPendingItems();
      if (items.isEmpty) {
        _onQueueEmpty?.call();
        return;
      }

      _stateController.add(QueueState.processing);
      
      int processed = 0;
      int succeeded = 0;
      final stopwatch = Stopwatch()..start();

      for (final item in items) {
        // Check if ready for retry
        if (item.nextRetryAt != null && item.nextRetryAt!.isAfter(DateTime.now())) {
          continue;
        }

        // Update status to syncing
        await database.syncQueueDao.updateItemStatus(item.id, SyncStatus.syncing);
        
        try {
          // Process based on type
          bool success = false;
          
          switch (item.type) {
            case SyncType.profile:
              success = await profileHandler.syncProfileData(item.userId);
              break;
            case SyncType.image:
            case SyncType.signature:
              // Handle image/signature sync
              success = true;
              break;
            case SyncType.settings:
              // Handle settings sync
              success = true;
              break;
          }

          if (success) {
            await database.syncQueueDao.deleteItem(item.id);
            succeeded++;
          } else {
            throw Exception('Sync failed');
          }
        } catch (e) {
          // Handle error
          await _handleItemError(item, e);
        }
        
        processed++;
      }

      stopwatch.stop();
      
      // Update statistics
      final currentProcessed = prefs.getInt('processed_count') ?? 0;
      await prefs.setInt('processed_count', currentProcessed + processed);
      
      final currentSuccess = prefs.getInt('sync_success_count') ?? 0;
      final currentTotal = prefs.getInt('sync_total_count') ?? 0;
      await prefs.setInt('sync_success_count', currentSuccess + succeeded);
      await prefs.setInt('sync_total_count', currentTotal + processed);

      // Check if queue is empty
      final remaining = await database.syncQueueDao.getPendingItems();
      if (remaining.isEmpty) {
        await prefs.setBool('has_pending_sync', false);
        _stateController.add(QueueState.empty);
        _onQueueEmpty?.call();
      }

      // Notify completion
      _onProcessingComplete?.call(ProcessingResult(
        processed: processed,
        succeeded: succeeded,
        failed: processed - succeeded,
        duration: stopwatch.elapsed,
      ));
    } finally {
      _processingLock.release();
    }
  }

  Future<void> _handleItemError(SyncQueueItem item, dynamic error) async {
    // Check if it's a permanent error
    if (_isPermanentError(error)) {
      await database.syncQueueDao.updateItemStatus(item.id, SyncStatus.failed);
      return;
    }

    // Check retry count
    if (item.retryCount >= 3) {
      await database.syncQueueDao.updateItemStatus(item.id, SyncStatus.failed);
      return;
    }

    // Calculate next retry time with exponential backoff
    final delaySeconds = (item.retryCount + 1) * 60; // 1min, 2min, 3min
    final nextRetry = DateTime.now().add(Duration(seconds: delaySeconds));
    
    await database.syncQueueDao.updateItemRetry(
      item.id,
      item.retryCount + 1,
      nextRetry,
    );
  }

  bool _isPermanentError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('validation') ||
           errorString.contains('invalid') ||
           errorString.contains('permission');
  }

  Future<List<SyncBatch>> getBatches({int maxBatchSize = 10}) async {
    final items = await database.syncQueueDao.getPendingItems();
    final batches = <SyncBatch>[];
    
    // Group by type and action
    final groups = <String, List<SyncQueueItem>>{};
    for (final item in items) {
      final key = '${item.type}_${item.action}';
      groups[key] ??= [];
      groups[key]!.add(item);
    }
    
    // Create batches
    for (final group in groups.values) {
      for (int i = 0; i < group.length; i += maxBatchSize) {
        final end = (i + maxBatchSize < group.length) ? i + maxBatchSize : group.length;
        batches.add(SyncBatch(
          items: group.sublist(i, end),
          type: group[i].type,
          action: group[i].action,
        ));
      }
    }
    
    return batches;
  }

  Future<void> processBatch(List<SyncQueueItem> batch) async {
    try {
      // Process as batch
      final success = await profileHandler.syncBatch(batch);
      
      if (success) {
        // Delete all items
        await database.syncQueueDao.deleteItems(batch.map((i) => i.id).toList());
      } else {
        throw Exception('Batch processing failed');
      }
    } catch (e) {
      // Update retry for all items
      for (final item in batch) {
        await _handleItemError(item, e);
      }
    }
  }

  Future<List<SyncQueueItem>> getQueueByPriority() async {
    return await database.syncQueueDao.getPendingItemsByPriority();
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    return await database.syncQueueDao.getPendingItems();
  }

  Future<void> promoteOldItems() async {
    final items = await database.syncQueueDao.getPendingItems();
    
    for (final item in items) {
      // Promote items older than 1 day
      if (DateTime.now().difference(item.createdAt).inDays >= 1) {
        if (item.priority == SyncPriority.low) {
          await database.syncQueueDao.updateItemPriority(item.id, SyncPriority.normal);
        }
      }
    }
  }

  Future<void> cleanupOldItems() async {
    final items = await database.syncQueueDao.getFailedItems();
    
    for (final item in items) {
      // Delete failed items older than 7 days
      if (DateTime.now().difference(item.createdAt).inDays > 7) {
        await database.syncQueueDao.deleteItem(item.id);
      }
    }
  }

  Future<QueueStatistics> getQueueStatistics() async {
    final status = await getQueueStatus();
    
    return QueueStatistics(
      totalItems: status.totalItems,
      pendingItems: status.pendingItems,
      syncingItems: status.syncingItems,
      failedItems: status.failedItems,
      averageWaitTime: status.averageWaitTime,
      oldestItemAge: status.oldestItemAge,
    );
  }

  Future<double> getSuccessRate() async {
    final successCount = prefs.getInt('sync_success_count') ?? 0;
    final totalCount = prefs.getInt('sync_total_count') ?? 0;
    
    if (totalCount == 0) return 0.0;
    return successCount / totalCount;
  }

  Future<bool> hasItemsToSync() async {
    final items = await database.syncQueueDao.getPendingItems();
    return items.isNotEmpty;
  }

  void onQueueEmpty(Function callback) {
    _onQueueEmpty = callback;
  }

  void onProcessingComplete(Function(ProcessingResult) callback) {
    _onProcessingComplete = callback;
  }

  void dispose() {
    _stateController.close();
  }
}

class _ProcessingLock {
  bool _isProcessing = false;

  Future<bool> acquire() async {
    if (_isProcessing) {
      return false;
    }
    _isProcessing = true;
    return true;
  }

  void release() {
    _isProcessing = false;
  }
}

// Custom exceptions for queue manager
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}