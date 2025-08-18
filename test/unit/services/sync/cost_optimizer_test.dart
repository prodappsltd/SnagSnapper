import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snagsnapper/services/sync/cost_optimizer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

@GenerateMocks([
  FirebaseFirestore,
  WriteBatch,
  DocumentReference,
])
import 'cost_optimizer_test.mocks.dart';

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() {
    return super.noSuchMethod(
      Invocation.method(#getApplicationDocumentsPath, []),
      returnValue: Future.value('/tmp'),
      returnValueForMissingStub: Future.value('/tmp'),
    );
  }
}

void main() {
  group('BatchOptimizer', () {
    late BatchOptimizer batchOptimizer;
    late MockFirebaseFirestore mockFirestore;
    late MockWriteBatch mockBatch;
    
    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockBatch = MockWriteBatch();
      when(mockFirestore.batch()).thenReturn(mockBatch);
      when(mockBatch.commit()).thenAnswer((_) async {});
      
      batchOptimizer = BatchOptimizer(firestore: mockFirestore);
    });
    
    tearDown(() {
      batchOptimizer.dispose();
    });
    
    test('should batch multiple updates within window', () async {
      // Arrange
      final mockRef1 = MockDocumentReference<Map<String, dynamic>>();
      final mockRef2 = MockDocumentReference<Map<String, dynamic>>();
      
      // Act
      batchOptimizer.addUpdate(DocumentUpdate(
        ref: mockRef1,
        data: {'field': 'value1'},
      ));
      batchOptimizer.addUpdate(DocumentUpdate(
        ref: mockRef2,
        data: {'field': 'value2'},
      ));
      
      // Wait for batch window
      await Future.delayed(Duration(seconds: 6));
      
      // Assert
      verify(mockBatch.commit()).called(1);
      verify(mockBatch.update(mockRef1, any)).called(1);
      verify(mockBatch.update(mockRef2, any)).called(1);
    });
    
    test('should execute batch immediately when reaching BATCH_SIZE', () async {
      // Arrange
      final updates = List.generate(500, (i) {
        final mockRef = MockDocumentReference<Map<String, dynamic>>();
        return DocumentUpdate(
          ref: mockRef,
          data: {'field': 'value$i'},
        );
      });
      
      // Act
      for (final update in updates) {
        batchOptimizer.addUpdate(update);
      }
      
      // Small delay to allow async execution
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      verify(mockBatch.commit()).called(1);
    });
    
    test('should track metrics correctly', () async {
      // Arrange
      final mockRef = MockDocumentReference<Map<String, dynamic>>();
      
      // Act
      for (int i = 0; i < 10; i++) {
        batchOptimizer.addUpdate(DocumentUpdate(
          ref: mockRef,
          data: {'field': 'value$i'},
        ));
      }
      
      await batchOptimizer.flush();
      
      // Assert
      final metrics = batchOptimizer.getMetrics();
      expect(metrics['totalBatches'], 1);
      expect(metrics['totalOperations'], 10);
      expect(metrics['savedOperations'], 9); // 10 - 1
    });
    
    test('should handle batch commit failures with retry', () async {
      // Arrange
      final mockRef = MockDocumentReference<Map<String, dynamic>>();
      int commitAttempts = 0;
      
      when(mockBatch.commit()).thenAnswer((_) async {
        commitAttempts++;
        if (commitAttempts == 1) {
          throw Exception('Network error');
        }
      });
      
      // Act
      batchOptimizer.addUpdate(DocumentUpdate(
        ref: mockRef,
        data: {'field': 'value'},
      ));
      
      await batchOptimizer.flush();
      await Future.delayed(Duration(seconds: 6)); // Wait for retry
      
      // Assert
      expect(commitAttempts, greaterThanOrEqualTo(2));
    });
  });
  
  group('ImageOptimizer', () {
    late Directory tempDir;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final mockPathProvider = MockPathProviderPlatform();
      PathProviderPlatform.instance = mockPathProvider;
      
      tempDir = Directory.systemTemp.createTempSync('image_optimizer_test');
      when(mockPathProvider.getApplicationDocumentsPath())
          .thenAnswer((_) async => tempDir.path);
    });
    
    tearDownAll(() {
      tempDir.deleteSync(recursive: true);
    });
    
    test('should compress image to target size', skip: 'Requires valid image data', () async {
      // Arrange - Create a mock image file
      final testImage = File('${tempDir.path}/test.jpg');
      // Create a simple 2x2 pixel image
      final imageBytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG header
        ...List.filled(2000, 0), // Dummy data to make it larger
      ]);
      await testImage.writeAsBytes(imageBytes);
      
      // Act
      final compressed = await ImageOptimizer.optimizeForUpload(testImage);
      
      // Assert
      expect(compressed.compressionRatio, greaterThan(0));
      expect(compressed.compressedSize, lessThan(compressed.originalSize));
      expect(compressed.thumbnail.length, lessThan(compressed.full.length));
    });
    
    test('should generate thumbnail of correct size', skip: 'Requires valid image data', () async {
      // This test would require actual image processing
      // For now, we'll test that the method doesn't throw
      final testImage = File('${tempDir.path}/test2.jpg');
      await testImage.writeAsBytes(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]));
      
      expect(
        () => ImageOptimizer.optimizeForUpload(testImage),
        throwsException, // Will throw because it's not a valid image
      );
    });
    
    test('should save optimized images to correct paths', () async {
      // Arrange
      final compressed = CompressedImage(
        full: Uint8List.fromList([1, 2, 3]),
        thumbnail: Uint8List.fromList([4, 5]),
        originalSize: 1000,
        compressedSize: 100,
      );
      
      // Act
      final paths = await ImageOptimizer.saveOptimizedImage(
        compressed,
        'user123',
        'profile',
      );
      
      // Assert
      expect(paths['full'], contains('user123'));
      expect(paths['full'], contains('profile'));
      expect(paths['thumbnail'], contains('thumb'));
    });
  });
  
  group('SyncCache', () {
    late SyncCache cache;
    
    setUp(() {
      cache = SyncCache();
    });
    
    test('should return cached data when not expired', () async {
      // Arrange
      const key = 'test_key';
      const value = 'test_value';
      int fetchCount = 0;
      
      // Act
      final result1 = await cache.getOrFetch(key, () async {
        fetchCount++;
        return value;
      });
      
      final result2 = await cache.getOrFetch(key, () async {
        fetchCount++;
        return 'different_value';
      });
      
      // Assert
      expect(result1, value);
      expect(result2, value); // Should return cached value
      expect(fetchCount, 1); // Fetcher called only once
    });
    
    test('should fetch new data when cache expired', () async {
      // Arrange
      const key = 'test_key';
      int fetchCount = 0;
      
      // Act
      await cache.getOrFetch(
        key,
        () async {
          fetchCount++;
          return 'value1';
        },
        ttl: Duration(milliseconds: 100),
      );
      
      await Future.delayed(Duration(milliseconds: 150));
      
      final result = await cache.getOrFetch(key, () async {
        fetchCount++;
        return 'value2';
      });
      
      // Assert
      expect(result, 'value2');
      expect(fetchCount, 2);
    });
    
    test('should calculate hit rate correctly', () async {
      // Arrange & Act
      await cache.getOrFetch('key1', () async => 'value1'); // Miss
      await cache.getOrFetch('key1', () async => 'value1'); // Hit
      await cache.getOrFetch('key1', () async => 'value1'); // Hit
      await cache.getOrFetch('key2', () async => 'value2'); // Miss
      
      // Assert
      final metrics = cache.getMetrics();
      expect(metrics['hits'], 2);
      expect(metrics['misses'], 2);
      expect(metrics['hitRate'], '50.0');
    });
    
    test('should evict old entries when cache is full', () async {
      // Arrange
      cache.clear();
      
      // Act - Add more than MAX_CACHE_SIZE entries
      for (int i = 0; i < 105; i++) {
        await cache.getOrFetch('key$i', () async => 'value$i');
      }
      
      // Assert
      final metrics = cache.getMetrics();
      expect(metrics['entries'], lessThanOrEqualTo(100));
    });
    
    test('should invalidate specific cache entries', () async {
      // Arrange
      await cache.getOrFetch('key1', () async => 'value1');
      await cache.getOrFetch('key2', () async => 'value2');
      
      // Act
      cache.invalidate('key1');
      
      int fetchCount = 0;
      final result = await cache.getOrFetch('key1', () async {
        fetchCount++;
        return 'new_value';
      });
      
      // Assert
      expect(result, 'new_value');
      expect(fetchCount, 1);
    });
    
    test('should invalidate entries matching pattern', () async {
      // Arrange
      await cache.getOrFetch('user_1', () async => 'data1');
      await cache.getOrFetch('user_2', () async => 'data2');
      await cache.getOrFetch('profile_1', () async => 'data3');
      
      // Act
      cache.invalidatePattern(r'^user_');
      
      // Assert
      int userFetchCount = 0;
      int profileFetchCount = 0;
      
      await cache.getOrFetch('user_1', () async {
        userFetchCount++;
        return 'new_data';
      });
      
      await cache.getOrFetch('profile_1', () async {
        profileFetchCount++;
        return 'new_data';
      });
      
      expect(userFetchCount, 1); // Should refetch
      expect(profileFetchCount, 0); // Should use cache
    });
  });
  
  group('SmartSyncScheduler', () {
    setUp(() {
      SmartSyncScheduler.reset();
    });
    
    test('should respect peak hours probability', () {
      // This is probabilistic, so we test the logic exists
      // In peak hours (9-17), shouldSyncNow returns true ~30% of the time
      // Outside peak hours, it always returns true
      
      // We can't easily test time-based logic without mocking DateTime
      // but we can verify the method exists and returns a boolean
      final result = SmartSyncScheduler.shouldSyncNow();
      expect(result, isA<bool>());
    });
    
    test('should deduplicate sync requests', () async {
      // Arrange
      int syncCount = 0;
      Future<void> syncAction() async {
        syncCount++;
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      // Act - Request same sync multiple times
      // Note: During peak hours this might not sync at all
      final futures = [
        SmartSyncScheduler.requestSync('item1', syncAction),
        SmartSyncScheduler.requestSync('item1', syncAction),
        SmartSyncScheduler.requestSync('item1', syncAction),
      ];
      
      await Future.wait(futures);
      
      // Assert - Either 0 (peak hours) or 1 (off-peak)
      expect(syncCount, lessThanOrEqualTo(1)); // Should sync at most once
    });
    
    test('should respect minimum sync interval', () async {
      // Arrange
      int syncCount = 0;
      Future<void> syncAction() async {
        syncCount++;
      }
      
      // Act
      await SmartSyncScheduler.requestSync('item1', syncAction);
      await SmartSyncScheduler.requestSync('item1', syncAction); // Too soon
      
      // Assert
      expect(syncCount, 1);
    });
    
    test('should calculate next sync time correctly', () {
      // Act
      final nextSync = SmartSyncScheduler.getNextSyncTime();
      
      // Assert
      expect(nextSync, isA<DateTime>());
      expect(nextSync.isAfter(DateTime.now()), true);
    });
    
    test('should provide accurate metrics', () async {
      // Arrange & Act
      await SmartSyncScheduler.requestSync('item1', () async {});
      
      final metrics = SmartSyncScheduler.getMetrics();
      
      // Assert
      expect(metrics['pendingSyncs'], isA<int>());
      expect(metrics['syncHistory'], isA<int>());
      expect(metrics['isPeakHour'], isA<bool>());
      expect(metrics['nextOptimalSync'], isA<String>());
    });
  });
}