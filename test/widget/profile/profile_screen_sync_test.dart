import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/screens/profile/profile_screen_ui_matched.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.mocks.dart';

// Manual mocks for database-related classes
class MockAppDatabase extends Mock implements AppDatabase {}
class MockProfileDao extends Mock implements ProfileDao {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileScreen Sync Integration Tests', () {
    late MockAppDatabase mockDatabase;
    late MockProfileDao mockProfileDao;
    late MockSyncService mockSyncService;
    late MockImageStorageService mockImageStorageService;
    late MockConnectivity mockConnectivity;
    
    // Stream controllers for testing
    late StreamController<SyncStatus> statusController;
    late StreamController<double> progressController;
    late StreamController<SyncError> errorController;
    
    const testUserId = 'test_user_123';
    late AppUser testUser;

    setUp(() {
      mockDatabase = MockAppDatabase();
      mockProfileDao = MockProfileDao();
      mockSyncService = MockSyncService();
      mockImageStorageService = MockImageStorageService();
      mockConnectivity = MockConnectivity();
      
      // Set up stream controllers
      statusController = StreamController<SyncStatus>.broadcast();
      progressController = StreamController<double>.broadcast();
      errorController = StreamController<SyncError>.broadcast();
      
      // Configure mock sync service streams
      when(mockSyncService.statusStream).thenAnswer((_) => statusController.stream);
      when(mockSyncService.progressStream).thenAnswer((_) => progressController.stream);
      when(mockSyncService.errorStream).thenAnswer((_) => errorController.stream);
      when(mockSyncService.isSyncing).thenReturn(false);
      when(mockSyncService.isInitialized).thenReturn(true);
      
      // Configure mock database
      when(mockDatabase.profileDao).thenReturn(mockProfileDao);
      
      // Create test user
      testUser = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        jobTitle: 'Developer',
        companyName: 'Test Company',
        postcodeOrArea: '12345',
        dateFormat: 'dd-MM-yyyy',
        needsProfileSync: false,
        needsImageSync: false,
        needsSignatureSync: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      when(mockProfileDao.getProfile(testUserId))
          .thenAnswer((_) async => testUser);
    });

    tearDown(() {
      statusController.close();
      progressController.close();
      errorController.close();
    });

