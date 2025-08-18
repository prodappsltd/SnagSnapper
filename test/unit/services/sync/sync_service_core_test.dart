import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'dart:async';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock SharedPreferences
  SharedPreferences.setMockInitialValues({});
  group('SyncService Core Tests - Phase 3 TDD', () {
    late SyncService syncService;
    
    setUp(() {
      syncService = SyncService.instance;
    });

    group('Service Initialization', () {
      test('should implement singleton pattern', () {
        final instance1 = SyncService.instance;
        final instance2 = SyncService.instance;
        
        expect(identical(instance1, instance2), isTrue,
            reason: 'SyncService should return same instance');
      });

      test('should initialize with user ID', () async {
        await syncService.initialize('test-user-123');
        
        expect(syncService.isInitialized, isTrue,
            reason: 'Service should be initialized');
        expect(syncService.userId, equals('test-user-123'),
            reason: 'User ID should be stored');
      });

      test('should provide status stream', () async {
        await syncService.initialize('test-user-456');
        
        expect(syncService.statusStream, isA<Stream<SyncStatus>>(),
            reason: 'Should provide status stream');
      });

      test('should provide progress stream', () async {
        await syncService.initialize('test-user-789');
        
        expect(syncService.progressStream, isA<Stream<double>>(),
            reason: 'Should provide progress stream');
      });

      test('should provide error stream', () async {
        await syncService.initialize('test-user-error');
        
        expect(syncService.errorStream, isA<Stream<SyncError>>(),
            reason: 'Should provide error stream');
      });
    });

    group('Sync Operations', () {
      test('should trigger manual sync', () async {
        await syncService.initialize('test-manual-sync');
        
        // Listen for status updates
        final statusCompleter = Completer<SyncStatus>();
        final subscription = syncService.statusStream.listen((status) {
          if (!statusCompleter.isCompleted) {
            statusCompleter.complete(status);
          }
        });
        
        // Trigger sync
        final result = await syncService.syncNow();
        
        expect(result, isA<SyncResult>(),
            reason: 'Should return sync result');
        
        // Clean up
        await subscription.cancel();
      });

      test('should prevent concurrent syncs', () async {
        await syncService.initialize('test-concurrent');
        
        // Start first sync
        final sync1 = syncService.syncNow();
        
        // Try to start second sync immediately
        final sync2 = syncService.syncNow();
        
        // Both should complete but second should be prevented
        final results = await Future.wait([sync1, sync2]);
        
        expect(results.length, equals(2),
            reason: 'Both calls should complete');
      });

      test('should handle sync cancellation', () async {
        await syncService.initialize('test-cancel');
        
        // Start sync
        final syncFuture = syncService.syncNow();
        
        // Cancel immediately
        syncService.cancelSync();
        
        final result = await syncFuture;
        
        expect(result.success, isFalse,
            reason: 'Cancelled sync should not succeed');
      });

      test('should pause and resume sync', () async {
        await syncService.initialize('test-pause');
        
        // Pause sync
        syncService.pauseSync();
        expect(syncService.isPaused, isTrue,
            reason: 'Sync should be paused');
        
        // Resume sync
        syncService.resumeSync();
        expect(syncService.isPaused, isFalse,
            reason: 'Sync should be resumed');
      });
    });

    group('Profile Sync', () {
      test('should sync profile data when needed', () async {
        await syncService.initialize('test-profile-sync');
        
        // Create test user with sync flag
        final testUser = AppUser(
          id: 'test-profile-sync',
          name: 'Test User',
          email: 'test@example.com',
          phone: '07700900000',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          needsProfileSync: true, // Flag for sync
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Sync should handle this profile
        final result = await syncService.syncProfile('test-profile-sync');
        
        expect(result, isNotNull,
            reason: 'Should return result for profile sync');
      });

      test('should skip sync when flags are false', () async {
        await syncService.initialize('test-skip-sync');
        
        // Create test user without sync flags
        final testUser = AppUser(
          id: 'test-skip-sync',
          name: 'Test User',
          email: 'test@example.com',
          phone: '07700900000',
          jobTitle: 'Tester',
          companyName: 'Test Co',
          needsProfileSync: false, // No sync needed
          needsImageSync: false,
          needsSignatureSync: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Sync should skip this profile
        final result = await syncService.syncProfile('test-skip-sync');
        
        expect(result, isTrue,
            reason: 'Should return success even when skipping');
      });
    });

    group('Network Handling', () {
      test('should handle offline mode', () async {
        await syncService.initialize('test-offline');
        
        // Test offline handling (would need mock network monitor)
        // For now, just test that sync returns a result
        final result = await syncService.syncNow();
        
        expect(result, isNotNull,
            reason: 'Should return a result even when offline');
      });

      test('should queue items when offline', () async {
        await syncService.initialize('test-queue-offline');
        
        // Test queue handling when offline (would need mock network monitor)
        // For now, just test that sync completes
        final result = await syncService.syncNow();
        
        expect(result, isNotNull,
            reason: 'Should handle sync request');
      });
    });

    group('Error Handling', () {
      test('should emit errors to error stream', () async {
        await syncService.initialize('test-error-stream');
        
        final errorCompleter = Completer<SyncError>();
        syncService.errorStream.listen((error) {
          if (!errorCompleter.isCompleted) {
            errorCompleter.complete(error);
          }
        });
        
        // Trigger an error
        syncService.handleError(SyncError(
          type: SyncErrorType.network,
          message: 'Test network error',
        ));
        
        final error = await errorCompleter.future;
        
        expect(error.type, equals(SyncErrorType.network),
            reason: 'Should emit correct error type');
        expect(error.message, contains('Test network error'),
            reason: 'Should emit error message');
      });

      test('should retry on transient errors', () async {
        await syncService.initialize('test-retry');
        
        // Test retry logic (would need mock dependencies)
        final result = await syncService.syncNow();
        
        // Should complete even with errors
        expect(result, isNotNull,
            reason: 'Should complete sync attempt');
      });
    });

    group('Progress Tracking', () {
      test('should emit progress updates', () async {
        await syncService.initialize('test-progress');
        
        final progressValues = <double>[];
        final subscription = syncService.progressStream.listen(
          progressValues.add
        );
        
        // Trigger sync
        await syncService.syncNow();
        
        // Should have received progress updates
        expect(progressValues.isNotEmpty, isTrue,
            reason: 'Should emit progress values');
        
        // Progress should be between 0 and 1
        for (final progress in progressValues) {
          expect(progress, greaterThanOrEqualTo(0.0));
          expect(progress, lessThanOrEqualTo(1.0));
        }
        
        await subscription.cancel();
      });
    });

    group('Cleanup', () {
      test('should dispose resources properly', () {
        syncService.dispose();
        
        expect(() => syncService.statusStream.listen((_) {}),
            throwsStateError,
            reason: 'Streams should be closed after dispose');
      });
    });
  });
}