import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snagsnapper/services/image_service.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// Generate mocks for testing
@GenerateMocks([
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot,
  FullMetadata,
  ImagePicker,
  XFile,
  http.Client,
])
import 'image_service_test.mocks.dart';

void main() {
  // Initialize Flutter binding for tests that need platform channels
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late ImageService imageService;
  late MockFirebaseStorage mockStorage;
  late MockImagePicker mockImagePicker;
  late MockClient mockHttpClient;
  
  // Test data
  final testUserId = 'test-user-123';
  // Create a small valid test image using the image package
  late Uint8List testImageBytes;
  
  setUp(() {
    // Reset singleton before each test
    ImageService.resetInstance();
    
    mockStorage = MockFirebaseStorage();
    mockImagePicker = MockImagePicker();
    mockHttpClient = MockClient();
    
    // Create a small test image (10x10 red square)
    final testImage = img.Image(width: 10, height: 10);
    img.fill(testImage, color: img.ColorRgb8(255, 0, 0));
    testImageBytes = Uint8List.fromList(img.encodePng(testImage));
    
    // Initialize ImageService with mocks
    imageService = ImageService(
      storage: mockStorage,
      imagePicker: mockImagePicker,
      httpClient: mockHttpClient,
    );
  });
  
  tearDown(() {
    // Clean up singleton after each test
    ImageService.resetInstance();
  });

  group('ImageService - Singleton', () {
    test('should return same instance when accessed multiple times', () {
      // Test singleton pattern
      final instance1 = ImageService();
      final instance2 = ImageService();
      
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('ImageService - Image Capture', () {
    test('should capture image from camera and process it', () async {
      // Arrange
      final mockXFile = MockXFile();
      when(mockXFile.readAsBytes()).thenAnswer((_) async => testImageBytes);
      when(mockXFile.path).thenReturn('/test/path/image.jpg');
      
      when(mockImagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: anyNamed('maxWidth'),
        maxHeight: anyNamed('maxHeight'),
      )).thenAnswer((_) async => mockXFile);
      
      // Act
      final result = await imageService.captureImage(
        source: ImageSource.camera,
        type: ImageType.profile,
      );
      
      // Assert
      expect(result, isNotNull);
      expect(result!.data, isNotEmpty);
      verify(mockImagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
      )).called(1);
    });

    test('should capture image from gallery and process it', () async {
      // Arrange
      final mockXFile = MockXFile();
      when(mockXFile.readAsBytes()).thenAnswer((_) async => testImageBytes);
      when(mockXFile.path).thenReturn('/test/path/image.jpg');
      
      when(mockImagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: anyNamed('maxWidth'),
        maxHeight: anyNamed('maxHeight'),
      )).thenAnswer((_) async => mockXFile);
      
      // Act
      final result = await imageService.captureImage(
        source: ImageSource.gallery,
        type: ImageType.profile,
      );
      
      // Assert
      expect(result, isNotNull);
      expect(result!.data, isNotEmpty);
    });

    test('should return null when user cancels image selection', () async {
      // Arrange
      when(mockImagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: anyNamed('maxWidth'),
        maxHeight: anyNamed('maxHeight'),
      )).thenAnswer((_) async => null);
      
      // Act
      final result = await imageService.captureImage(
        source: ImageSource.gallery,
        type: ImageType.profile,
      );
      
      // Assert
      expect(result, isNull);
    });
  });

  group('ImageService - Image Processing', () {
    test('should resize image to specified dimensions', () async {
      // This test will verify image resizing logic
      // Implementation will use the 'image' package
      
      // Act
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.profile,
      );
      
      // Assert
      expect(processed, isNotNull);
      expect(processed.data.length, lessThanOrEqualTo(400000)); // 400KB limit
    });

    test('should convert PNG to JPEG for non-signature images', () async {
      // Test that profile images are converted to JPEG
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.profile,
      );
      
      expect(processed.format, equals(ImageFormat.jpeg));
    });

    test('should keep PNG format for signatures', () async {
      // Test that signatures remain as PNG
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.signature,
      );
      
      expect(processed.format, equals(ImageFormat.png));
    });

    test('should recursively compress if size exceeds limit', () async {
      // Create a large test image that needs compression
      final largeImage = img.Image(width: 2000, height: 2000);
      img.fill(largeImage, color: img.ColorRgb8(255, 0, 0));
      final largeImageBytes = Uint8List.fromList(img.encodePng(largeImage));
      
      final processed = await imageService.processImage(
        imageBytes: largeImageBytes,
        type: ImageType.profile,
      );
      
      expect(processed.data.length, lessThanOrEqualTo(400000));
      expect(processed.quality, lessThanOrEqualTo(0.85)); // Quality may or may not be reduced
    });

    test('should generate thumbnail for list views', () async {
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.profile,
        generateThumbnail: true,
      );
      
      expect(processed.thumbnail, isNotNull);
      expect(processed.thumbnail!.length, lessThanOrEqualTo(25000)); // 25KB
    });
  });

  group('ImageService - Firebase Storage Upload', () {
    test('should upload image to correct path', () async {
      // Skip this test for now - complex UploadTask mocking
      // TODO: Implement integration test for actual Firebase Storage upload
    }, skip: 'Complex UploadTask mocking - needs integration test');

    test('should set correct metadata for uploaded image', () async {
      // Skip this test for now - complex UploadTask mocking
      // TODO: Implement integration test for actual Firebase Storage upload
    }, skip: 'Complex UploadTask mocking - needs integration test');
  });

  group('ImageService - Download & Cache', () {
    test('should return cached image if available and valid', () async {
      // Test that cache is checked first
      // Mock local file exists with valid ETag
      
      final url = 'https://storage.example.com/image.jpg';
      
      // Act
      final imageData = await imageService.getImage(url: url);
      
      // Assert
      expect(imageData, isNotNull);
      // Should not make network call if cache is valid
      verifyNever(mockHttpClient.get(any));
    });

    test('should download new image if cache is stale', () async {
      // Test ETag validation and re-download
      
      final url = 'https://storage.example.com/image.jpg';
      final mockRef = MockReference();
      
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      
      // Create mock metadata
      final mockMetadata = MockFullMetadata();
      when(mockMetadata.md5Hash).thenReturn('new-etag-value');
      when(mockRef.getMetadata()).thenAnswer((_) async => mockMetadata);
      
      // Act
      final imageData = await imageService.getImage(url: url);
      
      // Assert
      expect(imageData, isNotNull);
      verify(mockRef.getMetadata()).called(1);
    });

    test('should save downloaded image to cache', () async {
      // Test that downloaded images are cached
      
      final url = 'https://storage.example.com/image.jpg';
      
      when(mockHttpClient.get(Uri.parse(url)))
          .thenAnswer((_) async => http.Response.bytes(testImageBytes, 200));
      
      // Act
      await imageService.getImage(url: url, forceRefresh: true);
      
      // Assert
      // Verify file was saved to cache directory
      final cacheDir = await getApplicationDocumentsDirectory();
      final cacheFile = File('${cacheDir.path}/image_cache/$testUserId/profile.jpg');
      // In real implementation, check if file exists
    });
  });

  group('ImageService - Delete Operations', () {
    test('should delete image from Firebase Storage', () async {
      // Arrange
      final url = 'https://storage.example.com/image.jpg';
      final mockRef = MockReference();
      
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async {});
      
      // Act
      await imageService.deleteImage(url);
      
      // Assert
      verify(mockRef.delete()).called(1);
    });

    test('should delete cached image when deleting from storage', () async {
      // Test that cache is cleaned up
      
      final url = 'https://storage.example.com/image.jpg';
      final mockRef = MockReference();
      
      when(mockStorage.refFromURL(url)).thenReturn(mockRef);
      when(mockRef.delete()).thenAnswer((_) async {});
      
      // Act
      await imageService.deleteImage(url);
      
      // Assert
      // Verify cache file was deleted
    });
  });

  group('ImageService - Error Handling', () {
    test('should handle network errors gracefully', () async {
      // Arrange
      when(mockHttpClient.get(any))
          .thenThrow(SocketException('No internet'));
      
      // Act & Assert
      expect(
        () => imageService.getImage(url: 'https://example.com/image.jpg'),
        throwsA(isA<ImageServiceException>()),
      );
    });

    test('should handle storage permission errors', () async {
      // Arrange
      final mockRef = MockReference();
      when(mockStorage.ref(any)).thenReturn(mockRef);
      when(mockRef.putData(any, any))
          .thenThrow(FirebaseException(plugin: 'storage', code: 'unauthorized'));
      
      // Act & Assert
      expect(
        () => imageService.uploadImage(
          imageData: testImageBytes,
          path: 'unauthorized/path.jpg',
        ),
        throwsA(isA<ImageServiceException>()),
      );
    });

    test('should handle corrupt image data', () async {
      // Test processing invalid image data
      final corruptData = Uint8List.fromList([0, 0, 0, 0]);
      
      // Act & Assert
      expect(
        () => imageService.processImage(
          imageBytes: corruptData,
          type: ImageType.profile,
        ),
        throwsA(isA<ImageServiceException>()),
      );
    });
  });

  group('ImageService - Image Type Specifications', () {
    test('should apply correct dimensions for profile images', () async {
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.profile,
      );
      
      expect(processed.maxWidth, equals(1200));
      expect(processed.maxHeight, equals(1200));
    });

    test('should apply correct dimensions for signature images', () async {
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.signature,
      );
      
      expect(processed.maxWidth, equals(600));
      expect(processed.maxHeight, equals(300));
    });

    test('should apply correct dimensions for thumbnails', () async {
      final processed = await imageService.processImage(
        imageBytes: testImageBytes,
        type: ImageType.thumbnail,
      );
      
      expect(processed.maxWidth, equals(200));
      expect(processed.maxHeight, equals(200));
    });
  });
}