import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';

/// Event bus for sync-related notifications
/// 
/// Provides a communication channel between the GlobalSyncManager
/// (which runs without UI context) and UI components that need
/// to display sync status and errors.
/// 
/// This implements a simple pub-sub pattern for sync events.
class SyncEventBus {
  // Private constructors to prevent instantiation
  SyncEventBus._();
  
  // Stream controllers for different event types
  static final _errorController = StreamController<String>.broadcast();
  static final _statusController = StreamController<SyncStatus>.broadcast();
  static final _progressController = StreamController<double>.broadcast();
  static final _messageController = StreamController<String>.broadcast();
  
  // Public streams for subscribers
  static Stream<String> get errorStream => _errorController.stream;
  static Stream<SyncStatus> get statusStream => _statusController.stream;
  static Stream<double> get progressStream => _progressController.stream;
  static Stream<String> get messageStream => _messageController.stream;
  
  // Track if disposed to prevent usage after disposal
  static bool _isDisposed = false;
  
  /// Notify subscribers of a sync error
  /// @param message The error message to display to the user
  static void notifyError(String message) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('SyncEventBus: Error notification - $message');
    }
    
    if (!_errorController.isClosed) {
      _errorController.add(message);
    }
  }
  
  /// Notify subscribers of sync status change
  /// @param status The new sync status
  static void notifyStatus(SyncStatus status) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('SyncEventBus: Status change - $status');
    }
    
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }
  
  /// Notify subscribers of sync progress
  /// @param progress A value between 0.0 and 1.0
  static void notifyProgress(double progress) {
    if (_isDisposed) return;
    
    // Clamp progress between 0 and 1
    progress = progress.clamp(0.0, 1.0);
    
    if (kDebugMode && (progress == 0.0 || progress == 1.0 || progress % 0.25 == 0)) {
      print('SyncEventBus: Progress update - ${(progress * 100).toStringAsFixed(0)}%');
    }
    
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
  
  /// Notify subscribers of informational messages
  /// @param message The info message to display
  static void notifyMessage(String message) {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('SyncEventBus: Message - $message');
    }
    
    if (!_messageController.isClosed) {
      _messageController.add(message);
    }
  }
  
  /// Check if there are any active listeners for errors
  static bool get hasErrorListeners => _errorController.hasListener;
  
  /// Check if there are any active listeners for status
  static bool get hasStatusListeners => _statusController.hasListener;
  
  /// Check if there are any active listeners for progress
  static bool get hasProgressListeners => _progressController.hasListener;
  
  /// Check if there are any active listeners for messages
  static bool get hasMessageListeners => _messageController.hasListener;
  
  /// Initialize the event bus
  /// Called automatically when first accessed, but can be called
  /// explicitly to ensure initialization
  static void initialize() {
    if (_isDisposed) {
      _isDisposed = false;
      if (kDebugMode) {
        print('SyncEventBus: Reinitialized after disposal');
      }
    } else {
      if (kDebugMode) {
        print('SyncEventBus: Already initialized');
      }
    }
  }
  
  /// Clean up resources
  /// Should be called when the app is terminating
  static void dispose() {
    if (_isDisposed) return;
    
    if (kDebugMode) {
      print('SyncEventBus: Disposing stream controllers');
    }
    
    // Close all stream controllers
    if (!_errorController.isClosed) _errorController.close();
    if (!_statusController.isClosed) _statusController.close();
    if (!_progressController.isClosed) _progressController.close();
    if (!_messageController.isClosed) _messageController.close();
    
    _isDisposed = true;
    
    if (kDebugMode) {
      print('SyncEventBus: Disposal complete');
    }
  }
  
  /// Reset the event bus
  /// Useful for testing or reinitializing after logout
  static void reset() {
    if (kDebugMode) {
      print('SyncEventBus: Resetting');
    }
    
    dispose();
    initialize();
  }
}