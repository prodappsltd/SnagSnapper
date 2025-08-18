import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Represents the progress of a single operation
class OperationProgress {
  final String id;
  final String description;
  final int totalSteps;
  int completedSteps;
  final DateTime startTime;
  DateTime? endTime;
  Duration? estimatedDuration;

  OperationProgress({
    required this.id,
    required this.description,
    required this.totalSteps,
    this.completedSteps = 0,
    required this.startTime,
    this.endTime,
    this.estimatedDuration,
  });

  double get progress => totalSteps > 0 ? completedSteps / totalSteps : 0.0;
  
  bool get isComplete => completedSteps >= totalSteps;
  
  Duration get elapsedTime => (endTime ?? DateTime.now()).difference(startTime);
  
  Duration? get remainingTime {
    if (isComplete || completedSteps == 0) return null;
    
    final timePerStep = elapsedTime.inMilliseconds / completedSteps;
    final remainingSteps = totalSteps - completedSteps;
    final remainingMs = (timePerStep * remainingSteps).round();
    
    return Duration(milliseconds: remainingMs);
  }
}

/// Represents overall sync progress
class SyncProgress {
  final double overallProgress;
  final String? currentOperation;
  final int operationsCount;
  final int completedOperations;
  final Duration? estimatedTimeRemaining;
  final DateTime timestamp;