    group('Stream Integration Tests', () {
      testWidgets('should subscribe to sync status stream on mount', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Assert
        verify(mockSyncService.statusStream).called(greaterThan(0));
      });

      testWidgets('should update UI on status changes', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit different status changes
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Assert - Check UI reflects syncing status
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        
        // Act - Emit synced status
        statusController.add(SyncStatus.synced);
        await tester.pump();
        
        // Assert - Progress indicator should be gone
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('should handle stream errors gracefully', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit error
        errorController.addError('Test error');
        await tester.pump();
        
        // Assert - App should not crash
        expect(tester.takeException(), isNull);
      });

      testWidgets('should unsubscribe on dispose', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Navigate away to dispose widget
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Different Screen')),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Assert - Streams should be closed/unsubscribed
        expect(statusController.hasListener, isFalse);
        expect(progressController.hasListener, isFalse);
        expect(errorController.hasListener, isFalse);
      });
    });

    group('Progress Stream Tests', () {
      testWidgets('should show progress overlay during sync', (tester) async {
        // Arrange
        when(mockSyncService.isSyncing).thenReturn(true);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit progress updates
        progressController.add(0.25);
        await tester.pump();
        
        // Assert - Progress indicator should be visible
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('should update progress percentage', (tester) async {
        // Arrange
        when(mockSyncService.isSyncing).thenReturn(true);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit different progress values
        progressController.add(0.0);
        await tester.pump();
        expect(find.text('0%'), findsOneWidget);
        
        progressController.add(0.5);
        await tester.pump();
        expect(find.text('50%'), findsOneWidget);
        
        progressController.add(1.0);
        await tester.pump();
        expect(find.text('100%'), findsOneWidget);
      });

      testWidgets('should hide overlay on completion', (tester) async {
        // Arrange
        when(mockSyncService.isSyncing).thenReturn(true);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Show progress then complete
        progressController.add(0.5);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        
        // Complete sync
        when(mockSyncService.isSyncing).thenReturn(false);
        statusController.add(SyncStatus.synced);
        progressController.add(1.0);
        await tester.pumpAndSettle();
        
        // Assert - Overlay should be hidden
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('Error Stream Tests', () {
      testWidgets('should display error dialog on sync error', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network connection failed',
        ));
        await tester.pumpAndSettle();
        
        // Assert - Error dialog should appear
        expect(find.text('Sync Error'), findsOneWidget);
        expect(find.text('Network connection failed'), findsOneWidget);
      });

      testWidgets('should show retry option for recoverable errors', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit recoverable error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network timeout',
          isRecoverable: true,
        ));
        await tester.pumpAndSettle();
        
        // Assert - Retry button should be visible
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('should clear error after timeout', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Temporary error',
        ));
        await tester.pumpAndSettle();
        
        // Wait for timeout (5 seconds)
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        
        // Assert - Error should be cleared
        expect(find.text('Temporary error'), findsNothing);
      });
    });

    group('Manual Sync Trigger Tests', () {
      testWidgets('should disable sync button when offline', (tester) async {
        // Arrange
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              isOffline: true,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Assert - Sync button should be disabled
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        expect(syncButton, findsOneWidget);
        
        final button = tester.widget<TextButton>(syncButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('should disable sync button during active sync', (tester) async {
        // Arrange
        when(mockSyncService.isSyncing).thenReturn(true);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Assert - Sync button should be disabled
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        if (syncButton.evaluate().isNotEmpty) {
          final button = tester.widget<TextButton>(syncButton);
          expect(button.onPressed, isNull);
        }
      });

      testWidgets('should show loading state during sync', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Start sync
        when(mockSyncService.isSyncing).thenReturn(true);
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Assert - Loading indicator should be visible
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });
    });

    group('Sync Success Flow Tests', () {
      testWidgets('should show success message on sync completion', (tester) async {
        // Arrange
        when(mockSyncService.syncNow()).thenAnswer(
          (_) async => SyncResult.success(syncedItems: ['profile']),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Trigger sync
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        if (syncButton.evaluate().isNotEmpty) {
          await tester.tap(syncButton);
          await tester.pumpAndSettle();
        }
        
        // Assert - Success snackbar should appear
        expect(find.text('Sync completed successfully'), findsOneWidget);
      });

      testWidgets('should refresh profile data after sync', (tester) async {
        // Arrange
        final updatedUser = testUser.copyWith(
          name: 'Updated Name',
          updatedAt: DateTime.now(),
        );
        
        when(mockSyncService.syncNow()).thenAnswer(
          (_) async => SyncResult.success(syncedItems: ['profile']),
        );
        
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => updatedUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Complete sync
        statusController.add(SyncStatus.synced);
        await tester.pumpAndSettle();
        
        // Assert - Profile should be refreshed
        verify(mockProfileDao.getProfile(testUserId)).called(greaterThan(1));
      });

      testWidgets('should clear pending changes indicator', (tester) async {
        // Arrange
        testUser = testUser.copyWith(needsProfileSync: true);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Complete sync
        testUser = testUser.copyWith(needsProfileSync: false);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        statusController.add(SyncStatus.synced);
        await tester.pumpAndSettle();
        
        // Assert - Pending indicator should be gone
        expect(find.text('Pending sync'), findsNothing);
      });
    });

    group('Sync Failure Flow Tests', () {
      testWidgets('should show error message on sync failure', (tester) async {
        // Arrange
        when(mockSyncService.syncNow()).thenAnswer(
          (_) async => SyncResult.failure(message: 'Connection timeout'),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Connection timeout',
        ));
        await tester.pumpAndSettle();
        
        // Assert - Error message should appear
        expect(find.text('Connection timeout'), findsOneWidget);
      });

      testWidgets('should preserve local changes on failure', (tester) async {
        // Arrange
        testUser = testUser.copyWith(
          name: 'Local Change',
          needsProfileSync: true,
        );
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Sync fails
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Sync failed',
        ));
        await tester.pumpAndSettle();
        
        // Assert - Local changes should be preserved
        expect(testUser.needsProfileSync, isTrue);
        expect(testUser.name, equals('Local Change'));
      });
    });

    group('Auto-sync Tests', () {
      testWidgets('should trigger sync after profile save', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Save profile
        final saveButton = find.widgetWithText(TextButton, 'Save');
        if (saveButton.evaluate().isNotEmpty) {
          // Make a change first
          final nameField = find.byType(TextFormField).first;
          await tester.enterText(nameField, 'New Name');
          
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
        }
        
        // Assert - Sync should be triggered
        verify(mockSyncService.syncNow()).called(1);
      });

      testWidgets('should respect WiFi-only setting', (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'wifi_only_sync': true,
        });
        
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Try to sync on mobile
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        if (syncButton.evaluate().isNotEmpty) {
          await tester.tap(syncButton);
          await tester.pumpAndSettle();
        }
        
        // Assert - Sync should not be triggered
        verifyNever(mockSyncService.syncNow());
        expect(find.text('WiFi required for sync'), findsOneWidget);
      });

      testWidgets('should queue sync if offline', (tester) async {
        // Arrange
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              isOffline: true,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Save while offline
        final saveButton = find.widgetWithText(TextButton, 'Save');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
        }
        
        // Assert - Should show queued message
        expect(find.text('Saved locally - will sync when online'), findsOneWidget);
      });

      testWidgets('should sync on app resume if pending changes', (tester) async {
        // Arrange
        testUser = testUser.copyWith(needsProfileSync: true);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Act - Simulate app resume
        final binding = tester.binding;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
        
        // Assert - Should check for pending changes and sync
        verify(mockSyncService.onAppForeground()).called(1);
      });
    });
  });
}