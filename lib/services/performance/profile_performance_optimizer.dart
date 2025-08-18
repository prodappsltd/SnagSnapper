import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';

/// Performance optimizer for Profile module
/// Implements caching, query optimization, and memory management
class ProfilePerformanceOptimizer {
  static ProfilePerformanceOptimizer? _instance;
  
  ProfilePerformanceOptimizer._();
  
  static ProfilePerformanceOptimizer get instance {
    _instance ??= ProfilePerformanceOptimizer._();
    return _instance!;
  }

  // Cache for profile data
  final Map<String, AppUser> _profileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // Debounce timers for write operations
  final Map<String, Timer> _writeDebounceTimers = {};
  static const Duration _writeDebounceDelay = Duration(milliseconds: 500);
  
  // Performance metrics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _dbQueries = 0;
  int _dbWrites = 0;
  DateTime? _lastCleanup;

  /// Get performance metrics
  Map<String, dynamic> getMetrics() {
    final hitRate = _cacheHits + _cacheMisses > 0 
        ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(2)
        : '0.00';
    
    return {
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'cacheHitRate': '$hitRate%',
      'dbQueries': _dbQueries,
      'dbWrites': _dbWrites,
      'cacheSize': _profileCache.length,
      'lastCleanup': _lastCleanup?.toIso8601String() ?? 'Never',
    };
  }

  /// Get profile with caching
  Future<AppUser?> getCachedProfile(
    String userId,
    AppDatabase database,
  ) async {
    // Check cache first
    if (_profileCache.containsKey(userId)) {
      final timestamp = _cacheTimestamps[userId];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        _cacheHits++;
        if (kDebugMode) {
          print('Cache hit for user: $userId');
        }
        return _profileCache[userId];
      }
    }
    
    // Cache miss - fetch from database
    _cacheMisses++;
    _dbQueries++;
    
    final profile = await database.profileDao.getProfile(userId);
    
    if (profile != null) {
      _profileCache[userId] = profile;
      _cacheTimestamps[userId] = DateTime.now();
    }
    
    // Cleanup old cache entries
    _cleanupCacheIfNeeded();
    