  SyncProgress({
    required this.overallProgress,
    this.currentOperation,
    required this.operationsCount,
    this.completedOperations = 0,
    this.estimatedTimeRemaining,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncProgress.idle() {
    return SyncProgress(
      overallProgress: 0.0,
      operationsCount: 0,
      completedOperations: 0,
    );
  }

  factory SyncProgress.complete() {
    return SyncProgress(
      overallProgress: 1.0,
      operationsCount: 0,
      completedOperations: 0,
      currentOperation: 'Sync complete',
    );
  }

  bool get isIdle => operationsCount == 0;
  bool get isComplete => overallProgress >= 1.0;
  bool get isInProgress => !isIdle && !isComplete;
  
  String get progressPercentage => '${(overallProgress * 100).toStringAsFixed(1)}%';
  
  String get statusMessage {
    if (currentOperation != null) return currentOperation!;
    if (isComplete) return 'Sync complete';
    if (isIdle) return 'Ready to sync';
    return 'Syncing...';
  }
  
  String? get timeRemainingText {
    if (estimatedTimeRemaining == null) return null;
    
    final seconds = estimatedTimeRemaining!.inSeconds;
    if (seconds < 60) return '${seconds}s remaining';
    
    final minutes = estimatedTimeRemaining!.inMinutes;
    if (minutes < 60) return '${minutes}m remaining';
    
    final hours = estimatedTimeRemaining!.inHours;
    return '${hours}h ${minutes % 60}m remaining';
  }
}

/// Tracks progress of sync operations with real-time updates
class ProgressTracker {
  // Stream controllers
  final _progressController = StreamController<SyncProgress>.broadcast();
  final _operationsController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  // Operation tracking
  final Map<String, OperationProgress> _operations = {};
  final List<Duration> _completionTimes = [];
  final int _maxHistorySize = 10;
  
  // Time estimation
  DateTime? _syncStartTime;
  double _lastProgress = 0.0;
  DateTime _lastProgressTime = DateTime.now();
  
  // Public streams
  Stream<SyncProgress> get progressStream => _progressController.stream;
  Stream<String> get currentOperationStream => _operationsController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  // Singleton instance
  static ProgressTracker? _instance;
  static ProgressTracker get instance {
    _instance ??= ProgressTracker._();
    return _instance!;
  }
  
  ProgressTracker._();
  
  /// Start tracking overall sync
  void startSync() {
    _syncStartTime = DateTime.now();
    _operations.clear();
    _lastProgress = 0.0;
    _lastProgressTime = DateTime.now();
    
    _updateProgress();
    
    if (kDebugMode) {
      print('Progress tracking started');
    }
  }
  
  /// End tracking overall sync
  void endSync() {
    _syncStartTime = null;
    
    // Store completion time for future estimations
    if (_operations.isNotEmpty) {
      final totalTime = _operations.values
          .map((op) => op.elapsedTime)
          .reduce((a, b) => a + b);
      
      _completionTimes.add(totalTime);
      if (_completionTimes.length > _maxHistorySize) {
        _completionTimes.removeAt(0);
      }
    }
    
    _progressController.add(SyncProgress.complete());
    
    // Clear operations after delay
    Future.delayed(Duration(seconds: 2), () {
      _operations.clear();
      _updateProgress();
    });
    
    if (kDebugMode) {
      print('Progress tracking ended');
    }
  }
  
  /// Start a new operation
  void startOperation(
    String id,
    String description, {
    int totalSteps = 100,
  }) {
    _operations[id] = OperationProgress(
      id: id,
      description: description,
      totalSteps: totalSteps,
      startTime: DateTime.now(),
      estimatedDuration: _estimateOperationDuration(description),
    );
    
    _updateProgress();
    _operationsController.add(description);
    
    if (kDebugMode) {
      print('Started operation: $description ($totalSteps steps)');
    }
  }
  
  /// Update operation progress
  void updateOperation(String id, int completedSteps) {
    final operation = _operations[id];
    if (operation == null) return;
    
    operation.completedSteps = min(completedSteps, operation.totalSteps);
    _updateProgress();
    
    if (kDebugMode && operation.completedSteps % 10 == 0) {
      print('Operation $id: ${operation.completedSteps}/${operation.totalSteps}');
    }
  }
  
  /// Complete an operation
  void completeOperation(String id, {bool success = true}) {
    final operation = _operations[id];
    if (operation == null) return;
    
    operation.completedSteps = operation.totalSteps;
    operation.endTime = DateTime.now();
    
    if (!success) {
      _errorController.add('Failed: ${operation.description}');
    }
    
    _updateProgress();
    
    if (kDebugMode) {
      final status = success ? 'completed' : 'failed';
      print('Operation $status: ${operation.description} '
            '(${operation.elapsedTime.inSeconds}s)');
    }
    
    // Remove completed operation after delay
    Future.delayed(Duration(seconds: 2), () {
      _operations.remove(id);
      _updateProgress();
    });
  }
  
  /// Cancel an operation
  void cancelOperation(String id) {
    _operations.remove(id);
    _updateProgress();
    
    if (kDebugMode) {
      print('Operation cancelled: $id');
    }
  }
  
  /// Report an error
  void reportError(String error) {
    _errorController.add(error);
    
    if (kDebugMode) {
      print('Progress tracker error: $error');
    }
  }
  
  /// Get current progress snapshot
  SyncProgress getCurrentProgress() {
    if (_operations.isEmpty) {
      return SyncProgress.idle();
    }
    
    final totalSteps = _operations.values
        .map((op) => op.totalSteps)
        .fold(0, (a, b) => a + b);
    
    final completedSteps = _operations.values
        .map((op) => op.completedSteps)
        .fold(0, (a, b) => a + b);
    
    final progress = totalSteps > 0 ? completedSteps / totalSteps : 0.0;
    
    final currentOp = _operations.values
        .where((op) => !op.isComplete)
        .firstOrNull;
    
    final completedOps = _operations.values
        .where((op) => op.isComplete)
        .length;
    
    return SyncProgress(
      overallProgress: progress,
      currentOperation: currentOp?.description,
      operationsCount: _operations.length,
      completedOperations: completedOps,
      estimatedTimeRemaining: _estimateTimeRemaining(),
    );
  }
  
  /// Update progress and notify listeners
  void _updateProgress() {
    final progress = getCurrentProgress();
    _progressController.add(progress);
    
    // Update progress tracking for time estimation
    if (progress.overallProgress > _lastProgress) {
      _lastProgress = progress.overallProgress;
      _lastProgressTime = DateTime.now();
    }
  }
  
  /// Estimate remaining time based on current progress
  Duration? _estimateTimeRemaining() {
    if (_operations.isEmpty) return null;
    
    // Method 1: Based on incomplete operations
    final incompleteOps = _operations.values.where((op) => !op.isComplete);
    if (incompleteOps.isEmpty) return Duration.zero;
    
    final remainingTimes = incompleteOps
        .map((op) => op.remainingTime)
        .where((time) => time != null)
        .cast<Duration>()
        .toList();
    
    if (remainingTimes.isEmpty) {
      // Method 2: Based on overall progress rate
      if (_syncStartTime == null || _lastProgress <= 0) return null;
      
      final elapsed = DateTime.now().difference(_syncStartTime!);
      final progressRate = _lastProgress / elapsed.inSeconds;
      
      if (progressRate <= 0) return null;
      
      final remainingProgress = 1.0 - _lastProgress;
      final remainingSeconds = (remainingProgress / progressRate).round();
      
      return Duration(seconds: remainingSeconds);
    }
    
    // Sum all remaining times
    final totalRemaining = remainingTimes.reduce((a, b) => a + b);
    
    // Apply adjustment factor based on historical accuracy
    final adjustedRemaining = _applyHistoricalAdjustment(totalRemaining);
    
    return adjustedRemaining;
  }
  
  /// Estimate operation duration based on history
  Duration? _estimateOperationDuration(String description) {
    if (_completionTimes.isEmpty) return null;
    
    // Use average of historical completion times
    final totalMs = _completionTimes
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    
    final avgMs = totalMs ~/ _completionTimes.length;
    
    // Adjust based on operation type
    final factor = _getOperationFactor(description);
    
    return Duration(milliseconds: (avgMs * factor).round());
  }
  
  /// Get operation factor based on type
  double _getOperationFactor(String description) {
    // Estimate relative duration based on operation type
    if (description.contains('image') || description.contains('photo')) {
      return 2.0; // Images take longer
    } else if (description.contains('profile')) {
      return 1.0; // Profile data is average
    } else if (description.contains('check') || description.contains('validate')) {
      return 0.5; // Validation is quick
    } else {
      return 1.0; // Default
    }
  }
  
  /// Apply historical adjustment to time estimate
  Duration _applyHistoricalAdjustment(Duration estimate) {
    // If we have historical data, apply adjustment
    if (_completionTimes.length >= 3) {
      // Calculate accuracy factor from recent estimates
      // For now, add 20% buffer (estimates tend to be optimistic)
      final adjustedMs = (estimate.inMilliseconds * 1.2).round();
      return Duration(milliseconds: adjustedMs);
    }
    
    // No adjustment if insufficient history
    return estimate;
  }
  
  /// Get analytics about progress tracking
  Map<String, dynamic> getAnalytics() {
    final activeOps = _operations.values.where((op) => !op.isComplete).length;
    final completedOps = _operations.values.where((op) => op.isComplete).length;
    
    final avgCompletionTime = _completionTimes.isEmpty
        ? null
        : _completionTimes
            .map((d) => d.inSeconds)
            .reduce((a, b) => a + b) / _completionTimes.length;
    
    return {
      'activeOperations': activeOps,
      'completedOperations': completedOps,
      'totalOperations': _operations.length,
      'averageCompletionTime': avgCompletionTime != null
          ? '${avgCompletionTime.toStringAsFixed(1)}s'
          : 'N/A',
      'historicalSamples': _completionTimes.length,
      'currentProgress': getCurrentProgress().progressPercentage,
    };
  }
  
  /// Reset tracker
  void reset() {
    _operations.clear();
    _completionTimes.clear();
    _syncStartTime = null;
    _lastProgress = 0.0;
    _lastProgressTime = DateTime.now();
    
    _updateProgress();
    
    if (kDebugMode) {
      print('Progress tracker reset');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _progressController.close();
    _operationsController.close();
    _errorController.close();
  }
}