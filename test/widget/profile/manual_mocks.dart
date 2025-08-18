import 'dart:async';
import 'package:mockito/mockito.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/image_storage_service.dart';
import 'package:snagsnapper/Data/models/sync_status.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:snagsnapper/Data/models/sync_queue_item.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Manual mock for SyncService
class MockSyncService extends Mock implements SyncService {
  final StreamController<SyncStatus> _statusController = 
      StreamController<SyncStatus>.broadcast();
  final StreamController<double> _progressController = 
      StreamController<double>.broadcast();
  final StreamController<SyncError> _errorController = 
      StreamController<SyncError>.broadcast();
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  
  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;
  
  @override
  Stream<double> get progressStream => _progressController.stream;
  
  @override
  Stream<SyncError> get errorStream => _errorController.stream;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  bool get isSyncing => _isSyncing;
  
  @override
  Future<void> initialize(String userId) async {
    _isInitialized = true;
  }
  
  @override
  Future<SyncResult> syncNow() async {
    return super.noSuchMethod(
      Invocation.method(#syncNow, []),
      returnValue: Future.value(SyncResult.success()),
      returnValueForMissingStub: Future.value(SyncResult.success()),
    );
  }
  
  @override
  Future<bool> syncProfile(String userId) async {
    return super.noSuchMethod(
      Invocation.method(#syncProfile, [userId]),
      returnValue: Future.value(true),
      returnValueForMissingStub: Future.value(true),
    );
  }
  
  @override
  void setupAutoSync() {
    super.noSuchMethod(
      Invocation.method(#setupAutoSync, []),
      returnValueForMissingStub: null,
    );
  }
  
  @override
  void pauseSync() {
    super.noSuchMethod(
      Invocation.method(#pauseSync, []),
      returnValueForMissingStub: null,
    );
  }
  
  @override
  void resumeSync() {
    super.noSuchMethod(
      Invocation.method(#resumeSync, []),
      returnValueForMissingStub: null,
    );
  }
  
  @override
  Future<void> onAppForeground() async {
    super.noSuchMethod(
      Invocation.method(#onAppForeground, []),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }
  
  @override
  Future<QueueStatus> getQueueStatus() async {
    return super.noSuchMethod(
      Invocation.method(#getQueueStatus, []),
      returnValue: Future.value(QueueStatus(
        totalItems: 0,
        profileItems: 0,
        imageItems: 0,
        pendingItems: 0,
        syncingItems: 0,
        failedItems: 0,
        processedCount: 0,
      )),
      returnValueForMissingStub: Future.value(QueueStatus(
        totalItems: 0,
        profileItems: 0,
        imageItems: 0,
        pendingItems: 0,
        syncingItems: 0,
        failedItems: 0,
        processedCount: 0,
      )),
    );
  }
  
  @override
  Future<SyncResult> syncBatch(List<String> userIds) async {
    return super.noSuchMethod(
      Invocation.method(#syncBatch, [userIds]),
      returnValue: Future.value(SyncResult.success()),
      returnValueForMissingStub: Future.value(SyncResult.success()),
    );
  }
  
  @override
  Future<SyncStatus> checkSyncStatus(String userId) async {
    return super.noSuchMethod(
      Invocation.method(#checkSyncStatus, [userId]),
      returnValue: Future.value(SyncStatus.idle),
      returnValueForMissingStub: Future.value(SyncStatus.idle),
    );
  }
  
  // Helper methods for testing
  void emitStatus(SyncStatus status) {
    _statusController.add(status);
  }
  
  void emitProgress(double progress) {
    _progressController.add(progress);
  }
  
  void emitError(SyncError error) {
    _errorController.add(error);
  }
  
  void setIsSyncing(bool value) {
    _isSyncing = value;
  }
  
  void dispose() {
    _statusController.close();
    _progressController.close();
    _errorController.close();
  }
}

// Manual mock for ImageStorageService
class MockImageStorageService extends Mock implements ImageStorageService {
  @override
  Future<String> saveProfileImage(dynamic imageFile, String userId) async {
    return super.noSuchMethod(
      Invocation.method(#saveProfileImage, [imageFile, userId]),
      returnValue: Future.value('/path/to/image.jpg'),
      returnValueForMissingStub: Future.value('/path/to/image.jpg'),
    );
  }
  
  @override
  Future<String> saveSignature(dynamic signatureData, String userId) async {
    return super.noSuchMethod(
      Invocation.method(#saveSignature, [signatureData, userId]),
      returnValue: Future.value('/path/to/signature.png'),
      returnValueForMissingStub: Future.value('/path/to/signature.png'),
    );
  }
  
  @override
  Future<bool> deleteProfileImage(String userId) async {
    return super.noSuchMethod(
      Invocation.method(#deleteProfileImage, [userId]),
      returnValue: Future.value(true),
      returnValueForMissingStub: Future.value(true),
    );
  }
  
  @override
  Future<bool> deleteSignature(String userId) async {
    return super.noSuchMethod(
      Invocation.method(#deleteSignature, [userId]),
      returnValue: Future.value(true),
      returnValueForMissingStub: Future.value(true),
    );
  }
}

// Manual mock for Connectivity
class MockConnectivity extends Mock implements Connectivity {
  final StreamController<List<ConnectivityResult>> _connectivityController = 
      StreamController<List<ConnectivityResult>>.broadcast();
  
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => 
      _connectivityController.stream;
  
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return super.noSuchMethod(
      Invocation.method(#checkConnectivity, []),
      returnValue: Future.value([ConnectivityResult.wifi]),
      returnValueForMissingStub: Future.value([ConnectivityResult.wifi]),
    );
  }
  
  void emitConnectivity(List<ConnectivityResult> results) {
    _connectivityController.add(results);
  }
  
  void dispose() {
    _connectivityController.close();
  }
}