    return profile;
  }

  /// Update profile with debouncing
  Future<bool> updateProfileDebounced(
    String userId,
    AppUser profile,
    AppDatabase database,
  ) async {
    // Cancel existing timer if any
    _writeDebounceTimers[userId]?.cancel();
    
    // Update cache immediately for UI responsiveness
    _profileCache[userId] = profile;
    _cacheTimestamps[userId] = DateTime.now();
    
    // Debounce the actual database write
    final completer = Completer<bool>();
    
    _writeDebounceTimers[userId] = Timer(_writeDebounceDelay, () async {
      try {
        _dbWrites++;
        final success = await database.profileDao.updateProfile(userId, profile);
        completer.complete(success);
        
        if (kDebugMode) {
          print('Profile updated after debounce: $userId');
        }
      } catch (e) {
        completer.completeError(e);
      }
    });
    
    return completer.future;
  }

  /// Batch update multiple fields
  Future<bool> batchUpdateProfile(
    String userId,
    Map<String, dynamic> updates,
    AppDatabase database,
  ) async {
    try {
      // Get current profile
      final currentProfile = await getCachedProfile(userId, database);
      if (currentProfile == null) return false;
      
      // Apply updates
      final updatedProfile = currentProfile.copyWith(
        name: updates['name'] ?? currentProfile.name,
        email: updates['email'] ?? currentProfile.email,
        company: updates['company'] ?? currentProfile.company,
        role: updates['role'] ?? currentProfile.role,
        phoneNumber: updates['phoneNumber'] ?? currentProfile.phoneNumber,
        dateFormat: updates['dateFormat'] ?? currentProfile.dateFormat,
        profileImagePath: updates['profileImagePath'] ?? currentProfile.profileImagePath,
        signaturePath: updates['signaturePath'] ?? currentProfile.signaturePath,
        modifiedAt: DateTime.now(),
        localVersion: currentProfile.localVersion + 1,
        needsProfileSync: true,
      );
      
      // Update with debouncing
      return await updateProfileDebounced(userId, updatedProfile, database);
    } catch (e) {
      if (kDebugMode) {
        print('Error in batch update: $e');
      }
      return false;
    }
  }

  /// Preload profiles for better performance
  Future<void> preloadProfiles(
    List<String> userIds,
    AppDatabase database,
  ) async {
    final futures = userIds.map((userId) => 
      getCachedProfile(userId, database)
    );
    
    await Future.wait(futures);
    
    if (kDebugMode) {
      print('Preloaded ${userIds.length} profiles');
    }
  }

  /// Clear cache for a specific user
  void invalidateCache(String userId) {
    _profileCache.remove(userId);
    _cacheTimestamps.remove(userId);
    
    if (kDebugMode) {
      print('Cache invalidated for user: $userId');
    }
  }

  /// Clear all cache
  void clearAllCache() {
    _profileCache.clear();
    _cacheTimestamps.clear();
    _writeDebounceTimers.forEach((_, timer) => timer.cancel());
    _writeDebounceTimers.clear();
    
    if (kDebugMode) {
      print('All cache cleared');
    }
  }

  /// Cleanup old cache entries
  void _cleanupCacheIfNeeded() {
    final now = DateTime.now();
    
    // Run cleanup every 10 minutes
    if (_lastCleanup != null && 
        now.difference(_lastCleanup!) < Duration(minutes: 10)) {
      return;
    }
    
    _lastCleanup = now;
    
    // Remove expired entries
    final keysToRemove = <String>[];
    _cacheTimestamps.forEach((userId, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        keysToRemove.add(userId);
      }
    });
    
    for (final key in keysToRemove) {
      _profileCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    if (kDebugMode && keysToRemove.isNotEmpty) {
      print('Cleaned up ${keysToRemove.length} expired cache entries');
    }
  }

  /// Optimize database queries with indexing hints
  Future<List<AppUser>> getProfilesOptimized(
    AppDatabase database, {
    int limit = 50,
    int offset = 0,
  }) async {
    _dbQueries++;
    
    // Use indexed query for better performance
    final profiles = await database.customSelect(
      'SELECT * FROM app_users '
      'ORDER BY modified_at DESC '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {database.appUsers},
    ).map((row) => AppUser(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      email: row.read<String?>('email'),
      company: row.read<String?>('company'),
      role: row.read<String?>('role'),
      phoneNumber: row.read<String?>('phone_number'),
      dateFormat: row.read<String?>('date_format'),
      profileImagePath: row.read<String?>('profile_image_path'),
      signaturePath: row.read<String?>('signature_path'),
      createdAt: row.read<DateTime>('created_at'),
      modifiedAt: row.read<DateTime>('modified_at'),
      lastSyncTime: row.read<DateTime?>('last_sync_time'),
      needsProfileSync: row.read<bool>('needs_profile_sync'),
      needsImageSync: row.read<bool>('needs_image_sync'),
      needsSignatureSync: row.read<bool>('needs_signature_sync'),
      localVersion: row.read<int>('local_version'),
      firebaseVersion: row.read<int>('firebase_version'),
      deviceId: row.read<String?>('device_id'),
    )).get();
    
    // Cache the results
    for (final profile in profiles) {
      _profileCache[profile.id] = profile;
      _cacheTimestamps[profile.id] = DateTime.now();
    }
    
    return profiles;
  }

  /// Monitor memory usage
  void monitorMemoryUsage() {
    if (!kDebugMode) return;
    
    // Calculate approximate memory usage
    int approximateBytes = 0;
    
    _profileCache.forEach((_, profile) {
      // Estimate ~1KB per profile
      approximateBytes += 1024;
      
      // Add extra for image paths
      if (profile.profileImagePath != null) {
        approximateBytes += profile.profileImagePath!.length * 2;
      }
      if (profile.signaturePath != null) {
        approximateBytes += profile.signaturePath!.length * 2;
      }
    });
    
    final mbUsed = (approximateBytes / 1024 / 1024).toStringAsFixed(2);
    print('Profile cache memory usage: ~$mbUsed MB');
    
    // Clear cache if using too much memory (>10MB)
    if (approximateBytes > 10 * 1024 * 1024) {
      print('Memory limit exceeded, clearing cache');
      clearAllCache();
    }
  }

  /// Dispose resources
  void dispose() {
    clearAllCache();
    _instance = null;
  }
}

/// Extension for optimized profile operations
extension ProfileOptimizationExtension on AppDatabase {
  /// Get profile with optimization
  Future<AppUser?> getProfileOptimized(String userId) {
    return ProfilePerformanceOptimizer.instance.getCachedProfile(
      userId,
      this,
    );
  }
  
  /// Update profile with optimization
  Future<bool> updateProfileOptimized(String userId, AppUser profile) {
    return ProfilePerformanceOptimizer.instance.updateProfileDebounced(
      userId,
      profile,
      this,
    );
  }
  
  /// Batch update with optimization
  Future<bool> batchUpdateProfileOptimized(
    String userId,
    Map<String, dynamic> updates,
  ) {
    return ProfilePerformanceOptimizer.instance.batchUpdateProfile(
      userId,
      updates,
      this,
    );
  }
}