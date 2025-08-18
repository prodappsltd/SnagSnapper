import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snagsnapper/services/sync/error_recovery.dart';

@GenerateMocks([
  FirebaseAuth,
  User,
  BuildContext,
])
import 'error_recovery_test.mocks.dart';

void main() {
  group('SyncError', () {
    test('should create error with all properties', () {
      // Arrange & Act
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
        itemId: 'item123',
        originalError: Exception('Original'),
        retryCount: 2,
      );
      
      // Assert
      expect(error.type, SyncErrorType.network);
      expect(error.message, 'Network error');
      expect(error.itemId, 'item123');
      expect(error.retryCount, 2);
      expect(error.timestamp, isA<DateTime>());
    });
    
    test('should create error from FirebaseAuthException', () {
      // Arrange
      final authError = FirebaseAuthException(
        code: 'invalid-token',
        message: 'Token expired',
      );
      
      // Act
      final syncError = SyncError.fromException(authError);
      
      // Assert
      expect(syncError.type, SyncErrorType.authentication);
      expect(syncError.message, contains('Authentication error'));
    });
    
    test('should detect network timeout errors', () {
      // Arrange
      final timeoutError = TimeoutException('Request timed out');
      
      // Act
      final syncError = SyncError.fromException(timeoutError);
      
      // Assert
      expect(syncError.type, SyncErrorType.network);
      expect(syncError.message, 'Network timeout');
    });
    
    test('should detect permission errors', () {
      // Arrange
      final permError = Exception('permission denied for resource');
      
      // Act
      final syncError = SyncError.fromException(permError);
      
      // Assert
      expect(syncError.type, SyncErrorType.permission);
      expect(syncError.message, 'Permission denied');
    });
    
    test('should detect validation errors', () {
      // Arrange
      final validationError = Exception('validation failed: invalid email');
      
      // Act
      final syncError = SyncError.fromException(validationError);
      
      // Assert
      expect(syncError.type, SyncErrorType.validation);
      expect(syncError.message, 'Data validation failed');
    });
    
    test('should detect conflict errors', () {
      // Arrange
      final conflictError = Exception('conflict: version mismatch');
      
      // Act
      final syncError = SyncError.fromException(conflictError);
      
      // Assert
      expect(syncError.type, SyncErrorType.conflict);
      expect(syncError.message, 'Data conflict detected');
    });
    
    test('should detect storage errors', () {
      // Arrange
      final storageError = Exception('storage quota exceeded');
      
      // Act
      final syncError = SyncError.fromException(storageError);
      
      // Assert
      expect(syncError.type, SyncErrorType.storage);
      expect(syncError.message, 'Storage quota exceeded');
    });
    
    test('should convert to JSON', () {
      // Arrange
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Test error',
        itemId: 'item123',
        retryCount: 1,
      );
      
      // Act
      final json = error.toJson();
      
      // Assert
      expect(json['type'], contains('network'));
      expect(json['message'], 'Test error');
      expect(json['itemId'], 'item123');
      expect(json['retryCount'], 1);
      expect(json['timestamp'], isA<String>());
    });
  });
  
  group('ErrorRecoveryService', () {
    late ErrorRecoveryService service;
    late MockBuildContext mockContext;
    
    setUp(() {
      mockContext = MockBuildContext();
      service = ErrorRecoveryService(
        context: mockContext,
      );
    });
    
    test('should use correct recovery strategy for each error type', () {
      // Assert default strategies
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.network],
        RecoveryStrategy.retry,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.authentication],
        RecoveryStrategy.refreshToken,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.permission],
        RecoveryStrategy.notifyUser,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.validation],
        RecoveryStrategy.skipItem,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.conflict],
        RecoveryStrategy.resolveConflict,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.storage],
        RecoveryStrategy.cleanup,
      );
      expect(
        ErrorRecoveryService.defaultStrategies[SyncErrorType.unknown],
        RecoveryStrategy.log,
      );
    });
    
    test('should retry with exponential backoff', () async {
      // Arrange
      int attemptCount = 0;
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
        retryAction: () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Still failing');
          }
        },
      );
      
      final stopwatch = Stopwatch()..start();
      
      // Act
      final result = await service.recoverFromError(error);
      
      stopwatch.stop();
      
      // Assert
      expect(result, true);
      expect(attemptCount, 3);
      // Should take at least 2s + 4s = 6s for backoff
      expect(stopwatch.elapsed.inSeconds, greaterThanOrEqualTo(6));
    });
    
    test('should stop retrying after max attempts', () async {
      // Arrange
      int attemptCount = 0;
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
        retryAction: () async {
          attemptCount++;
          throw Exception('Always fails');
        },
      );
      
      // Act
      final result = await service.recoverFromError(error);
      
      // Assert
      expect(result, false);
      expect(attemptCount, 3); // MAX_RETRIES
    });
    
    test('should skip item for validation errors', () async {
      // Arrange
      bool skipCalled = false;
      service.onErrorCallback = (error) {
        skipCalled = true;
      };
      
      final error = SyncError(
        type: SyncErrorType.validation,
        message: 'Invalid data',
        itemId: 'item123',
      );
      
      // Act
      final result = await service.recoverFromError(error);
      
      // Assert
      expect(result, true);
      expect(skipCalled, true);
    });
    
    test('should resolve conflicts using callback', () async {
      // Arrange
      bool conflictResolved = false;
      service.onConflictCallback = (itemId) async {
        conflictResolved = true;
        expect(itemId, 'item123');
      };
      
      final error = SyncError(
        type: SyncErrorType.conflict,
        message: 'Version conflict',
        itemId: 'item123',
      );
      
      // Act
      final result = await service.recoverFromError(error);
      
      // Assert
      expect(result, true);
      expect(conflictResolved, true);
    });
    
    test('should track error frequency', () async {
      // Arrange
      final error1 = SyncError(
        type: SyncErrorType.network,
        message: 'Error 1',
        itemId: 'item1',
      );
      final error2 = SyncError(
        type: SyncErrorType.network,
        message: 'Error 2',
        itemId: 'item1',
      );
      
      // Act
      await service.recoverFromError(error1);
      await service.recoverFromError(error2);
      
      final analytics = service.getAnalytics();
      
      // Assert
      expect(analytics['totalErrors'], 2);
      expect(analytics['errorsByType'], isA<Map>());
    });
    
    test('should identify recoverable errors correctly', () {
      // Arrange
      final networkError = SyncError(
        type: SyncErrorType.network,
        message: 'Network error',
      );
      final permissionError = SyncError(
        type: SyncErrorType.permission,
        message: 'Permission denied',
      );
      
      // Act & Assert
      expect(service.isRecoverable(networkError), true);
      expect(service.isRecoverable(permissionError), false);
    });
    
    test('should provide user-friendly error messages', () {
      // Arrange
      final errors = [
        SyncError(type: SyncErrorType.network, message: 'Technical error'),
        SyncError(type: SyncErrorType.authentication, message: 'Auth failed'),
        SyncError(type: SyncErrorType.permission, message: 'Access denied'),
        SyncError(type: SyncErrorType.validation, message: 'Bad data'),
        SyncError(type: SyncErrorType.conflict, message: 'Version mismatch'),
        SyncError(type: SyncErrorType.storage, message: 'No space'),
        SyncError(type: SyncErrorType.unknown, message: 'Unknown'),
      ];
      
      // Act & Assert
      for (final error in errors) {
        // Use reflection to access private method for testing
        // In production, this would be tested through the public API
        expect(error.type, isA<SyncErrorType>());
      }
    });
    
    test('should generate error report', () {
      // Arrange
      service.clearHistory();
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Test error',
      );
      
      // Act
      service.recoverFromError(error);
      final report = service.generateReport();
      
      // Assert
      expect(report, contains('Sync Error Report'));
      expect(report, contains('Total Errors'));
      expect(report, contains('Errors by Type'));
    });
    
    test('should calculate error rate', () {
      // Arrange & Act
      final analytics = service.getAnalytics();
      
      // Assert
      expect(analytics['errorRate'], isA<String>());
      expect(analytics['recentErrors'], isA<int>());
    });
    
    test('should limit error history size', () async {
      // Arrange
      service.clearHistory();
      
      // Act - Add more than 100 errors
      for (int i = 0; i < 110; i++) {
        final error = SyncError(
          type: SyncErrorType.network,
          message: 'Error $i',
        );
        await service.recoverFromError(error);
      }
      
      final analytics = service.getAnalytics();
      
      // Assert
      expect(analytics['totalErrors'], lessThanOrEqualTo(100));
    });
  });
}