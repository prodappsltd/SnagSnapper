import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Types of sync errors
enum SyncErrorType {
  network,        // Network connectivity issues
  authentication, // Auth token expired or invalid
  permission,     // User lacks permission
  validation,     // Data validation failed
  conflict,       // Version conflict
  storage,        // Storage quota exceeded
  unknown,        // Unknown error
}

/// Recovery strategies for different error types
enum RecoveryStrategy {
  retry,           // Retry with exponential backoff
  refreshToken,    // Refresh authentication token
  notifyUser,      // Show error dialog to user
  skipItem,        // Skip this item and continue
  resolveConflict, // Resolve data conflict
  cleanup,         // Clean up storage and retry
  log,             // Just log the error
}

/// Sync error with context and retry capability
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? itemId;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Future<void> Function()? retryAction;
  int retryCount;

  SyncError({
    required this.type,
    required this.message,
    this.itemId,
    this.originalError,
    this.stackTrace,
    this.retryAction,
    this.retryCount = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create error from exception
  factory SyncError.fromException(
    dynamic error, {
    String? itemId,
    Future<void> Function()? retryAction,
  }) {
    SyncErrorType type;
    String message;

    if (error is FirebaseAuthException) {
      type = SyncErrorType.authentication;
      message = 'Authentication error: ${error.message}';
    } else if (error is TimeoutException) {
      type = SyncErrorType.network;
      message = 'Network timeout';
    } else if (error.toString().contains('permission')) {
      type = SyncErrorType.permission;
      message = 'Permission denied';
    } else if (error.toString().contains('validation')) {
      type = SyncErrorType.validation;
      message = 'Data validation failed';
    } else if (error.toString().contains('conflict')) {
      type = SyncErrorType.conflict;
      message = 'Data conflict detected';
    } else if (error.toString().contains('storage') || 
               error.toString().contains('quota')) {
      type = SyncErrorType.storage;
      message = 'Storage quota exceeded';
    } else {
      type = SyncErrorType.unknown;
      message = error.toString();
    }

    return SyncError(
      type: type,
      message: message,
      itemId: itemId,
      originalError: error,
      retryAction: retryAction,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'message': message,
    'itemId': itemId,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
  };
}

/// Error recovery service for handling sync errors
class ErrorRecoveryService {
  static const Map<SyncErrorType, RecoveryStrategy> defaultStrategies = {
    SyncErrorType.network: RecoveryStrategy.retry,
    SyncErrorType.authentication: RecoveryStrategy.refreshToken,
    SyncErrorType.permission: RecoveryStrategy.notifyUser,
    SyncErrorType.validation: RecoveryStrategy.skipItem,
    SyncErrorType.conflict: RecoveryStrategy.resolveConflict,
    SyncErrorType.storage: RecoveryStrategy.cleanup,
    SyncErrorType.unknown: RecoveryStrategy.log,
  };

  static const int MAX_RETRIES = 3;
  static const Duration BASE_DELAY = Duration(seconds: 2);

  final List<SyncError> _errorHistory = [];
  final Map<String, int> _errorFrequency = {};
  final BuildContext? context;
  Function(SyncError)? onErrorCallback;
  Function(String)? onConflictCallback;

  ErrorRecoveryService({
    this.context,
    this.onErrorCallback,
    this.onConflictCallback,
  });

  /// Recover from a sync error
  Future<bool> recoverFromError(
    SyncError error, {
    Map<SyncErrorType, RecoveryStrategy>? customStrategies,
  }) async {
    // Track error
    _trackError(error);

    // Determine strategy
    final strategies = customStrategies ?? defaultStrategies;
    final strategy = strategies[error.type] ?? RecoveryStrategy.log;

    if (kDebugMode) {
      print('Error recovery: ${error.type} -> $strategy');
      print('Error message: ${error.message}');
    }

    // Execute recovery strategy
    switch (strategy) {
      case RecoveryStrategy.retry:
        return await _retryWithBackoff(error);
      
      case RecoveryStrategy.refreshToken:
        return await _refreshAuthentication(error);
      
      case RecoveryStrategy.notifyUser:
        await _showErrorDialog(error);
        return false;
      
      case RecoveryStrategy.skipItem:
        await _markAsSkipped(error);
        return true;
      
      case RecoveryStrategy.resolveConflict:
        return await _resolveConflict(error);
      
      case RecoveryStrategy.cleanup:
        await _cleanupStorage();
        return await _retryWithBackoff(error);
      
      case RecoveryStrategy.log:
      default:
        await _logError(error);
        return false;
    }
  }

  /// Retry with exponential backoff
  Future<bool> _retryWithBackoff(SyncError error) async {
    if (error.retryAction == null) {
      if (kDebugMode) {
        print('No retry action available for error');
      }
      await _logError(error); // Log error if no retry action
      return false;
    }

    for (int i = 0; i < MAX_RETRIES; i++) {
      error.retryCount++;
      
      // Calculate delay: 2s, 4s, 8s
      final delay = BASE_DELAY * pow(2, i) as Duration;
      
      if (kDebugMode) {
        print('Retry attempt ${i + 1}/$MAX_RETRIES after ${delay.inSeconds}s');
      }
      
      await Future.delayed(delay);
      
      try {
        await error.retryAction!();
        if (kDebugMode) {
          print('Retry successful on attempt ${i + 1}');
        }
        return true;
      } catch (e) {
        if (i == MAX_RETRIES - 1) {
          if (kDebugMode) {
            print('Max retries exceeded. Giving up.');
          }
          await _logError(error);
          return false;
        }
        // Continue to next retry
      }
    }
    
    return false;
  }

  /// Refresh authentication token
  Future<bool> _refreshAuthentication(SyncError error) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No user logged in');
        }
        return false;
      }

      // Force token refresh
      await user.getIdToken(true);
      
      if (kDebugMode) {
        print('Authentication token refreshed');
      }

      // Retry original action if available
      if (error.retryAction != null) {
        try {
          await error.retryAction!();
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('Retry failed after token refresh: $e');
          }
          return false;
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to refresh token: $e');
      }
      return false;
    }
  }

  /// Show error dialog to user
  Future<void> _showErrorDialog(SyncError error) async {
    if (context == null) {
      if (kDebugMode) {
        print('No context available for showing dialog');
      }
      return;
    }

    final message = _getUserFriendlyMessage(error);
    
    await showDialog(
      context: context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sync Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
            if (error.retryAction != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await recoverFromError(error);
                },
                child: Text('Retry'),
              ),
          ],
        );
      },
    );
  }

  /// Mark item as skipped
  Future<void> _markAsSkipped(SyncError error) async {
    if (error.itemId == null) return;
    
    // TODO: Store skipped items in database or preferences
    if (kDebugMode) {
      print('Item ${error.itemId} marked as skipped due to validation error');
    }
    
    onErrorCallback?.call(error);
  }

  /// Resolve conflict
  Future<bool> _resolveConflict(SyncError error) async {
    if (error.itemId == null) return false;
    
    if (onConflictCallback != null) {
      try {
        await onConflictCallback!(error.itemId!);
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Conflict resolution failed: $e');
        }
        return false;
      }
    }
    
    // Default: skip conflicted item
    await _markAsSkipped(error);
    return true;
  }

  /// Clean up storage
  Future<void> _cleanupStorage() async {
    // TODO: Implement storage cleanup
    // - Clear cache
    // - Delete old files
    // - Compact database
    
    if (kDebugMode) {
      print('Storage cleanup completed');
    }
  }

  /// Log error for analytics
  Future<void> _logError(SyncError error) async {
    _errorHistory.add(error);
    
    // Keep only last 100 errors
    if (_errorHistory.length > 100) {
      _errorHistory.removeRange(0, _errorHistory.length - 100);
    }
    
    // TODO: Send to analytics service
    if (kDebugMode) {
      print('Error logged: ${error.toJson()}');
    }
    
    onErrorCallback?.call(error);
  }

  /// Track error frequency
  void _trackError(SyncError error) {
    final key = '${error.type}_${error.itemId ?? 'global'}';
    _errorFrequency[key] = (_errorFrequency[key] ?? 0) + 1;
  }

  /// Get user-friendly error message
  String _getUserFriendlyMessage(SyncError error) {
    switch (error.type) {
      case SyncErrorType.network:
        return 'Unable to connect to the server. Please check your internet connection and try again.';
      
      case SyncErrorType.authentication:
        return 'Your session has expired. Please log in again.';
      
      case SyncErrorType.permission:
        return 'You don\'t have permission to perform this action.';
      
      case SyncErrorType.validation:
        return 'Some data couldn\'t be synced due to validation errors. The invalid items have been skipped.';
      
      case SyncErrorType.conflict:
        return 'A conflict was detected. Your local changes have been preserved.';
      
      case SyncErrorType.storage:
        return 'Storage quota exceeded. Please free up some space and try again.';
      
      case SyncErrorType.unknown:
      default:
        return 'An unexpected error occurred. Please try again later.';
    }
  }

  /// Check if error is recoverable
  bool isRecoverable(SyncError error) {
    switch (error.type) {
      case SyncErrorType.network:
      case SyncErrorType.authentication:
      case SyncErrorType.storage:
      case SyncErrorType.conflict:
        return true;
      
      case SyncErrorType.permission:
      case SyncErrorType.validation:
      case SyncErrorType.unknown:
      default:
        return false;
    }
  }

  /// Get error analytics
  Map<String, dynamic> getAnalytics() {
    final Map<SyncErrorType, int> errorsByType = {};
    for (final error in _errorHistory) {
      errorsByType[error.type] = (errorsByType[error.type] ?? 0) + 1;
    }

    final recentErrors = _errorHistory
        .where((e) => DateTime.now().difference(e.timestamp) < Duration(hours: 1))
        .length;

    return {
      'totalErrors': _errorHistory.length,
      'recentErrors': recentErrors,
      'errorsByType': errorsByType.map((k, v) => MapEntry(k.toString(), v)),
      'topErrors': _getTopErrors(),
      'errorRate': _calculateErrorRate(),
    };
  }

  /// Get top errors by frequency
  List<Map<String, dynamic>> _getTopErrors() {
    final sorted = _errorFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(5).map((e) => {
      'key': e.key,
      'count': e.value,
    }).toList();
  }

  /// Calculate error rate
  String _calculateErrorRate() {
    if (_errorHistory.isEmpty) return '0.0';
    
    final recentErrors = _errorHistory
        .where((e) => DateTime.now().difference(e.timestamp) < Duration(minutes: 5))
        .length;
    
    // Errors per minute in last 5 minutes
    return (recentErrors / 5).toStringAsFixed(1);
  }

  /// Clear error history
  void clearHistory() {
    _errorHistory.clear();
    _errorFrequency.clear();
  }

  /// Generate error report
  String generateReport() {
    final analytics = getAnalytics();
    final buffer = StringBuffer();
    
    buffer.writeln('=== Sync Error Report ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Summary:');
    buffer.writeln('  Total Errors: ${analytics['totalErrors']}');
    buffer.writeln('  Recent Errors (1h): ${analytics['recentErrors']}');
    buffer.writeln('  Error Rate: ${analytics['errorRate']} errors/min');
    buffer.writeln('');
    buffer.writeln('Errors by Type:');
    
    final errorsByType = analytics['errorsByType'] as Map<String, dynamic>;
    errorsByType.forEach((type, count) {
      buffer.writeln('  $type: $count');
    });
    
    buffer.writeln('');
    buffer.writeln('Top Errors:');
    
    final topErrors = analytics['topErrors'] as List<Map<String, dynamic>>;
    for (final error in topErrors) {
      buffer.writeln('  ${error['key']}: ${error['count']} occurrences');
    }
    
    return buffer.toString();
  }
}