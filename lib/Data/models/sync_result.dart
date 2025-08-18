class SyncResult {
  final bool success;
  final String message;
  final List<String> syncedItems;
  final bool wasQueued;
  final bool wasCancelled;
  final bool requiresDeviceSwitch;
  final bool hasValidationErrors;
  final bool hasCorruption;
  final bool recoveryAttempted;
  final bool batchedOperations;
  final int firebaseReads;
  final int processed;
  final int succeeded;

  SyncResult({
    required this.success,
    this.message = '',
    this.syncedItems = const [],
    this.wasQueued = false,
    this.wasCancelled = false,
    this.requiresDeviceSwitch = false,
    this.hasValidationErrors = false,
    this.hasCorruption = false,
    this.recoveryAttempted = false,
    this.batchedOperations = false,
    this.firebaseReads = 0,
    this.processed = 0,
    this.succeeded = 0,
  });

  factory SyncResult.success({
    String message = 'Sync completed successfully',
    List<String> syncedItems = const [],
    int firebaseReads = 0,
  }) {
    return SyncResult(
      success: true,
      message: message,
      syncedItems: syncedItems,
      firebaseReads: firebaseReads,
    );
  }

  factory SyncResult.failure({
    required String message,
    bool wasQueued = false,
    bool requiresDeviceSwitch = false,
    bool hasValidationErrors = false,
  }) {
    return SyncResult(
      success: false,
      message: message,
      wasQueued: wasQueued,
      requiresDeviceSwitch: requiresDeviceSwitch,
      hasValidationErrors: hasValidationErrors,
    );
  }

  factory SyncResult.cancelled() {
    return SyncResult(
      success: false,
      message: 'Sync was cancelled',
      wasCancelled: true,
    );
  }
}