import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/services/sync/progress_tracker.dart';

void main() {
  group('OperationProgress', () {
    test('should calculate progress correctly', () {
      // Arrange
      final operation = OperationProgress(
        id: 'op1',
        description: 'Test operation',
        totalSteps: 100,
        completedSteps: 25,
        startTime: DateTime.now(),
      );
      
      // Act & Assert
      expect(operation.progress, 0.25);
      expect(operation.isComplete, false);
    });
    
    test('should identify completed operations', () {
      // Arrange
      final operation = OperationProgress(
        id: 'op1',
        description: 'Test operation',
        totalSteps: 50,
        completedSteps: 50,
        startTime: DateTime.now(),
      );
      
      // Act & Assert
      expect(operation.isComplete, true);
      expect(operation.progress, 1.0);
    });
    
    test('should calculate elapsed time', () async {
      // Arrange
      final startTime = DateTime.now();
      final operation = OperationProgress(
        id: 'op1',
        description: 'Test operation',
        totalSteps: 100,
        startTime: startTime,
      );
      
      // Act
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      expect(operation.elapsedTime.inMilliseconds, greaterThanOrEqualTo(100));
    });
    
    test('should estimate remaining time', () {
      // Arrange
      final operation = OperationProgress(
        id: 'op1',
        description: 'Test operation',
        totalSteps: 100,
        completedSteps: 25,
        startTime: DateTime.now().subtract(Duration(seconds: 10)),
      );
      
      // Act
      final remaining = operation.remainingTime;
      
      // Assert
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThan(0));
    });
    
    test('should return null remaining time when complete', () {
      // Arrange
      final operation = OperationProgress(
        id: 'op1',
        description: 'Test operation',
        totalSteps: 100,
        completedSteps: 100,
        startTime: DateTime.now(),
      );
      
      // Act & Assert
      expect(operation.remainingTime, isNull);
    });
  });
  
  group('SyncProgress', () {
    test('should create idle progress', () {
      // Act
      final progress = SyncProgress.idle();
      
      // Assert
      expect(progress.isIdle, true);
      expect(progress.isComplete, false);
      expect(progress.isInProgress, false);
      expect(progress.overallProgress, 0.0);
    });
    
    test('should create complete progress', () {
      // Act
      final progress = SyncProgress.complete();
      
      // Assert
      expect(progress.isComplete, true);
      expect(progress.isIdle, true); // operationsCount is 0
      expect(progress.isInProgress, false);
      expect(progress.overallProgress, 1.0);
      expect(progress.currentOperation, 'Sync complete');
    });
    
    test('should calculate progress percentage', () {
      // Arrange
      final progress = SyncProgress(
        overallProgress: 0.456,
        operationsCount: 5,
      );
      
      // Act & Assert
      expect(progress.progressPercentage, '45.6%');
    });
    
    test('should provide correct status messages', () {
      // Arrange
      final idle = SyncProgress.idle();
      final complete = SyncProgress.complete();
      final inProgress = SyncProgress(
        overallProgress: 0.5,
        currentOperation: 'Uploading profile',
        operationsCount: 3,
      );
      
      // Act & Assert
      expect(idle.statusMessage, 'Ready to sync');
      expect(complete.statusMessage, 'Sync complete'); // Has currentOperation set
      expect(inProgress.statusMessage, 'Uploading profile');
    });
    
    test('should format time remaining text', () {
      // Arrange
      final progress1 = SyncProgress(
        overallProgress: 0.5,
        operationsCount: 2,
        estimatedTimeRemaining: Duration(seconds: 45),
      );
      final progress2 = SyncProgress(
        overallProgress: 0.3,
        operationsCount: 3,
        estimatedTimeRemaining: Duration(minutes: 5, seconds: 30),
      );
      final progress3 = SyncProgress(
        overallProgress: 0.1,
        operationsCount: 5,
        estimatedTimeRemaining: Duration(hours: 2, minutes: 15),
      );
      
      // Act & Assert
      expect(progress1.timeRemainingText, '45s remaining');
      expect(progress2.timeRemainingText, '5m remaining');
      expect(progress3.timeRemainingText, '2h 15m remaining');
    });
  });
  
  group('ProgressTracker', () {
    late ProgressTracker tracker;
    
    setUp(() {
      tracker = ProgressTracker.instance;
      tracker.reset();
    });
    
    test('should start and end sync tracking', () async {
      // Arrange
      final progressUpdates = <SyncProgress>[];
      final subscription = tracker.progressStream.listen(progressUpdates.add);
      
      // Act
      tracker.startSync();
      await Future.delayed(Duration(milliseconds: 50));
      tracker.endSync();
      await Future.delayed(Duration(milliseconds: 50));
      
      // Assert
      expect(progressUpdates.length, greaterThanOrEqualTo(2));
      expect(progressUpdates.last.isComplete, true);
      
      // Cleanup
      await subscription.cancel();
    });
    
    test('should track operation lifecycle', () async {
      // Arrange
      final progressUpdates = <SyncProgress>[];
      final operationUpdates = <String>[];
      final progressSub = tracker.progressStream.listen(progressUpdates.add);
      final operationSub = tracker.currentOperationStream.listen(operationUpdates.add);
      
      // Act
      tracker.startOperation('op1', 'Uploading profile', totalSteps: 100);
      await Future.delayed(Duration(milliseconds: 50));
      
      tracker.updateOperation('op1', 50);
      await Future.delayed(Duration(milliseconds: 50));
      
      tracker.completeOperation('op1');
      await Future.delayed(Duration(milliseconds: 50));
      
      // Assert
      expect(operationUpdates, contains('Uploading profile'));
      expect(progressUpdates.length, greaterThanOrEqualTo(3));
      
      // Cleanup
      await progressSub.cancel();
      await operationSub.cancel();
    });
    
    test('should handle multiple concurrent operations', () async {
      // Arrange
      tracker.startSync();
      
      // Act
      tracker.startOperation('op1', 'Operation 1', totalSteps: 100);
      tracker.startOperation('op2', 'Operation 2', totalSteps: 200);
      tracker.startOperation('op3', 'Operation 3', totalSteps: 50);
      
      tracker.updateOperation('op1', 50);
      tracker.updateOperation('op2', 100);
      tracker.updateOperation('op3', 25);
      
      final progress = tracker.getCurrentProgress();
      
      // Assert
      expect(progress.operationsCount, 3);
      // Total: 350 steps, completed: 175
      expect(progress.overallProgress, closeTo(0.5, 0.01));
    });
    
    test('should cancel operations', () {
      // Arrange
      tracker.startOperation('op1', 'Test op', totalSteps: 100);
      
      // Act
      tracker.cancelOperation('op1');
      final progress = tracker.getCurrentProgress();
      
      // Assert
      expect(progress.isIdle, true);
      expect(progress.operationsCount, 0);
    });
    
    test('should report errors', () async {
      // Arrange
      final errors = <String>[];
      final subscription = tracker.errorStream.listen(errors.add);
      
      // Act
      tracker.reportError('Test error 1');
      tracker.reportError('Test error 2');
      await Future.delayed(Duration(milliseconds: 50));
      
      // Assert
      expect(errors, contains('Test error 1'));
      expect(errors, contains('Test error 2'));
      
      // Cleanup
      await subscription.cancel();
    });
    
    test('should handle failed operations', () async {
      // Arrange
      final errors = <String>[];
      final subscription = tracker.errorStream.listen(errors.add);
      
      // Act
      tracker.startOperation('op1', 'Failing operation', totalSteps: 100);
      tracker.completeOperation('op1', success: false);
      await Future.delayed(Duration(milliseconds: 50));
      
      // Assert
      expect(errors, contains('Failed: Failing operation'));
      
      // Cleanup
      await subscription.cancel();
    });
    
    test('should estimate time remaining', () async {
      // Arrange
      tracker.startSync();
      tracker.startOperation('op1', 'Slow operation', totalSteps: 100);
      
      // Simulate progress over time
      for (int i = 1; i <= 5; i++) {
        await Future.delayed(Duration(milliseconds: 100));
        tracker.updateOperation('op1', i * 10);
      }
      
      // Act
      final progress = tracker.getCurrentProgress();
      
      // Assert
      expect(progress.estimatedTimeRemaining, isNotNull);
      expect(progress.estimatedTimeRemaining!.inMilliseconds, greaterThan(0));
    });
    
    test('should provide analytics', () {
      // Arrange
      tracker.startOperation('op1', 'Op 1', totalSteps: 100);
      tracker.updateOperation('op1', 50);
      tracker.startOperation('op2', 'Op 2', totalSteps: 100);
      tracker.completeOperation('op2');
      
      // Act
      final analytics = tracker.getAnalytics();
      
      // Assert
      expect(analytics['activeOperations'], 1);
      expect(analytics['completedOperations'], 1);
      expect(analytics['totalOperations'], 2);
      expect(analytics['currentProgress'], contains('%'));
    });
    
    test('should reset tracker state', () {
      // Arrange
      tracker.startSync();
      tracker.startOperation('op1', 'Test op', totalSteps: 100);
      tracker.updateOperation('op1', 50);
      
      // Act
      tracker.reset();
      final progress = tracker.getCurrentProgress();
      
      // Assert
      expect(progress.isIdle, true);
      expect(progress.operationsCount, 0);
      expect(progress.overallProgress, 0.0);
    });
    
    test('should handle operation time estimation', () {
      // Arrange
      final operation = OperationProgress(
        id: 'op1',
        description: 'Image upload',
        totalSteps: 100,
        completedSteps: 25,
        startTime: DateTime.now().subtract(Duration(seconds: 5)),
      );
      
      // Act
      final remaining = operation.remainingTime;
      
      // Assert
      expect(remaining, isNotNull);
      // 25% done in 5 seconds, so ~15 seconds remaining
      expect(remaining!.inSeconds, closeTo(15, 3));
    });
    
    test('should stream real-time updates', () async {
      // Arrange
      final completer = Completer<void>();
      int updateCount = 0;
      
      final subscription = tracker.progressStream.listen((progress) {
        updateCount++;
        if (updateCount >= 3) {
          completer.complete();
        }
      });
      
      // Act
      tracker.startSync();
      tracker.startOperation('op1', 'Test', totalSteps: 100);
      tracker.updateOperation('op1', 50);
      tracker.completeOperation('op1');
      
      // Wait for stream updates
      await completer.future.timeout(Duration(seconds: 1));
      
      // Assert
      expect(updateCount, greaterThanOrEqualTo(3));
      
      // Cleanup
      await subscription.cancel();
    });
  });
}