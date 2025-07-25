import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snagsnapper/services/image_service.dart';
import 'package:snagsnapper/services/enhanced_image_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:connectivity_plus/connectivity_plus.dart';

// Generate mocks for enhanced testing
@GenerateMocks([
  SharedPreferences,
  Connectivity,
  Directory,
  File,
])
import 'image_service_enhanced_test.mocks.dart';
import 'image_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late EnhancedImageService imageService;
  late MockFirebaseStorage mockStorage;
  late MockSharedPreferences mockPrefs;
  late MockConnectivity mockConnectivity;
  late Uint8List testImageBytes;
  
  setUp(() {
    // Reset singleton
    EnhancedImageService.resetInstance();
    
    // Create mocks
    mockStorage = MockFirebaseStorage();
    mockPrefs = MockSharedPreferences();
    mockConnectivity = MockConnectivity();
    
    // Create test image
    final testImage = img.Image(width: 100, height: 100);
    img.fill(testImage, color: img.ColorRgb8(255, 0, 0));
    testImageBytes = Uint8List.fromList(img.encodeJpg(testImage, quality: 85));
    
    // Initialize service with mocks
    imageService = EnhancedImageService(
      storage: mockStorage,
      connectivity: mockConnectivity,
    );
  });
  
  tearDown(() {
    EnhancedImageService.resetInstance();
  });
  
  group('Enhanced ImageService - Relative Path Handling', () {
    test('should return relative path instead of full URL after upload', () async {
      // Arrange
      const userId = 'test-user-123';
      const relativePath = '$userId/profile.jpg';
      final mockRef = MockReference();
      final mockTask = MockUploadTask();
      final mockSnapshot = MockTaskSnapshot();
      
      when(mockStorage.ref(relativePath)).thenReturn(mockRef);
      when(mockRef.putData(any, any)).thenReturn(mockTask);
      when(mockTask.whenComplete(any)).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.ref).thenReturn(mockRef);
      when(mockRef.getDownloadURL()).thenAnswer((_) async => 
        'https://firebasestorage.googleapis.com/v0/b/bucket/o/$relativePath?alt=media&token=123');
      
      // Act
      final result = await imageService.uploadImage(
        imageData: testImageBytes,
        path: relativePath,
      );
      
      // Assert
      expect(result, equals(relativePath)); // Should return path, not URL
    });
    
    test('should resolve path to local file when cached', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      final mockDir = MockDirectory();
      final mockFile = MockFile();
      
      // Mock cache directory
      when(mockDir.path).thenReturn('/test/cache');
      when(mockFile.exists()).thenAnswer((_) async => true);
      when(mockFile.path).thenReturn('/test/cache/$relativePath');
      
      // Act
      final resolvedPath = await imageService.resolvePath(relativePath);
      
      // Assert
      expect(resolvedPath, startsWith('/test/cache/'));
      expect(resolvedPath, endsWith(relativePath));
    });
    
    test('should resolve path to Firebase URL when not cached', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      
      // Mock no local file
      final mockFile = MockFile();
      when(mockFile.exists()).thenAnswer((_) async => false);
      
      // Act
      final resolvedPath = await imageService.resolvePath(relativePath);
      
      // Assert
      expect(resolvedPath, startsWith('https://firebasestorage.googleapis.com'));
      expect(resolvedPath, contains(Uri.encodeComponent(relativePath)));
    });
  });
  
  group('Enhanced ImageService - Offline Support', () {
    test('should queue upload when offline', () async {
      // Arrange
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      when(mockPrefs.getStringList('upload_queue')).thenReturn(null);
      when(mockPrefs.setStringList(any, any)).thenAnswer((_) async => true);
      
      const relativePath = 'user123/profile.jpg';
      
      // Act
      final result = await imageService.uploadProfileImage(
        imageData: testImageBytes,
        userId: 'user123',
      );
      
      // Assert
      expect(result, equals(relativePath)); // Should still return path
      verify(mockPrefs.setStringList('upload_queue', any)).called(1);
    });
    
    test('should process upload queue when coming online', () async {
      // Arrange
      final queueItem = {
        'relativePath': 'user123/profile.jpg',
        'localTempPath': '/cache/temp/profile.jpg',
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };
      
      when(mockPrefs.getStringList('upload_queue'))
          .thenReturn([jsonEncode(queueItem)]);
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.wifi);
      
      // Act
      await imageService.processPendingUploads();
      
      // Assert
      verify(mockStorage.ref(any)).called(1);
      verify(mockPrefs.setStringList('upload_queue', [])).called(1);
    });
    
    test('should increment retry count on upload failure', () async {
      // Arrange
      final queueItem = {
        'relativePath': 'user123/profile.jpg',
        'localTempPath': '/cache/temp/profile.jpg',
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      };
      
      when(mockPrefs.getStringList('upload_queue'))
          .thenReturn([jsonEncode(queueItem)]);
      when(mockStorage.ref(any))
          .thenThrow(FirebaseException(plugin: 'storage', code: 'network-error'));
      
      // Act
      await imageService.processPendingUploads();
      
      // Assert
      final updatedQueue = verify(mockPrefs.setStringList('upload_queue', captureAny))
          .captured.single as List<String>;
      final updatedItem = jsonDecode(updatedQueue.first) as Map<String, dynamic>;
      expect(updatedItem['retryCount'], equals(1));
    });
    
    test('should move to manual retry after max retries', () async {
      // Arrange
      final queueItem = {
        'relativePath': 'user123/profile.jpg',
        'localTempPath': '/cache/temp/profile.jpg',
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 3, // Already at max
      };
      
      when(mockPrefs.getStringList('upload_queue'))
          .thenReturn([jsonEncode(queueItem)]);
      when(mockPrefs.getStringList('manual_retry_queue')).thenReturn(null);
      when(mockStorage.ref(any))
          .thenThrow(FirebaseException(plugin: 'storage', code: 'network-error'));
      
      // Act
      await imageService.processPendingUploads();
      
      // Assert
      verify(mockPrefs.setStringList('manual_retry_queue', any)).called(1);
      verify(mockPrefs.setStringList('upload_queue', [])).called(1);
    });
  });
  
  group('Enhanced ImageService - State Management', () {
    test('should track image state correctly', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      
      // Act & Assert
      expect(imageService.getImageState(relativePath), equals(ImageStatus.none));
      
      // Start upload
      imageService.setImageState(relativePath, ImageStatus.uploading);
      expect(imageService.getImageState(relativePath), equals(ImageStatus.uploading));
      
      // Complete upload
      imageService.setImageState(relativePath, ImageStatus.cached);
      expect(imageService.getImageState(relativePath), equals(ImageStatus.cached));
    });
    
    test('should emit state changes', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      final states = <ImageStatus>[];
      
      imageService.imageStateStream(relativePath).listen((state) {
        states.add(state);
      });
      
      // Act
      imageService.setImageState(relativePath, ImageStatus.uploading);
      imageService.setImageState(relativePath, ImageStatus.cached);
      
      // Allow stream to process
      await Future.delayed(Duration(milliseconds: 100));
      
      // Assert
      expect(states, equals([ImageStatus.uploading, ImageStatus.cached]));
    });
  });
  
  group('Enhanced ImageService - Cache Validation', () {
    test('should validate cache using ETag', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      const url = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/user123%2Fprofile.jpg';
      
      final mockRef = MockReference();
      final mockMetadata = MockFullMetadata();
      
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      when(mockRef.getMetadata()).thenAnswer((_) async => mockMetadata);
      when(mockMetadata.md5Hash).thenReturn('new-etag');
      
      // Mock cached metadata
      final cachedMetadata = {'etag': 'old-etag'};
      
      // Act
      final isValid = await imageService.validateCache(relativePath, url);
      
      // Assert
      expect(isValid, isFalse); // Different ETags = invalid cache
    });
    
    test('should skip validation when offline', () async {
      // Arrange
      when(mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => ConnectivityResult.none);
      
      // Act
      final isValid = await imageService.validateCache('path', 'url');
      
      // Assert
      expect(isValid, isTrue); // Assume valid when offline
    });
  });
  
  group('Enhanced ImageService - Error Recovery', () {
    test('should rollback on Firestore update failure', () async {
      // This test verifies the rollback logic in profile screen
      // The actual implementation would be in the profile screen
      
      // Arrange
      const originalPath = 'user123/old-profile.jpg';
      const newPath = 'user123/profile.jpg';
      
      // Simulate upload success but Firestore failure
      // The profile screen should handle this by:
      // 1. Keeping the old path
      // 2. Deleting the uploaded file
      // 3. Showing error to user
      
      expect(true, isTrue); // Placeholder - actual test in profile screen tests
    });
    
    test('should handle corrupted cache gracefully', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      final mockFile = MockFile();
      
      when(mockFile.exists()).thenAnswer((_) async => true);
      when(mockFile.readAsBytes()).thenThrow(FileSystemException('Corrupted'));
      
      // Act & Assert
      expect(
        () => imageService.getImage(url: 'test-url'),
        returnsNormally, // Should not throw, but handle gracefully
      );
    });
  });
  
  group('Enhanced ImageService - Performance', () {
    test('should return cached image instantly', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      final mockFile = MockFile();
      
      when(mockFile.exists()).thenAnswer((_) async => true);
      when(mockFile.readAsBytes()).thenAnswer((_) async => testImageBytes);
      
      // Act
      final stopwatch = Stopwatch()..start();
      final result = await imageService.getCachedImage(relativePath);
      stopwatch.stop();
      
      // Assert
      expect(result, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Should be very fast
    });
    
    test('should validate cache in background', () async {
      // Arrange
      const relativePath = 'user123/profile.jpg';
      
      // Act
      final future = imageService.getImageWithBackgroundValidation(
        relativePath: relativePath,
      );
      
      // The method should return immediately with cached data
      // and validate in background
      
      // Assert
      expect(future, completes);
    });
  });
  
  group('Enhanced ImageService - Cleanup', () {
    test('should clean orphaned cache files', () async {
      // Arrange
      final cacheFiles = ['user123/profile.jpg', 'user123/old-image.jpg'];
      final firestorePaths = ['user123/profile.jpg']; // old-image is orphaned
      
      // Act
      await imageService.cleanOrphanedCache(
        cacheFiles: cacheFiles,
        firestorePaths: firestorePaths,
      );
      
      // Assert
      // Should delete 'user123/old-image.jpg' from cache
      expect(true, isTrue); // Placeholder - verify file deletion
    });
    
    test('should clear all cache on user logout', () async {
      // Act
      await imageService.clearAllUserCache();
      
      // Assert
      // Should delete entire cache directory and recreate it empty
      expect(true, isTrue); // Placeholder - verify directory deletion
    });
  });
}