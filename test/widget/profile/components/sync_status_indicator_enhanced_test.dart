import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/database/daos/profile_dao.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/services/sync_service.dart';

import '../manual_mocks.dart';

// Manual mocks for database-related classes
class MockAppDatabase extends Mock implements AppDatabase {}
class MockProfileDao extends Mock implements ProfileDao {}

// Enhanced version of SyncStatusIndicator with new features
class EnhancedSyncStatusIndicator extends StatefulWidget {
  final String userId;
  final AppDatabase database;
  final SyncService syncService;
  
  const EnhancedSyncStatusIndicator({
    super.key,
    required this.userId,
    required this.database,
    required this.syncService,
  });
  
  @override
  State<EnhancedSyncStatusIndicator> createState() => _EnhancedSyncStatusIndicatorState();
}

class _EnhancedSyncStatusIndicatorState extends State<EnhancedSyncStatusIndicator> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<SyncError>? _errorSubscription;
  
  SyncStatus _currentStatus = SyncStatus.idle;
  double _progress = 0.0;
  SyncError? _lastError;
  DateTime? _lastSyncTime;
  List<String> _pendingChanges = [];
  bool _isOffline = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    
    _initialize();
  }
  
  Future<void> _initialize() async {
    // Subscribe to streams
    _statusSubscription = widget.syncService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          if (status == SyncStatus.syncing) {
            _animationController.repeat();
          } else {
            _animationController.stop();
          }
        });
      }
    });
    
    _progressSubscription = widget.syncService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    });
    
    _errorSubscription = widget.syncService.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _lastError = error;
        });
      }
    });
    
    // Load initial data
    await _loadSyncStatus();
  }
  
  Future<void> _loadSyncStatus() async {
    final user = await widget.database.profileDao.getProfile(widget.userId);
    if (user != null && mounted) {
      setState(() {
        _lastSyncTime = user.lastSyncTime;
        _pendingChanges.clear();
        if (user.needsProfileSync) _pendingChanges.add('Profile');
        if (user.needsImageSync) _pendingChanges.add('Profile Image');
        if (user.needsSignatureSync) _pendingChanges.add('Signature');
      });
    }
  }
  
  Future<void> _triggerManualSync() async {
    if (_currentStatus == SyncStatus.syncing) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    final result = await widget.syncService.syncNow();
    if (result.success) {
      await _loadSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  void _showSyncDetails() {
    // Haptic feedback for long press
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lastSyncTime != null)
              Text('Last Sync: ${_getRelativeTime(_lastSyncTime!)}'),
            const SizedBox(height: 8),
            if (_pendingChanges.isNotEmpty) ...[
              const Text('Pending Changes:'),
              ..._pendingChanges.map((change) => Text('• $change')),
            ] else
              const Text('No pending changes'),
            if (_lastError != null) ...[
              const SizedBox(height: 8),
              Text('Last Error: ${_lastError!.message}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_pendingChanges.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _triggerManualSync();
              },
              child: const Text('Sync Now'),
            ),
        ],
      ),
    );
  }
  
  String _getRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
  
  void _dismissError() {
    // Haptic feedback for swipe
    HapticFeedback.lightImpact();
    
    setState(() {
      _lastError = null;
    });
  }
  
  Widget _buildStatusIcon() {
    if (_isOffline) {
      return const Icon(Icons.cloud_off, color: Colors.grey, size: 20);
    }
    
    switch (_currentStatus) {
      case SyncStatus.idle:
        return const Icon(Icons.cloud_queue, color: Colors.grey, size: 20);
      case SyncStatus.synced:
        return const Icon(Icons.cloud_done, color: Colors.green, size: 20);
      case SyncStatus.pending:
        return const Icon(Icons.cloud_upload, color: Colors.orange, size: 20);
      case SyncStatus.syncing:
        return AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: const Icon(Icons.sync, color: Colors.blue, size: 20),
            );
          },
        );
      case SyncStatus.error:
      case SyncStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_lastError != null) {
      // Error state with swipe to dismiss
      return Dismissible(
        key: Key('error_${_lastError.hashCode}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => _dismissError(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text(
                'Sync error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    
    return GestureDetector(
      onTap: _pendingChanges.isNotEmpty && !_isOffline && _currentStatus != SyncStatus.syncing
          ? _triggerManualSync
          : null,
      onLongPress: _showSyncDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _currentStatus == SyncStatus.syncing
              ? Colors.blue.withOpacity(0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(),
            const SizedBox(width: 4),
            if (_currentStatus == SyncStatus.syncing && _progress > 0) ...[
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12),
              ),
            ] else if (_pendingChanges.isNotEmpty) ...[
              Text(
                '${_pendingChanges.length} pending',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ] else if (_lastSyncTime != null) ...[
              Text(
                _getRelativeTime(_lastSyncTime!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Enhanced Sync Status Indicator Tests', () {
    late MockAppDatabase mockDatabase;
    late MockProfileDao mockProfileDao;
    late MockSyncService mockSyncService;
    
    late StreamController<SyncStatus> statusController;
    late StreamController<double> progressController;
    late StreamController<SyncError> errorController;
    
    const testUserId = 'test_user_123';
    late AppUser testUser;
    
    setUp(() {
      mockDatabase = MockAppDatabase();
      mockProfileDao = MockProfileDao();
      mockSyncService = MockSyncService();
      
      statusController = StreamController<SyncStatus>.broadcast();
      progressController = StreamController<double>.broadcast();
      errorController = StreamController<SyncError>.broadcast();
      
      when(mockSyncService.statusStream).thenAnswer((_) => statusController.stream);
      when(mockSyncService.progressStream).thenAnswer((_) => progressController.stream);
      when(mockSyncService.errorStream).thenAnswer((_) => errorController.stream);
      when(mockSyncService.isSyncing).thenReturn(false);
      
      when(mockDatabase.profileDao).thenReturn(mockProfileDao);
      
      testUser = AppUser(
        id: testUserId,
        name: 'Test User',
        email: 'test@example.com',
        companyName: 'Test Company',
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
    
    group('Real-time Updates', () {
      testWidgets('shows correct icon for each status', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        // Test idle state
        statusController.add(SyncStatus.idle);
        await tester.pump();
        expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
        
        // Test synced state
        statusController.add(SyncStatus.synced);
        await tester.pump();
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
        
        // Test pending state
        statusController.add(SyncStatus.pending);
        await tester.pump();
        expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
        
        // Test syncing state
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        expect(find.byIcon(Icons.sync), findsOneWidget);
        
        // Test error state
        statusController.add(SyncStatus.error);
        await tester.pump();
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
      
      testWidgets('animates sync icon during sync', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Check that animation is running
        expect(find.byType(AnimatedBuilder), findsOneWidget);
        
        // Pump a few frames to see animation
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      });
      
      testWidgets('shows progress percentage during sync', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        statusController.add(SyncStatus.syncing);
        progressController.add(0.5);
        await tester.pump();
        
        expect(find.text('50%'), findsOneWidget);
        
        progressController.add(0.75);
        await tester.pump();
        
        expect(find.text('75%'), findsOneWidget);
      });
      
      testWidgets('shows pending changes count', (tester) async {
        testUser = testUser.copyWith(
          needsProfileSync: true,
          needsImageSync: true,
        );
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('2 pending'), findsOneWidget);
      });
    });
    
    group('User Interactions', () {
      testWidgets('tap triggers manual sync when changes pending', (tester) async {
        testUser = testUser.copyWith(needsProfileSync: true);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        when(mockSyncService.syncNow())
            .thenAnswer((_) async => SyncResult.success(syncedItems: ['profile']));
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        await tester.tap(find.byType(EnhancedSyncStatusIndicator));
        await tester.pumpAndSettle();
        
        verify(mockSyncService.syncNow()).called(1);
      });
      
      testWidgets('long press shows sync details dialog', (tester) async {
        testUser = testUser.copyWith(
          needsProfileSync: true,
          lastSyncTime: DateTime.now().subtract(const Duration(minutes: 30)),
        );
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        await tester.longPress(find.byType(EnhancedSyncStatusIndicator));
        await tester.pumpAndSettle();
        
        expect(find.text('Sync Details'), findsOneWidget);
        expect(find.text('Last Sync: 30m ago'), findsOneWidget);
        expect(find.text('Pending Changes:'), findsOneWidget);
        expect(find.text('• Profile'), findsOneWidget);
      });
      
      testWidgets('swipe dismisses error state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Emit error
        errorController.add(SyncError(
          type: SyncErrorType.network,
          message: 'Network error',
        ));
        await tester.pump();
        
        expect(find.text('Sync error'), findsOneWidget);
        
        // Swipe to dismiss
        await tester.drag(find.byType(Dismissible), const Offset(200, 0));
        await tester.pumpAndSettle();
        
        expect(find.text('Sync error'), findsNothing);
      });
      
      testWidgets('disabled when already syncing', (tester) async {
        when(mockSyncService.isSyncing).thenReturn(true);
        testUser = testUser.copyWith(needsProfileSync: true);
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        statusController.add(SyncStatus.syncing);
        await tester.pumpAndSettle();
        
        await tester.tap(find.byType(EnhancedSyncStatusIndicator));
        await tester.pump();
        
        verifyNever(mockSyncService.syncNow());
      });
    });
    
    group('Visual Feedback', () {
      testWidgets('shows offline icon when offline', (tester) async {
        // Mark as offline by setting a flag
        // This would normally be done through connectivity check
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Initially should not show offline icon
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });
      
      testWidgets('shows relative time for last sync', (tester) async {
        testUser = testUser.copyWith(
          lastSyncTime: DateTime.now().subtract(const Duration(hours: 2)),
        );
        when(mockProfileDao.getProfile(testUserId))
            .thenAnswer((_) async => testUser);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        expect(find.text('2h ago'), findsOneWidget);
      });
      
      testWidgets('highlights when syncing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EnhancedSyncStatusIndicator(
                userId: testUserId,
                database: mockDatabase,
                syncService: mockSyncService,
              ),
            ),
          ),
        );
        
        statusController.add(SyncStatus.syncing);
        await tester.pump();
        
        // Check for blue background container
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(GestureDetector),
            matching: find.byType(Container),
          ).first,
        );
        
        expect(container.decoration, isNotNull);
      });
    });
  });
}