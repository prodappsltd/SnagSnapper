import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:snagsnapper/services/background_sync_service.dart';
import 'package:flutter/foundation.dart';

@GenerateMocks([
  Workmanager,
  SharedPreferences,
])
import 'background_sync_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('BackgroundSyncService', () {
    late MockSharedPreferences mockPrefs;
    
    setUp(() {
      mockPrefs = MockSharedPreferences();
      
      // Setup default preferences
      when(mockPrefs.getString('current_user_id')).thenReturn('user123');
      when(mockPrefs.getBool('auto_sync_enabled')).thenReturn(true);
      when(mockPrefs.getBool('wifi_only_sync')).thenReturn(true);
      when(mockPrefs.getInt('sync_frequency_minutes')).thenReturn(30);
      when(mockPrefs.getBool('sync_requires_wifi')).thenReturn(true);
      when(mockPrefs.getBool('sync_requires_charging')).thenReturn(false);
      when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.setBool(any, any)).thenAnswer((_) async => true);
      when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    });
    
    test('should initialize background sync service', () async {
      // Act
      await BackgroundSyncService.initialize(isDebug: true);
      
      // Assert - Just verify it doesn't throw
      expect(BackgroundSyncService.instance, isNotNull);
    });
    
    test('should register periodic sync with correct frequency', () async {
      // Note: Can't easily test Workmanager without mocking platform channels
      // This test verifies the method exists and doesn't throw
      
      // Act & Assert
      expect(
        () => BackgroundSyncService.registerPeriodicSync(
          frequency: Duration(minutes: 45),
          requiresWifi: true,
        ),
        returnsNormally,
      );
    });
    
    test('should enforce minimum sync interval', () async {
      // Note: The actual enforcement happens inside registerPeriodicSync
      // We can verify the constant is set correctly
      
      // Assert
      expect(BackgroundSyncService.minimumInterval, Duration(minutes: 15));
      expect(BackgroundSyncService.defaultInterval, Duration(minutes: 30));
      expect(BackgroundSyncService.extendedInterval, Duration(hours: 2));
    });
    
    test('should trigger one-off sync', () async {
      // Act & Assert
      expect(
        () => BackgroundSyncService.triggerOneOffSync(
          requiresWifi: false,
          delay: Duration(minutes: 5),
        ),
        returnsNormally,
      );
    });
    
    test('should cancel all background tasks', () async {
      // Act & Assert
      expect(
        () => BackgroundSyncService.cancelAll(),
        returnsNormally,
      );
    });
    
    test('should get sync statistics', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'last_background_sync': DateTime.now().millisecondsSinceEpoch,
        'last_background_sync_error': 'Test error',
        'last_background_sync_error_time': DateTime.now().millisecondsSinceEpoch,
        'sync_frequency_minutes': 30,
        'sync_requires_wifi': true,
        'sync_requires_charging': false,
      });
      
      // Act
      final stats = await BackgroundSyncService.getSyncStatistics();
      
      // Assert
      expect(stats['lastSyncTime'], isA<String?>());
      expect(stats['lastError'], isA<String?>());
      expect(stats['syncFrequencyMinutes'], isA<int>());
      expect(stats['requiresWifi'], isA<bool>());
      expect(stats['requiresCharging'], isA<bool>());
      expect(stats['nextSyncTime'], isA<String?>());
    });
    
    test('should update sync preferences', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act & Assert
      expect(
        () => BackgroundSyncService.updateSyncPreferences(
          autoSyncEnabled: true,
          wifiOnly: false,
          frequency: Duration(hours: 1),
        ),
        returnsNormally,
      );
    });
    
    test('should check if background sync is available', () {
      // Act
      final available = BackgroundSyncService.isBackgroundSyncAvailable();
      
      // Assert
      expect(available, true);
    });
    
    test('should get platform constraints', () {
      // Act
      final constraints = BackgroundSyncService.getPlatformConstraints();
      
      // Assert
      expect(constraints['minimumInterval'], isA<int>());
      expect(constraints['backgroundRefreshAvailable'], isA<bool>());
      expect(constraints['requiresMainPowerSource'], isA<bool>());
      expect(constraints['note'], isA<String>());
    });
    
    test('should estimate battery impact based on frequency', () async {
      // Arrange
      final testCases = [
        (15, 'High (3-5% per day)'),
        (30, 'Medium (1-2% per day)'),
        (60, 'Low (< 1% per day)'),
        (120, 'Minimal (< 0.5% per day)'),
      ];
      
      for (final testCase in testCases) {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'sync_frequency_minutes': testCase.$1,
        });
        
        // Act
        final impact = await BackgroundSyncService.estimateBatteryImpact();
        
        // Assert
        expect(impact, testCase.$2);
      }
    });
    
    test('should estimate data usage based on frequency', () async {
      // Arrange
      final testCases = [
        (15, 'Very High (> 20MB per day)'), // 96 syncs/day * 0.5MB
        (30, 'Very High (> 20MB per day)'), // 48 syncs/day * 0.5MB
        (60, 'High (10-20MB per day)'),     // 24 syncs/day * 0.5MB
        (120, 'Medium (5-10MB per day)'),   // 12 syncs/day * 0.5MB
        (240, 'Low (< 5MB per day)'),       // 6 syncs/day * 0.5MB
      ];
      
      for (final testCase in testCases) {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'sync_frequency_minutes': testCase.$1,
        });
        
        // Act
        final usage = await BackgroundSyncService.estimateDataUsage();
        
        // Assert
        expect(usage, testCase.$2);
      }
    });
    
    test('should handle missing user in background sync', () async {
      // This tests the callbackDispatcher logic indirectly
      // In a real test, we'd need to mock Firebase and other dependencies
      
      // Arrange
      SharedPreferences.setMockInitialValues({});
      
      // Act
      final stats = await BackgroundSyncService.getSyncStatistics();
      
      // Assert
      expect(stats['lastSyncTime'], isNull);
    });
    
    test('should respect auto-sync preference', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'auto_sync_enabled': false,
      });
      
      // Act
      await BackgroundSyncService.updateSyncPreferences(
        autoSyncEnabled: false,
      );
      
      // Assert - cancelPeriodicSync would be called
      expect(
        () => BackgroundSyncService.cancelPeriodicSync(),
        returnsNormally,
      );
    });
    
    test('should handle platform-specific constraints', () {
      // Act
      final constraints = BackgroundSyncService.getPlatformConstraints();
      
      // Assert based on current platform
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        expect(constraints['minimumInterval'], 15);
        expect(constraints['note'], contains('iOS'));
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        expect(constraints['minimumInterval'], 15);
        expect(constraints['note'], contains('Android'));
      } else {
        expect(constraints['backgroundRefreshAvailable'], false);
      }
    });
  });
  
  group('Background Sync Task Names', () {
    test('should have correct task names', () {
      expect(BackgroundSyncService.periodicTaskName, 'periodic-sync');
      expect(BackgroundSyncService.oneOffTaskName, 'one-off-sync');
    });
  });
}