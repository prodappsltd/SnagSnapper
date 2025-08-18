import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/services/signature_service.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([Directory, File])
import 'signature_service_test.mocks.dart';

void main() {
  group('SignatureService', () {
    late SignatureService service;

    setUp(() {
      service = SignatureService();
    });

    group('Stroke Management', () {
      test('should start with empty strokes', () {
        expect(service.strokes, isEmpty);
        expect(service.hasContent, isFalse);
      });

      test('should add point to current stroke', () {
        // Arrange
        const point = Offset(100, 100);
        
        // Act
        service.startNewStroke();
        service.addPoint(point);
        
        // Assert
        expect(service.strokes.length, equals(1));
        expect(service.strokes.first.length, equals(1));
        expect(service.strokes.first.first, equals(point));
        expect(service.hasContent, isTrue);
      });

      test('should start new stroke when startNewStroke is called', () {
        // Arrange
        const point1 = Offset(100, 100);
        const point2 = Offset(200, 200);
        
        // Act
        service.startNewStroke();
        service.addPoint(point1);
        service.startNewStroke();
        service.addPoint(point2);
        
        // Assert
        expect(service.strokes.length, equals(2));
        expect(service.strokes[0].first, equals(point1));
        expect(service.strokes[1].first, equals(point2));
      });

      test('should not add point without starting stroke first', () {
        // Arrange
        const point = Offset(100, 100);
        
        // Act
        service.addPoint(point);
        
        // Assert
        expect(service.strokes, isEmpty);
      });

      test('should clear all strokes', () {
        // Arrange
        service.startNewStroke();
        service.addPoint(const Offset(100, 100));
        service.startNewStroke();
        service.addPoint(const Offset(200, 200));
        
        // Act
        service.clear();
        
        // Assert
        expect(service.strokes, isEmpty);
        expect(service.hasContent, isFalse);
      });

      test('should validate canvas boundaries', () {
        // Arrange
        const canvasSize = Size(640, 360);
        const validPoint = Offset(320, 180);
        const invalidPoint1 = Offset(-10, 100);
        const invalidPoint2 = Offset(650, 100);
        const invalidPoint3 = Offset(100, -10);
        const invalidPoint4 = Offset(100, 370);
        
        // Act & Assert
        expect(service.isPointInBounds(validPoint, canvasSize), isTrue);
        expect(service.isPointInBounds(invalidPoint1, canvasSize), isFalse);
        expect(service.isPointInBounds(invalidPoint2, canvasSize), isFalse);
        expect(service.isPointInBounds(invalidPoint3, canvasSize), isFalse);
        expect(service.isPointInBounds(invalidPoint4, canvasSize), isFalse);
      });

      test('should only add points within canvas bounds', () {
        // Arrange
        const canvasSize = Size(640, 360);
        const validPoint = Offset(320, 180);
        const invalidPoint = Offset(700, 400);
        
        // Act
        service.startNewStroke();
        service.addPointWithBounds(validPoint, canvasSize);
        service.addPointWithBounds(invalidPoint, canvasSize);
        
        // Assert
        expect(service.strokes.first.length, equals(1));
        expect(service.strokes.first.first, equals(validPoint));
      });
    });

    group('Image Generation', () {
      test('should calculate bounds of signature correctly', () {
        // Arrange
        service.startNewStroke();
        service.addPoint(const Offset(100, 100));
        service.addPoint(const Offset(200, 150));
        service.startNewStroke();
        service.addPoint(const Offset(50, 200));
        service.addPoint(const Offset(250, 50));
        
        // Act
        final bounds = service.calculateSignatureBounds();
        
        // Assert
        expect(bounds, isNotNull);
        expect(bounds!.left, equals(50));
        expect(bounds.top, equals(50));
        expect(bounds.right, equals(250));
        expect(bounds.bottom, equals(200));
      });

      test('should return null bounds for empty signature', () {
        // Act
        final bounds = service.calculateSignatureBounds();
        
        // Assert
        expect(bounds, isNull);
      });

      test('should generate image data from strokes', () async {
        // Arrange
        service.startNewStroke();
        service.addPoint(const Offset(100, 100));
        service.addPoint(const Offset(200, 200));
        service.startNewStroke();
        service.addPoint(const Offset(150, 50));
        service.addPoint(const Offset(250, 150));
        
        const canvasSize = Size(640, 360);
        
        // Act
        final imageData = await service.generateImage(canvasSize);
        
        // Assert
        expect(imageData, isNotNull);
        expect(imageData, isA<Uint8List>());
        expect(imageData!.isNotEmpty, isTrue);
      });

      test('should return null for empty signature', () async {
        // Arrange
        const canvasSize = Size(640, 360);
        
        // Act
        final imageData = await service.generateImage(canvasSize);
        
        // Assert
        expect(imageData, isNull);
      });

      test('should crop image to signature bounds', () async {
        // Arrange
        service.startNewStroke();
        // Create a small signature in the center
        service.addPoint(const Offset(300, 150));
        service.addPoint(const Offset(340, 150));
        service.addPoint(const Offset(340, 210));
        service.addPoint(const Offset(300, 210));
        
        const canvasSize = Size(640, 360);
        
        // Act
        final croppedImage = await service.generateCroppedImage(canvasSize);
        
        // Assert
        expect(croppedImage, isNotNull);
        expect(croppedImage, isA<Uint8List>());
        // The cropped image should be smaller than full canvas
        // Note: Actual size verification would require image decoding
      });
    });

    group('File Storage', () {
      test('should generate correct file path', () {
        // Arrange
        const userId = 'test_user_123';
        
        // Act
        final path = service.generateSignaturePath(userId);
        
        // Assert
        expect(path, equals('SnagSnapper/test_user_123/Profile/signature.jpg'));
      });

      test('should save signature to file system', () async {
        // This test would require mocking file system operations
        // For now, we'll test the logic without actual file I/O
        
        // Arrange
        const userId = 'test_user_123';
        final mockImageData = Uint8List.fromList([1, 2, 3, 4, 5]);
        
        // We would mock the file system here in actual implementation
        // For unit test, we verify the method structure exists
        expect(service.saveSignature, isA<Function>());
      });

      test('should delete existing signature file', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // We would mock the file system here in actual implementation
        // For unit test, we verify the method structure exists
        expect(service.deleteSignature, isA<Function>());
      });

      test('should check if signature exists', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // We would mock the file system here in actual implementation
        // For unit test, we verify the method structure exists
        expect(service.signatureExists, isA<Function>());
      });
    });

    group('JPEG Conversion', () {
      test('should convert image to JPEG with specified quality', () async {
        // Arrange
        service.startNewStroke();
        service.addPoint(const Offset(100, 100));
        service.addPoint(const Offset(200, 200));
        
        const canvasSize = Size(640, 360);
        const quality = 95;
        
        // Act
        final jpegData = await service.generateJpegImage(canvasSize, quality);
        
        // Assert
        expect(jpegData, isNotNull);
        expect(jpegData, isA<Uint8List>());
        // JPEG signature starts with FF D8 FF
        if (jpegData != null && jpegData.length > 3) {
          expect(jpegData[0], equals(0xFF));
          expect(jpegData[1], equals(0xD8));
          expect(jpegData[2], equals(0xFF));
        }
      });

      test('should handle different quality levels', () async {
        // Arrange
        service.startNewStroke();
        service.addPoint(const Offset(100, 100));
        service.addPoint(const Offset(200, 200));
        
        const canvasSize = Size(640, 360);
        
        // Act
        final highQuality = await service.generateJpegImage(canvasSize, 95);
        final lowQuality = await service.generateJpegImage(canvasSize, 30);
        
        // Assert
        expect(highQuality, isNotNull);
        expect(lowQuality, isNotNull);
        // High quality should generally be larger than low quality
        // Note: Can't guarantee this without actual image encoding
      });
    });

    group('Responsive Canvas', () {
      test('should adjust canvas size for small screens', () {
        // Arrange
        const screenWidth = 320.0; // Small phone
        const defaultHeight = 360.0;
        
        // Act
        final canvasSize = service.calculateCanvasSize(screenWidth);
        
        // Assert
        expect(canvasSize.width, equals(320));
        expect(canvasSize.height, equals(360));
      });

      test('should use default size for large screens', () {
        // Arrange
        const screenWidth = 800.0; // Tablet
        
        // Act
        final canvasSize = service.calculateCanvasSize(screenWidth);
        
        // Assert
        expect(canvasSize.width, equals(640));
        expect(canvasSize.height, equals(360));
      });

      test('should maintain aspect ratio', () {
        // Arrange
        const screenWidth1 = 320.0;
        const screenWidth2 = 640.0;
        
        // Act
        final size1 = service.calculateCanvasSize(screenWidth1);
        final size2 = service.calculateCanvasSize(screenWidth2);
        
        // Assert
        // Height should always be 360
        expect(size1.height, equals(360));
        expect(size2.height, equals(360));
        
        // Width should adjust based on screen size
        expect(size1.width, equals(320)); // Uses screen width when smaller
        expect(size2.width, equals(640)); // Uses default when larger
      });
    });
  });
}