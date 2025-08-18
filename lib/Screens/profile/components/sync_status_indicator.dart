import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/services/sync_service.dart';

/// Sync Status Indicator Widget
/// Shows current sync status and allows manual sync trigger
class SyncStatusIndicator extends StatefulWidget {
  final String userId;
  final AppDatabase database;
  final SyncService syncService;
  final Connectivity? connectivity;

  const SyncStatusIndicator({
    super.key,
    required this.userId,
    required this.database,
    required this.syncService,
    this.connectivity,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late Connectivity _connectivity;
  
  AppUser? _currentUser;
  List<ConnectivityResult> _connectivityResult = [ConnectivityResult.none];
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Enhanced features
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
    _connectivity = widget.connectivity ?? Connectivity();
    
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
    // Load initial data
    await _loadUserData();
    await _checkConnectivity();
    
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
    
    // Set up connectivity listener
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _connectivityResult = result;
        _isOffline = result.contains(ConnectivityResult.none);
      });
      // No need to reload user data on connectivity change
      // The sync service will handle syncing when online
    });
    
    // Remove periodic refresh entirely - not needed!
    // The sync service streams already provide real-time updates
    // We only need to load user data once initially
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    try {
      final user = await widget.database.profileDao.getProfile(widget.userId);
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _lastSyncTime = user.lastSyncTime;
          _pendingChanges.clear();
          if (user.needsProfileSync) _pendingChanges.add('Profile');
          if (user.needsImageSync) _pendingChanges.add('Profile Image');
          if (user.needsSignatureSync) _pendingChanges.add('Signature');
          _isSyncing = widget.syncService.isSyncing;
        });
        
        // Update animation based on sync status
        if (_isSyncing) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user data for sync status: $e');
      }
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (mounted) {
        setState(() {
          _connectivityResult = result;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking connectivity: $e');
      }
    }
  }

  Future<void> _triggerManualSync() async {
    if (_currentStatus == SyncStatus.syncing) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Immediately update UI to show syncing state
    setState(() {
      _currentStatus = SyncStatus.syncing;
      _animationController.repeat();
    });
    
    final result = await widget.syncService.syncNow();
    
    // Update UI based on result
    if (mounted) {
      if (result.success) {
        await _loadUserData();
        setState(() {
          _currentStatus = SyncStatus.synced;
          _lastSyncTime = DateTime.now();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _currentStatus = SyncStatus.error;
          _lastError = SyncError(
            type: SyncErrorType.unknown,
            message: result.message ?? 'Sync failed',
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Sync failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _animationController.stop();
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
    
    final status = _currentStatus;
    switch (status) {
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
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case SyncStatus.failed:
        return const Icon(Icons.cloud_off, color: Colors.red, size: 20);
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending sync';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync failed';
      case SyncStatus.failed:
        return 'Failed';
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.pending:
        return Colors.orange;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.failed:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statusSubscription?.cancel();
    _progressSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectivitySubscription?.cancel();
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