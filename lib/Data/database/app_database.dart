import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/profile_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/sites_table.dart';
import 'daos/profile_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/site_dao.dart';

part 'app_database.g.dart';

/// Main database class for SnagSnapper offline-first architecture
/// Implements singleton pattern for database access
@DriftDatabase(
  tables: [Profiles, SyncQueueTable, Sites], 
  daos: [ProfileDao, SyncQueueDao, SiteDao]
)
class AppDatabase extends _$AppDatabase {
  // Singleton instance
  static AppDatabase? _instance;
  static final _lock = Object();

  // Private constructor
  AppDatabase._() : super(_openConnection());

  /// Get singleton instance of database
  static AppDatabase get instance {
    if (_instance == null) {
      // Use synchronization to ensure thread safety
      _instance = AppDatabase._();
    }
    return _instance!;
  }

  /// Alternative method for getting instance (for compatibility)
  static Future<AppDatabase> getInstance() async {
    return instance;
  }

  /// Database schema version
  /// Version 2: Added Sites table for site management
  @override
  int get schemaVersion => 2;

  /// Migration strategy for database upgrades
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // Create all tables
        await m.createAll();
        
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
        
        if (kDebugMode) {
          print('Database created with version $schemaVersion');
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations between versions
        if (from < 2) {
          // Migration from version 1 to 2: Add Sites table
          await m.create(sites);
          if (kDebugMode) {
            print('Added Sites table in migration to version 2');
          }
        }
        
        if (kDebugMode) {
          print('Database upgraded from version $from to $to');
        }
      },
      beforeOpen: (details) async {
        // Enable foreign keys on every open
        await customStatement('PRAGMA foreign_keys = ON');
        
        // Set journal mode to WAL for better performance
        await customStatement('PRAGMA journal_mode = WAL');
        
        // Set busy timeout to 5 seconds
        await customStatement('PRAGMA busy_timeout = 5000');
        
        if (kDebugMode) {
          print('Database opened, version: ${details.versionNow}');
        }
      },
    );
  }

  /// Check if database is open
  bool get isOpen => _instance != null;

  /// Close database and cleanup resources
  Future<void> closeDatabase() async {
    await close();
    _instance = null;
    
    if (kDebugMode) {
      print('Database closed');
    }
  }

  /// Create backup of database
  Future<bool> createBackup(String backupPath) async {
    try {
      final dbFile = File(await _getDatabasePath());
      if (await dbFile.exists()) {
        await dbFile.copy(backupPath);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating backup: $e');
      }
      return false;
    }
  }

  /// Handle database corruption
  static Future<bool> handleCorruption() async {
    try {
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        // Create backup of corrupted file for debugging
        final backupPath = '$dbPath.corrupted.${DateTime.now().millisecondsSinceEpoch}';
        await dbFile.copy(backupPath);
        
        // Delete corrupted database
        await dbFile.delete();
        
        if (kDebugMode) {
          print('Corrupted database backed up to: $backupPath');
        }
      }
      
      // Recreate database
      _instance = null;
      final newDb = AppDatabase.instance;
      
      // TODO: Restore from Firebase if available
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error handling corruption: $e');
      }
      return false;
    }
  }

  /// Get database file path
  static Future<String> _getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'snagsnapper.db');
  }

  /// Get database directory
  static Future<String> get databaseDirectory async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  /// Ensure database directory exists
  static Future<void> ensureDirectoryExists() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Get current database path
  Future<String> get databasePath => _getDatabasePath();

  /// Get database file size
  Future<int> get databaseSize async {
    final dbFile = File(await _getDatabasePath());
    if (await dbFile.exists()) {
      return await dbFile.length();
    }
    return 0;
  }

  /// Execute in transaction
  Future<T> inTransaction<T>(Future<T> Function() action) async {
    return transaction(() async {
      return await action();
    });
  }

  /// Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    await delete(profiles).go();
    // Add other tables when implemented
    
    if (kDebugMode) {
      print('All data cleared from database');
    }
  }

  /// Get table information (for testing)
  Future<List<Map<String, dynamic>>> getTableInfo(String tableName) async {
    final result = await customSelect(
      'PRAGMA table_info($tableName)',
      readsFrom: {},
    ).get();
    
    return result.map((row) => row.data).toList();
  }

  /// Check if profile exists
  Future<bool> profileExists(String userId) async {
    final query = select(profiles)..where((tbl) => tbl.id.equals(userId));
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Get profiles needing sync
  Future<List<ProfileEntry>> getProfilesNeedingSync() async {
    final query = select(profiles)
      ..where((tbl) => 
        tbl.needsProfileSync.equals(true) |
        tbl.needsImageSync.equals(true) |
        tbl.needsSignatureSync.equals(true)
      );
    return await query.get();
  }
}

/// Open database connection
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Ensure SQLite3 flutter libs are initialized
    if (Platform.isAndroid || Platform.isIOS) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Get database path
    final dbPath = await AppDatabase._getDatabasePath();
    
    // Ensure directory exists
    await AppDatabase.ensureDirectoryExists();
    
    final file = File(dbPath);
    
    if (kDebugMode) {
      print('Opening database at: $dbPath');
    }
    
    return NativeDatabase.createInBackground(file);
  });
}