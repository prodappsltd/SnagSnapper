import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:snagsnapper/services/sync/queue_manager.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/sync_queue_dao.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';
import 'package:snagsnapper/services/sync/network_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

@GenerateMocks([
  AppDatabase,
  SyncQueueDao,
  ProfileSyncHandler,
  NetworkMonitor,
  SharedPreferences,
])
import 'queue_manager_test.mocks.dart';

void main() {
  group('SyncQueueManager', () {
    late SyncQueueManager queueManager;
    late MockAppDatabase mockDatabase;
    late MockSyncQueueDao mockQueueDao;
    late MockProfileSyncHandler mockProfileHandler;
    late MockNetworkMonitor mockNetworkMonitor;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockDatabase = MockAppDatabase();
      mockQueueDao = MockSyncQueueDao();
      mockProfileHandler = MockProfileSyncHandler();
      mockNetworkMonitor = MockNetworkMonitor();
      mockPrefs = MockSharedPreferences();

      when(mockDatabase.syncQueueDao).thenReturn(mockQueueDao);

      queueManager = SyncQueueManager(
        database: mockDatabase,
        profileHandler: mockProfileHandler,
        networkMonitor: mockNetworkMonitor,
        prefs: mockPrefs,
      );
    });

    group('Queue Operations', () {
      test('should add items to queue', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          data: {'name': 'Test User'},
          priority: SyncPriority.normal,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.insertItem(any)).thenAnswer((_) async => 1);
        when(mockPrefs.setBool('has_pending_sync', true))
            .thenAnswer((_) async => true);

        final success = await queueManager.addToQueue(item);

        expect(success, isTrue);
        verify(mockQueueDao.insertItem(item)).called(1);
        verify(mockPrefs.setBool('has_pending_sync', true)).called(1);
      });

      test('should add high priority items to front', () async {
        final highPriorityItem = SyncQueueItem(
          id: 'queue_high',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          priority: SyncPriority.high,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.insertItem(any)).thenAnswer((_) async => 1);
        when(mockPrefs.setBool('has_pending_sync', true))
            .thenAnswer((_) async => true);

        await queueManager.addToQueue(highPriorityItem);

        verify(mockQueueDao.insertItem(
          argThat(predicate<SyncQueueItem>((item) =>
            item.priority == SyncPriority.high
          ))
        )).called(1);
      });

      test('should prevent duplicate items', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getItemById('queue_1'))
            .thenAnswer((_) async => item);

        final success = await queueManager.addToQueue(item);

        expect(success, isFalse);
        verifyNever(mockQueueDao.insertItem(any));
      });

      test('should batch similar operations', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => items);

        final batches = await queueManager.getBatches();

        expect(batches.length, equals(1)); // Should batch similar operations
        expect(batches.first.items.length, equals(2));
      });

      test('should remove completed items', () async {
        final itemId = 'queue_1';
        when(mockQueueDao.deleteItem(itemId))
            .thenAnswer((_) async => true);
        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => []);
        when(mockPrefs.setBool('has_pending_sync', false))
            .thenAnswer((_) async => true);

        final success = await queueManager.removeFromQueue(itemId);

        expect(success, isTrue);
        verify(mockQueueDao.deleteItem(itemId)).called(1);
        verify(mockPrefs.setBool('has_pending_sync', false)).called(1);
      });

      test('should clear all items for user', () async {
        when(mockQueueDao.clearQueueForUser('test_user_id'))
            .thenAnswer((_) async => true);
        when(mockPrefs.setBool('has_pending_sync', false))
            .thenAnswer((_) async => true);

        await queueManager.clearQueue('test_user_id');

        verify(mockQueueDao.clearQueueForUser('test_user_id')).called(1);
        verify(mockPrefs.setBool('has_pending_sync', false)).called(1);
      });

      test('should get queue status', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.image,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => items);

        final status = await queueManager.getQueueStatus();

        expect(status.totalItems, equals(2));
        expect(status.profileItems, equals(1));
        expect(status.imageItems, equals(1));
        expect(status.isEmpty, isFalse);
      });
    });

    group('Queue Processing', () {
      test('should process queue items in order', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.high,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.normal,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => items);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenAnswer((_) async => true);
        when(mockQueueDao.deleteItem(any))
            .thenAnswer((_) async => true);

        await queueManager.processQueue();

        // Verify high priority processed first
        verifyInOrder([
          mockQueueDao.updateItemStatus('queue_1', SyncStatus.syncing),
          mockProfileHandler.syncProfileData('test_user_id'),
          mockQueueDao.deleteItem('queue_1'),
          mockQueueDao.updateItemStatus('queue_2', SyncStatus.syncing),
          mockProfileHandler.syncProfileData('test_user_id'),
          mockQueueDao.deleteItem('queue_2'),
        ]);
      });

      test('should handle processing errors', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          retryCount: 0,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenThrow(Exception('Sync failed'));

        await queueManager.processQueue();

        verify(mockQueueDao.updateItemRetry('queue_1', 1, any)).called(1);
        verifyNever(mockQueueDao.deleteItem('queue_1'));
      });

      test('should respect max retry attempts', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          retryCount: 3, // Already at max retries
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenThrow(Exception('Sync failed'));

        await queueManager.processQueue();

        // Should move to failed state after max retries
        verify(mockQueueDao.updateItemStatus('queue_1', SyncStatus.failed))
            .called(1);
        verifyNever(mockQueueDao.updateItemRetry(any, any, any));
      });

      test('should skip processing when offline', () async {
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => false);

        await queueManager.processQueue();

        verifyNever(mockQueueDao.getPendingItems());
        verifyNever(mockProfileHandler.syncProfileData(any));
      });

      test('should process only when queue has items', () async {
        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => []);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);

        await queueManager.processQueue();

        verifyNever(mockProfileHandler.syncProfileData(any));
      });

      test('should handle concurrent processing requests', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenAnswer((_) async {
              await Future.delayed(Duration(seconds: 2));
              return true;
            });

        // Start two concurrent processes
        final process1 = queueManager.processQueue();
        final process2 = queueManager.processQueue();

        await Future.wait([process1, process2]);

        // Should only process once due to lock
        verify(mockProfileHandler.syncProfileData(any)).called(1);
      });
    });

    group('Retry Logic', () {
      test('should implement exponential backoff', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          retryCount: 0,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenThrow(Exception('Sync failed'));

        await queueManager.processQueue();

        verify(mockQueueDao.updateItemRetry(
          'queue_1',
          1,
          argThat(predicate<DateTime>((nextRetry) =>
            nextRetry.isAfter(DateTime.now()) // Should set future retry time
          ))
        )).called(1);
      });

      test('should respect retry delay', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          retryCount: 1,
          nextRetryAt: DateTime.now().add(Duration(hours: 1)), // Not ready yet
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);

        await queueManager.processQueue();

        // Should skip item that's not ready for retry
        verifyNever(mockProfileHandler.syncProfileData(any));
      });

      test('should handle different error types', () async {
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          retryCount: 0,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);

        // Test network error - should retry
        when(mockProfileHandler.syncProfileData(any))
            .thenThrow(NetworkException('Connection failed'));
        
        await queueManager.processQueue();
        verify(mockQueueDao.updateItemRetry('queue_1', 1, any)).called(1);

        // Test permanent error - should fail immediately
        when(mockProfileHandler.syncProfileData(any))
            .thenThrow(ValidationException('Invalid data'));
        
        await queueManager.processQueue();
        verify(mockQueueDao.updateItemStatus('queue_1', SyncStatus.failed))
            .called(1);
      });

      test('should clear failed items after timeout', () async {
        final oldFailedItem = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          status: SyncStatus.failed,
          createdAt: DateTime.now().subtract(Duration(days: 8)), // Old item
        );

        when(mockQueueDao.getFailedItems())
            .thenAnswer((_) async => [oldFailedItem]);
        when(mockQueueDao.deleteItem('queue_1'))
            .thenAnswer((_) async => true);

        await queueManager.cleanupOldItems();

        verify(mockQueueDao.deleteItem('queue_1')).called(1);
      });
    });

    group('Priority Management', () {
      test('should process high priority first', () async {
        final items = [
          SyncQueueItem(
            id: 'normal_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.normal,
            createdAt: DateTime.now().subtract(Duration(hours: 2)),
          ),
          SyncQueueItem(
            id: 'high_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.high,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
          SyncQueueItem(
            id: 'low_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.low,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItemsByPriority())
            .thenAnswer((_) async => [items[1], items[0], items[2]]); // Sorted

        final sorted = await queueManager.getQueueByPriority();

        expect(sorted[0].id, equals('high_1'));
        expect(sorted[1].id, equals('normal_1'));
        expect(sorted[2].id, equals('low_1'));
      });

      test('should auto-promote old items', () async {
        final oldItem = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          priority: SyncPriority.low,
          createdAt: DateTime.now().subtract(Duration(days: 2)), // Old item
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [oldItem]);

        await queueManager.promoteOldItems();

        verify(mockQueueDao.updateItemPriority('queue_1', SyncPriority.normal))
            .called(1);
      });

      test('should handle priority conflicts', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.high,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            priority: SyncPriority.high,
            createdAt: DateTime.now().add(Duration(seconds: 1)),
          ),
        ];

        when(mockQueueDao.getPendingItemsByPriority())
            .thenAnswer((_) async => items);

        final sorted = await queueManager.getQueueByPriority();

        // Should maintain FIFO for same priority
        expect(sorted[0].id, equals('queue_1'));
        expect(sorted[1].id, equals('queue_2'));
      });
    });

    group('Batch Processing', () {
      test('should batch similar operations', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            data: {'field1': 'value1'},
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            data: {'field2': 'value2'},
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_3',
            userId: 'test_user_id',
            type: SyncType.image,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => items);

        final batches = await queueManager.getBatches();

        expect(batches.length, equals(2)); // Profile batch and image batch
        expect(batches[0].items.length, equals(2)); // Two profile items
        expect(batches[1].items.length, equals(1)); // One image item
      });

      test('should respect batch size limits', () async {
        final items = List.generate(25, (i) =>
          SyncQueueItem(
            id: 'queue_$i',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          )
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => items);

        final batches = await queueManager.getBatches(maxBatchSize: 10);

        expect(batches.length, equals(3)); // 10 + 10 + 5
        expect(batches[0].items.length, equals(10));
        expect(batches[1].items.length, equals(10));
        expect(batches[2].items.length, equals(5));
      });

      test('should process batch atomically', () async {
        final batch = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => batch);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncBatch(any))
            .thenAnswer((_) async => true);

        await queueManager.processBatch(batch);

        verify(mockProfileHandler.syncBatch(batch)).called(1);
        verify(mockQueueDao.deleteItems(['queue_1', 'queue_2'])).called(1);
      });

      test('should rollback batch on failure', () async {
        final batch = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            createdAt: DateTime.now(),
          ),
        ];

        when(mockProfileHandler.syncBatch(any))
            .thenThrow(Exception('Batch failed'));

        await queueManager.processBatch(batch);

        // Should not delete any items on failure
        verifyNever(mockQueueDao.deleteItem(any));
        verifyNever(mockQueueDao.deleteItems(any));
        
        // Should update retry count for all items
        verify(mockQueueDao.updateItemRetry('queue_1', any, any)).called(1);
        verify(mockQueueDao.updateItemRetry('queue_2', any, any)).called(1);
      });
    });

    group('Queue Statistics', () {
      test('should track queue metrics', () async {
        final items = [
          SyncQueueItem(
            id: 'queue_1',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.upload,
            status: SyncStatus.pending,
            createdAt: DateTime.now().subtract(Duration(minutes: 30)),
          ),
          SyncQueueItem(
            id: 'queue_2',
            userId: 'test_user_id',
            type: SyncType.image,
            action: SyncAction.upload,
            status: SyncStatus.syncing,
            createdAt: DateTime.now().subtract(Duration(minutes: 20)),
          ),
          SyncQueueItem(
            id: 'queue_3',
            userId: 'test_user_id',
            type: SyncType.profile,
            action: SyncAction.download,
            status: SyncStatus.failed,
            retryCount: 2,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        ];

        when(mockQueueDao.getAllItems())
            .thenAnswer((_) async => items);

        final stats = await queueManager.getQueueStatistics();

        expect(stats.totalItems, equals(3));
        expect(stats.pendingItems, equals(1));
        expect(stats.syncingItems, equals(1));
        expect(stats.failedItems, equals(1));
        expect(stats.averageWaitTime, isNotNull);
        expect(stats.oldestItemAge, isNotNull);
      });

      test('should calculate success rate', () async {
        when(mockPrefs.getInt('sync_success_count'))
            .thenReturn(45);
        when(mockPrefs.getInt('sync_total_count'))
            .thenReturn(50);

        final successRate = await queueManager.getSuccessRate();

        expect(successRate, equals(0.9)); // 45/50
      });

      test('should track processing time', () async {
        final startTime = DateTime.now();
        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenAnswer((_) async {
              await Future.delayed(Duration(seconds: 1));
              return true;
            });

        await queueManager.processQueue();

        final endTime = DateTime.now();
        final processingTime = endTime.difference(startTime);
        expect(processingTime.inMilliseconds, greaterThan(1000));
      });
    });

    group('Queue Event Handling', () {
      test('should emit queue state changes', () async {
        final stateChanges = <QueueState>[];
        queueManager.stateStream.listen(stateChanges.add);

        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.insertItem(any)).thenAnswer((_) async => 1);
        when(mockPrefs.setBool('has_pending_sync', true))
            .thenAnswer((_) async => true);

        await queueManager.addToQueue(item);
        await Future.delayed(Duration(milliseconds: 100));

        expect(stateChanges, contains(QueueState.hasItems));
      });

      test('should notify on queue empty', () async {
        final emptyNotifications = <bool>[];
        queueManager.onQueueEmpty(() {
          emptyNotifications.add(true);
        });

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => []);

        await queueManager.processQueue();

        expect(emptyNotifications, isNotEmpty);
      });

      test('should notify on processing complete', () async {
        final completeNotifications = <ProcessingResult>[];
        queueManager.onProcessingComplete((result) {
          completeNotifications.add(result);
        });

        final item = SyncQueueItem(
          id: 'queue_1',
          userId: 'test_user_id',
          type: SyncType.profile,
          action: SyncAction.upload,
          createdAt: DateTime.now(),
        );

        when(mockQueueDao.getPendingItems())
            .thenAnswer((_) async => [item]);
        when(mockNetworkMonitor.isOnline())
            .thenAnswer((_) async => true);
        when(mockProfileHandler.syncProfileData(any))
            .thenAnswer((_) async => true);
        when(mockQueueDao.deleteItem(any))
            .thenAnswer((_) async => true);

        await queueManager.processQueue();

        expect(completeNotifications, isNotEmpty);
        expect(completeNotifications.first.processed, equals(1));
        expect(completeNotifications.first.succeeded, equals(1));
      });
    });
  });
}

// Custom exceptions for testing
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}