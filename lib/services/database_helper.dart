import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/database/app_database.dart';

/// Helper service for database operations and utilities
/// Provides convenient methods for database management
class DatabaseHelper {
  /// Get the database file path
  /// Returns the full path to the database file
  static Future<String> getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'snagsnapper.db');
  }

  /// Get the database directory
  /// Returns the directory where database is stored
  static Future<String> getDatabaseDirectory() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  /// Check if database exists
  /// Returns true if database file exists, false otherwise
  static Future<bool> databaseExists() async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    return await dbFile.exists();
  }

  /// Get database file size in bytes
  /// Returns the size of the database file
  static Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    
    if (await dbFile.exists()) {
      return await dbFile.length();
    }
    
    return 0;
  }

  /// Get database size in human-readable format
  /// Returns formatted string like "1.5 MB"
  static Future<String> getDatabaseSizeFormatted() async {
    final sizeInBytes = await getDatabaseSize();
    
    if (sizeInBytes < 1024) {
      return '$sizeInBytes bytes';
    } else if (sizeInBytes < 1024 * 1024) {
      final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(2);
      return '$sizeInKB KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      final sizeInMB = (sizeInBytes / (1024 * 1024)).toStringAsFixed(2);
      return '$sizeInMB MB';
    } else {
      final sizeInGB = (sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$sizeInGB GB';
    }
  }

  /// Create a backup of the database
  /// Returns the path to the backup file if successful, null otherwise
  static Future<String?> createBackup({String? customName}) async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        if (kDebugMode) {
          print('DatabaseHelper: Database file does not exist');
        }
        return null;
      }
      
      // Generate backup file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupName = customName ?? 'backup_$timestamp.db';
      
      // Get backup directory (same as database directory)
      final backupDir = await getDatabaseDirectory();
      final backupPath = p.join(backupDir, 'backups', backupName);
      
      // Ensure backup directory exists
      final backupDirectory = Directory(p.join(backupDir, 'backups'));
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }
      
      // Copy database file to backup location
      await dbFile.copy(backupPath);
      
      if (kDebugMode) {
        print('DatabaseHelper: Backup created at $backupPath');
      }
      
      return backupPath;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error creating backup: $e');
      }
      return null;
    }
  }

  /// Restore database from backup
  /// Returns true if successful, false otherwise
  static Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      
      if (!await backupFile.exists()) {
        if (kDebugMode) {
          print('DatabaseHelper: Backup file does not exist');
        }
        return false;
      }
      
      // Close current database connection
      await AppDatabase.instance.closeDatabase();
      
      // Get database path
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      
      // Delete current database if exists
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      // Copy backup to database location
      await backupFile.copy(dbPath);
      
      if (kDebugMode) {
        print('DatabaseHelper: Database restored from $backupPath');
      }
      
      // Reinitialize database
      AppDatabase.instance;
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error restoring from backup: $e');
      }
      return false;
    }
  }

  /// List all available backups
  /// Returns list of backup file paths
  static Future<List<String>> listBackups() async {
    try {
      final backupDir = await getDatabaseDirectory();
      final backupDirectory = Directory(p.join(backupDir, 'backups'));
      
      if (!await backupDirectory.exists()) {
        return [];
      }
      
      final backups = <String>[];
      await for (final entity in backupDirectory.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          backups.add(entity.path);
        }
      }
      
      // Sort by modification time (newest first)
      backups.sort((a, b) {
        final aFile = File(a);
        final bFile = File(b);
        final aStat = aFile.statSync();
        final bStat = bFile.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      return backups;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error listing backups: $e');
      }
      return [];
    }
  }

  /// Delete old backups keeping only the most recent N backups
  /// Returns the number of backups deleted
  static Future<int> cleanupOldBackups({int keepCount = 5}) async {
    try {
      final backups = await listBackups();
      
      if (backups.length <= keepCount) {
        return 0; // Nothing to delete
      }
      
      int deletedCount = 0;
      
      // Delete older backups (already sorted newest first)
      for (int i = keepCount; i < backups.length; i++) {
        try {
          final file = File(backups[i]);
          await file.delete();
          deletedCount++;
          
          if (kDebugMode) {
            print('DatabaseHelper: Deleted old backup: ${backups[i]}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('DatabaseHelper: Error deleting backup ${backups[i]}: $e');
          }
        }
      }
      
      return deletedCount;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error cleaning up backups: $e');
      }
      return 0;
    }
  }

  /// Reset database (delete and recreate)
  /// WARNING: This will delete all data!
  /// Returns true if successful, false otherwise
  static Future<bool> resetDatabase() async {
    try {
      // Create backup before reset
      final backupPath = await createBackup(customName: 'pre_reset_${DateTime.now().millisecondsSinceEpoch}.db');
      
      if (kDebugMode) {
        print('DatabaseHelper: Created backup before reset: $backupPath');
      }
      
      // Close current database connection
      await AppDatabase.instance.closeDatabase();
      
      // Delete database file
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      
      if (await dbFile.exists()) {
        await dbFile.delete();
        
        if (kDebugMode) {
          print('DatabaseHelper: Database file deleted');
        }
      }
      
      // Reinitialize database (will create new empty database)
      AppDatabase.instance;
      
      if (kDebugMode) {
        print('DatabaseHelper: Database reset completed');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error resetting database: $e');
      }
      return false;
    }
  }

  /// Export database to a specific location
  /// Useful for sharing or external backup
  static Future<bool> exportDatabase(String exportPath) async {
    try {
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) {
        if (kDebugMode) {
          print('DatabaseHelper: Database file does not exist');
        }
        return false;
      }
      
      // Copy database to export location
      await dbFile.copy(exportPath);
      
      if (kDebugMode) {
        print('DatabaseHelper: Database exported to $exportPath');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error exporting database: $e');
      }
      return false;
    }
  }

  /// Import database from external location
  /// WARNING: This will replace current database!
  static Future<bool> importDatabase(String importPath) async {
    try {
      final importFile = File(importPath);
      
      if (!await importFile.exists()) {
        if (kDebugMode) {
          print('DatabaseHelper: Import file does not exist');
        }
        return false;
      }
      
      // Create backup of current database first
      await createBackup(customName: 'pre_import_${DateTime.now().millisecondsSinceEpoch}.db');
      
      // Close current database connection
      await AppDatabase.instance.closeDatabase();
      
      // Get database path
      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);
      
      // Delete current database if exists
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      // Copy import file to database location
      await importFile.copy(dbPath);
      
      if (kDebugMode) {
        print('DatabaseHelper: Database imported from $importPath');
      }
      
      // Reinitialize database
      AppDatabase.instance;
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error importing database: $e');
      }
      return false;
    }
  }

  /// Check database integrity
  /// Runs PRAGMA integrity_check
  static Future<bool> checkIntegrity() async {
    try {
      final db = AppDatabase.instance;
      final result = await db.customSelect('PRAGMA integrity_check').get();
      
      if (result.isNotEmpty && result.first.data['integrity_check'] == 'ok') {
        if (kDebugMode) {
          print('DatabaseHelper: Database integrity check passed');
        }
        return true;
      }
      
      if (kDebugMode) {
        print('DatabaseHelper: Database integrity check failed');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error checking database integrity: $e');
      }
      return false;
    }
  }

  /// Vacuum database to reclaim space
  /// This can reduce database file size after deletions
  static Future<bool> vacuumDatabase() async {
    try {
      final db = AppDatabase.instance;
      await db.customStatement('VACUUM');
      
      if (kDebugMode) {
        print('DatabaseHelper: Database vacuumed successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error vacuuming database: $e');
      }
      return false;
    }
  }

  /// Get database statistics
  /// Returns a map with various database metrics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final stats = <String, dynamic>{};
      
      // Get database size
      stats['sizeInBytes'] = await getDatabaseSize();
      stats['sizeFormatted'] = await getDatabaseSizeFormatted();
      
      // Check if database exists
      stats['exists'] = await databaseExists();
      
      // Get profile count
      final db = AppDatabase.instance;
      final profileCount = await db.profileDao.getProfileCount();
      stats['profileCount'] = profileCount;
      
      // Get profiles needing sync
      final profilesNeedingSync = await db.profileDao.getProfilesNeedingSync();
      stats['profilesNeedingSync'] = profilesNeedingSync.length;
      
      // Check integrity
      stats['integrityOk'] = await checkIntegrity();
      
      // Get backup count
      final backups = await listBackups();
      stats['backupCount'] = backups.length;
      
      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('DatabaseHelper: Error getting database stats: $e');
      }
      return {};
    }
  }
}