enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  pending,
  failed,
}

enum SyncErrorType {
  network,
  permission,
  validation,
  conflict,
  device,
  unknown,
}

class SyncError {
  final SyncErrorType type;
  final String message;
  final String? details;
  final DateTime timestamp;
  final bool isRecoverable;

  SyncError({
    required this.type,
    required this.message,
    this.details,
    DateTime? timestamp,
    bool? isRecoverable,
  }) : timestamp = timestamp ?? DateTime.now(),
        isRecoverable = isRecoverable ?? _getDefaultRecoverability(type);
  
  static bool _getDefaultRecoverability(SyncErrorType type) {
    switch (type) {
      case SyncErrorType.network:
        return true; // Network errors are typically recoverable
      case SyncErrorType.permission:
        return false; // Permission errors usually require user action
      case SyncErrorType.validation:
        return false; // Validation errors need data correction
      case SyncErrorType.conflict:
        return true; // Conflicts can be resolved
      case SyncErrorType.device:
        return false; // Device issues need user action
      case SyncErrorType.unknown:
        return true; // Try to recover from unknown errors
    }
  }
}