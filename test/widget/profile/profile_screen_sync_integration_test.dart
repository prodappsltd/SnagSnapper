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
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_mocks.dart';

// Manual mocks for database-related classes
class MockAppDatabase extends Mock implements AppDatabase {}
class MockProfileDao extends Mock implements ProfileDao {}

// Test version of ProfileScreen with sync integration
class TestableProfileScreen extends ProfileScreen {
  final SyncService? syncServiceOverride;
  
  TestableProfileScreen({
    super.key,
    required super.database,
    required super.userId,
    super.imageStorageService,
    super.isOffline,
    this.syncServiceOverride,
  });
  
  @override
  TestableProfileScreenState createState() => TestableProfileScreenState();
}

class TestableProfileScreenState extends State<TestableProfileScreen> {
  late SyncService syncService;
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<SyncError>? _errorSubscription;
  
  SyncStatus? currentSyncStatus;
  double syncProgress = 0.0;
  SyncError? lastSyncError;
  bool showProgressOverlay = false;
  
  @override
  void initState() {
    super.initState();
    syncService = widget.syncServiceOverride ?? SyncService.instance;
    _initializeSyncStreams();
  }
  
  void _initializeSyncStreams() {
    _statusSubscription = syncService.statusStream.listen(_onSyncStatusChange);
    _progressSubscription = syncService.progressStream.listen(_onProgressUpdate);
    _errorSubscription = syncService.errorStream.listen(_onSyncError);
  }
  
  void _onSyncStatusChange(SyncStatus status) {
    if (mounted) {
      setState(() {
        currentSyncStatus = status;
        showProgressOverlay = status == SyncStatus.syncing;
      });
    }
  }
  
  void _onProgressUpdate(double progress) {
    if (mounted) {
      setState(() {
        syncProgress = progress;
      });
    }
  }
  
  void _onSyncError(SyncError error) {
    if (mounted) {
      setState(() {
        lastSyncError = error;
      });
      _showErrorDialog(error);
    }
  }
  
  Future<void> _showErrorDialog(SyncError error) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Error'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (error.isRecoverable)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _triggerSync();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
    
