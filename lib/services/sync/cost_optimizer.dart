import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Document update for batching
class DocumentUpdate {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  DocumentUpdate({
    required this.ref,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Compressed image result
class CompressedImage {
  final Uint8List full;
  final Uint8List thumbnail;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;

  CompressedImage({
    required this.full,
    required this.thumbnail,
    required this.originalSize,
    required this.compressedSize,
  }) : compressionRatio = 1 - (compressedSize / originalSize);
}

/// Cached data wrapper
class CachedData {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  CachedData({
    required this.data,
    required this.timestamp,
    this.ttl = const Duration(minutes: 5),
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Batch optimizer for Firestore operations
/// Reduces write costs by batching multiple operations
class BatchOptimizer {
  static const int BATCH_SIZE = 500; // Firestore limit
  static const Duration BATCH_WINDOW = Duration(seconds: 5);
  
  final List<DocumentUpdate> _pendingUpdates = [];
  Timer? _batchTimer;
  final FirebaseFirestore _firestore;
  
  // Metrics
  int _totalBatches = 0;
  int _totalOperations = 0;
  int _savedOperations = 0;
  
  BatchOptimizer({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  
  /// Add an update to the batch queue
  void addUpdate(DocumentUpdate update) {
    _pendingUpdates.add(update);
    
    if (_pendingUpdates.length >= BATCH_SIZE) {
      _executeBatch();
    } else {
      _scheduleBatch();
    }
  }
  
  /// Schedule batch execution
  void _scheduleBatch() {
    _batchTimer?.cancel();
    _batchTimer = Timer(BATCH_WINDOW, _executeBatch);
  }
  
  /// Execute the batch
  Future<void> _executeBatch() async {
    if (_pendingUpdates.isEmpty) return;
    
    final batch = _firestore.batch();
    final updates = List<DocumentUpdate>.from(_pendingUpdates);
    _pendingUpdates.clear();
    
    for (final update in updates) {
      batch.update(update.ref, {
        ...update.data,
        'batchedAt': FieldValue.serverTimestamp(),
      });
    }
    
    try {
      await batch.commit();
      _totalBatches++;
      _totalOperations += updates.length;
      _savedOperations += updates.length - 1; // Saved by batching
      
      if (kDebugMode) {
        print('Batch committed: ${updates.length} operations');
        print('Total savings: $_savedOperations operations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Batch commit failed: $e');
      }
      // Re-add failed updates for retry
      _pendingUpdates.addAll(updates);
      _scheduleBatch();
    }
  }
  
  /// Force execute pending batch
  Future<void> flush() async {
    _batchTimer?.cancel();
    await _executeBatch();
  }
  
  /// Get optimization metrics
  Map<String, dynamic> getMetrics() {
    return {
      'totalBatches': _totalBatches,
      'totalOperations': _totalOperations,
      'savedOperations': _savedOperations,
      'savingsPercentage': _totalOperations > 0
          ? (_savedOperations / _totalOperations * 100).toStringAsFixed(1)
          : '0.0',
    };
  }
  
  void dispose() {
    _batchTimer?.cancel();
    flush();
  }
}

/// Image optimizer for reducing storage and bandwidth costs
class ImageOptimizer {
  static const int MAX_WIDTH = 1024;
  static const int MAX_HEIGHT = 1024;
  static const int QUALITY = 85;
  static const int THUMBNAIL_SIZE = 150;
  static const int THUMBNAIL_QUALITY = 70;
  
  /// Optimize image for upload with compression and thumbnail generation
  static Future<CompressedImage> optimizeForUpload(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalSize = bytes.length;
    
    // Decode image
    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Failed to decode image');
    }
    
    // Generate thumbnail for list views
    final thumbnail = img.copyResize(
      original,
      width: THUMBNAIL_SIZE,
      height: THUMBNAIL_SIZE,
      interpolation: img.Interpolation.linear,
    );
    
    // Resize main image if needed
    img.Image resized;
    if (original.width > MAX_WIDTH || original.height > MAX_HEIGHT) {
      final aspectRatio = original.width / original.height;
      int newWidth, newHeight;
      
      if (aspectRatio > 1) {
        // Landscape
        newWidth = MAX_WIDTH;
        newHeight = (MAX_WIDTH / aspectRatio).round();
      } else {
        // Portrait or square
        newHeight = MAX_HEIGHT;
        newWidth = (MAX_HEIGHT * aspectRatio).round();
      }
      
      resized = img.copyResize(
        original,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
    } else {
      resized = original;
    }
    
    // Compress images
    final fullBytes = img.encodeJpg(resized, quality: QUALITY);
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: THUMBNAIL_QUALITY);
    
    if (kDebugMode) {
      final savings = ((1 - (fullBytes.length / originalSize)) * 100).toStringAsFixed(1);
      print('Image optimized: ${originalSize ~/ 1024}KB -> ${fullBytes.length ~/ 1024}KB ($savings% reduction)');
    }
    
    return CompressedImage(
      full: fullBytes,
      thumbnail: thumbnailBytes,
      originalSize: originalSize,
      compressedSize: fullBytes.length,
    );
  }
  
  /// Save optimized image to local storage
  static Future<Map<String, String>> saveOptimizedImage(
    CompressedImage compressed,
    String userId,
    String type, // 'profile' or 'signature'
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final userDir = Directory(p.join(appDir.path, 'SnagSnapper', userId, 'Profile'));
    
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fullPath = p.join(userDir.path, '${type}_$timestamp.jpg');
    final thumbPath = p.join(userDir.path, '${type}_thumb_$timestamp.jpg');
    
    // Save files
    await File(fullPath).writeAsBytes(compressed.full);
    await File(thumbPath).writeAsBytes(compressed.thumbnail);
    
    // Return relative paths
    return {
      'full': 'SnagSnapper/$userId/Profile/${type}_$timestamp.jpg',
      'thumbnail': 'SnagSnapper/$userId/Profile/${type}_thumb_$timestamp.jpg',
    };
  }
}

/// Smart cache for reducing Firestore reads
class SyncCache {
  static const Duration CACHE_DURATION = Duration(minutes: 5);
  static const int MAX_CACHE_SIZE = 100; // Maximum cache entries
  
  final Map<String, CachedData> _cache = {};
  int _hits = 0;
  int _misses = 0;
  
  /// Get data from cache or fetch if not available
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    // Check cache
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      _hits++;
      if (kDebugMode) {
        print('Cache hit: $key (hit rate: ${getHitRate()}%)');
      }
      return cached.data as T;
    }
    
    // Cache miss - fetch data
    _misses++;
    final data = await fetcher();
    
    // Store in cache
    _cache[key] = CachedData(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? CACHE_DURATION,
    );
    
    // Evict old entries if cache is too large
    _evictOldEntries();
    
    return data;
  }
  
  /// Invalidate cache entry
  void invalidate(String key) {
    _cache.remove(key);
  }
  
  /// Invalidate entries matching pattern
  void invalidatePattern(String pattern) {
    final regex = RegExp(pattern);
    _cache.removeWhere((key, _) => regex.hasMatch(key));
  }
  
  /// Clear entire cache
  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }
  
  /// Evict old entries when cache is too large
  void _evictOldEntries() {
    if (_cache.length <= MAX_CACHE_SIZE) return;
    
    // Sort entries by timestamp and remove oldest
    final entries = _cache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    
    final toRemove = entries.take(_cache.length - MAX_CACHE_SIZE);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }
  }
  
  /// Get cache hit rate
  String getHitRate() {
    final total = _hits + _misses;
    if (total == 0) return '0.0';
    return ((_hits / total) * 100).toStringAsFixed(1);
  }
  
  /// Get cache metrics
  Map<String, dynamic> getMetrics() {
    return {
      'entries': _cache.length,
      'hits': _hits,
      'misses': _misses,
      'hitRate': getHitRate(),
      'maxSize': MAX_CACHE_SIZE,
    };
  }
}

/// Smart sync scheduler for optimizing sync timing
class SmartSyncScheduler {
  static const List<int> PEAK_HOURS = [9, 10, 11, 12, 13, 14, 15, 16, 17];
  static const double PEAK_HOUR_PROBABILITY = 0.3;
  
  // Track pending syncs to prevent duplicates
  static final Set<String> _pendingSyncs = {};
  static final Map<String, DateTime> _lastSyncTime = {};
  static const Duration MIN_SYNC_INTERVAL = Duration(minutes: 5);
  
  /// Check if sync should happen now based on time and load
  static bool shouldSyncNow({bool force = false}) {
    if (force) return true;
    
    final hour = DateTime.now().hour;
    
    // During peak hours, reduce sync frequency
    if (PEAK_HOURS.contains(hour)) {
      return Random().nextDouble() < PEAK_HOUR_PROBABILITY;
    }
    
    // Off-peak hours - always sync
    return true;
  }
  
  /// Request sync for an item (deduplicated)
  static Future<bool> requestSync(
    String itemId,
    Future<void> Function() syncAction,
  ) async {
    // Check if already pending
    if (_pendingSyncs.contains(itemId)) {
      if (kDebugMode) {
        print('Sync already pending for: $itemId');
      }
      return false;
    }
    
    // Check minimum interval
    final lastSync = _lastSyncTime[itemId];
    if (lastSync != null) {
      final timeSinceLastSync = DateTime.now().difference(lastSync);
      if (timeSinceLastSync < MIN_SYNC_INTERVAL) {
        if (kDebugMode) {
          final remaining = MIN_SYNC_INTERVAL - timeSinceLastSync;
          print('Sync throttled for $itemId. Try again in ${remaining.inSeconds}s');
        }
        return false;
      }
    }
    
    // Check if we should sync now
    if (!shouldSyncNow()) {
      if (kDebugMode) {
        print('Sync deferred (peak hours): $itemId');
      }
      return false;
    }
    
    // Perform sync
    _pendingSyncs.add(itemId);
    try {
      await syncAction();
      _lastSyncTime[itemId] = DateTime.now();
      return true;
    } finally {
      _pendingSyncs.remove(itemId);
    }
  }
  
  /// Get next optimal sync time
  static DateTime getNextSyncTime() {
    final now = DateTime.now();
    final currentHour = now.hour;
    
    // If in peak hours, schedule for next off-peak
    if (PEAK_HOURS.contains(currentHour)) {
      final nextOffPeakHour = PEAK_HOURS.last + 1;
      return DateTime(now.year, now.month, now.day, nextOffPeakHour);
    }
    
    // If off-peak, sync soon
    return now.add(Duration(minutes: 15));
  }
  
  /// Get scheduler metrics
  static Map<String, dynamic> getMetrics() {
    return {
      'pendingSyncs': _pendingSyncs.length,
      'syncHistory': _lastSyncTime.length,
      'isPeakHour': PEAK_HOURS.contains(DateTime.now().hour),
      'nextOptimalSync': getNextSyncTime().toIso8601String(),
    };
  }
  
  /// Clear pending syncs (for testing)
  static void reset() {
    _pendingSyncs.clear();
    _lastSyncTime.clear();
  }
}