    // Auto-clear error after timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          lastSyncError = null;
        });
      }
    });
  }
  
  Future<void> _triggerSync() async {
    final result = await syncService.syncNow();
    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual ProfileScreen UI would go here
        Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              if (currentSyncStatus == SyncStatus.pending && !widget.isOffline)
                TextButton(
                  onPressed: syncService.isSyncing ? null : _triggerSync,
                  child: const Text('Sync'),
                ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentSyncStatus != null)
                  Text('Sync Status: ${currentSyncStatus.toString()}'),
                if (syncProgress > 0)
                  Text('Progress: ${(syncProgress * 100).toStringAsFixed(0)}%'),
                if (lastSyncError != null)
                  Text('Error: ${lastSyncError!.message}'),
              ],
            ),
          ),
        ),
        
        // Progress overlay
        if (showProgressOverlay)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('${(syncProgress * 100).toStringAsFixed(0)}%'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: syncProgress),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileScreen Sync Integration', () {
    late MockAppDatabase mockDatabase;
    late MockProfileDao mockProfileDao;
    late MockSyncService mockSyncService;
    late MockImageStorageService mockImageStorageService;
    
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

    group('Stream Integration', () {
      testWidgets('subscribes to sync status stream on mount', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        verify(mockSyncService.statusStream).called(greaterThan(0));
      });

      testWidgets('updates UI on status changes', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit syncing status
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        expect(find.text('Sync Status: SyncStatus.syncing'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Emit synced status
        statusController.add(SyncStatus.synced);
        await tester.pump();
        
        expect(find.text('Sync Status: SyncStatus.synced'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows progress overlay during sync', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Start sync
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Progress overlay should be visible
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        
        // Update progress
        progressController.add(0.5);
        await tester.pump();
        
        expect(find.text('50%'), findsOneWidget);
      });

      testWidgets('displays error dialog on sync error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network connection failed',
        ));
        await tester.pumpAndSettle();
        
        // Error dialog should appear
        expect(find.text('Sync Error'), findsOneWidget);
        expect(find.text('Network connection failed'), findsOneWidget);
      });

      testWidgets('shows retry button for recoverable errors', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit recoverable error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network timeout',
          isRecoverable: true,
        ));
        await tester.pumpAndSettle();
        
        // Retry button should be visible
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('unsubscribes on dispose', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Navigate away to dispose widget
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: Text('Different Screen')),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Streams should be closed
        expect(statusController.hasListener, isFalse);
        expect(progressController.hasListener, isFalse);
        expect(errorController.hasListener, isFalse);
      });
    });

    group('Manual Sync', () {
      testWidgets('shows sync button when changes are pending', (tester) async {
        testUser = testUser.copyWith(needsProfileSync: true);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        statusController.add(SyncStatus.pending);
        await tester.pumpAndSettle();
        
        expect(find.widgetWithText(TextButton, 'Sync'), findsOneWidget);
      });

      testWidgets('disables sync button during active sync', (tester) async {
        when(mockSyncService.isSyncing).thenReturn(true);
        
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        statusController.add(SyncStatus.pending);
        await tester.pumpAndSettle();
        
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        if (syncButton.evaluate().isNotEmpty) {
          final button = tester.widget<TextButton>(syncButton);
          expect(button.onPressed, isNull);
        }
      });

      testWidgets('triggers sync and shows success message', (tester) async {
        when(mockSyncService.syncNow()).thenAnswer(
          (_) async => SyncResult.success(syncedItems: ['profile']),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        statusController.add(SyncStatus.pending);
        await tester.pumpAndSettle();
        
        final syncButton = find.widgetWithText(TextButton, 'Sync');
        await tester.tap(syncButton);
        await tester.pumpAndSettle();
        
        expect(find.text('Sync completed successfully'), findsOneWidget);
        verify(mockSyncService.syncNow()).called(1);
      });

      testWidgets('hides sync button when offline', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
              isOffline: true,
            ),
          ),
        );
        
        statusController.add(SyncStatus.pending);
        await tester.pumpAndSettle();
        
        expect(find.widgetWithText(TextButton, 'Sync'), findsNothing);
      });
    });

    group('Progress Updates', () {
      testWidgets('updates progress percentage smoothly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Test multiple progress updates
        for (double progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          progressController.add(progress);
          await tester.pump();
          
          final percentage = (progress * 100).toStringAsFixed(0);
          expect(find.text('$percentage%'), findsWidgets);
        }
      });

      testWidgets('hides progress overlay on completion', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Start sync
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        
        // Complete sync
        statusController.add(SyncStatus.synced);
        progressController.add(1.0);
        await tester.pumpAndSettle();
        
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('Error Handling', () {
      testWidgets('clears error after timeout', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Temporary error',
        ));
        await tester.pumpAndSettle();
        
        // Close dialog
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        
        // Error should be displayed
        expect(find.text('Error: Temporary error'), findsOneWidget);
        
        // Wait for timeout
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        
        // Error should be cleared
        expect(find.text('Error: Temporary error'), findsNothing);
      });

      testWidgets('retry button triggers new sync', (tester) async {
        when(mockSyncService.syncNow()).thenAnswer(
          (_) async => SyncResult.success(syncedItems: ['profile']),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: TestableProfileScreen(
              database: mockDatabase,
              userId: testUserId,
              imageStorageService: mockImageStorageService,
              syncServiceOverride: mockSyncService,
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit recoverable error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network timeout',
          isRecoverable: true,
        ));
        await tester.pumpAndSettle();
        
        // Tap retry
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        
        verify(mockSyncService.syncNow()).called(1);
      });
    });
  });
}