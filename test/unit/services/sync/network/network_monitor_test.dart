import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:snagsnapper/services/sync/network_monitor.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

@GenerateMocks([
  Connectivity,
  SharedPreferences,
  http.Client,
])
import 'network_monitor_test.mocks.dart';

void main() {
  group('NetworkMonitor', () {
    late NetworkMonitor networkMonitor;
    late MockConnectivity mockConnectivity;
    late MockSharedPreferences mockPrefs;
    late MockClient mockHttpClient;

    setUp(() {
      mockConnectivity = MockConnectivity();
      mockPrefs = MockSharedPreferences();
      mockHttpClient = MockClient();

      networkMonitor = NetworkMonitor(
        connectivity: mockConnectivity,
        prefs: mockPrefs,
        httpClient: mockHttpClient,
      );
    });

    group('Connectivity Tests', () {
      test('should detect online state', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        final isOnline = await networkMonitor.isOnline();

        expect(isOnline, isTrue);
        verify(mockConnectivity.checkConnectivity()).called(1);
      });

      test('should detect offline state', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);

        final isOnline = await networkMonitor.isOnline();

        expect(isOnline, isFalse);
      });

      test('should detect connection type - WiFi', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        final connectionType = await networkMonitor.getConnectionType();

        expect(connectionType, equals(ConnectionType.wifi));
      });

      test('should detect connection type - Mobile', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);

        final connectionType = await networkMonitor.getConnectionType();

        expect(connectionType, equals(ConnectionType.mobile));
      });

      test('should detect connection type - Ethernet', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.ethernet]);

        final connectionType = await networkMonitor.getConnectionType();

        expect(connectionType, equals(ConnectionType.ethernet));
      });

      test('should assess connection quality', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        
        // Mock ping test
        when(mockHttpClient.get(Uri.parse('https://www.google.com')))
            .thenAnswer((_) async => http.Response('', 200));

        final hasGoodConnection = await networkMonitor.hasGoodConnection();

        expect(hasGoodConnection, isTrue);
      });

      test('should detect poor connection quality', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        
        // Mock slow ping test
        when(mockHttpClient.get(argThat(isA<Uri>())))
            .thenAnswer((_) async {
              await Future.delayed(Duration(seconds: 3));
              return http.Response('', 200);
            });

        final hasGoodConnection = await networkMonitor.hasGoodConnection();

        expect(hasGoodConnection, isFalse);
      });
    });

    group('State Change Handling', () {
      test('should handle offline to online transition', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);

        final stateChanges = <ConnectivityResult>[];
        networkMonitor.connectivityStream.listen(stateChanges.add);

        // Start offline
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Go online
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(stateChanges, equals([
          ConnectivityResult.none,
          ConnectivityResult.wifi,
        ]));

        connectivityController.close();
      });

      test('should handle online to offline transition', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);

        final stateChanges = <ConnectivityResult>[];
        networkMonitor.connectivityStream.listen(stateChanges.add);

        // Start online
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Go offline
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(stateChanges, equals([
          ConnectivityResult.wifi,
          ConnectivityResult.none,
        ]));

        connectivityController.close();
      });

      test('should handle intermittent connection', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);

        final stateChanges = <ConnectivityResult>[];
        networkMonitor.connectivityStream.listen(stateChanges.add);

        // Simulate intermittent connection
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 50));
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 50));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 50));
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 50));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(stateChanges.length, equals(5));
        expect(stateChanges.last, equals(ConnectivityResult.wifi));

        connectivityController.close();
      });

      test('should debounce rapid state changes', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);

        final debouncedChanges = <ConnectivityResult>[];
        networkMonitor.debouncedConnectivityStream.listen(debouncedChanges.add);

        // Rapid changes
        connectivityController.add([ConnectivityResult.wifi]);
        connectivityController.add([ConnectivityResult.none]);
        connectivityController.add([ConnectivityResult.wifi]);
        connectivityController.add([ConnectivityResult.none]);
        connectivityController.add([ConnectivityResult.wifi]);
        
        // Wait for debounce
        await Future.delayed(Duration(milliseconds: 500));

        // Should only emit the last stable state
        expect(debouncedChanges.length, equals(1));
        expect(debouncedChanges.last, equals(ConnectivityResult.wifi));

        connectivityController.close();
      });
    });

    group('Auto-Sync Trigger Tests', () {
      test('should trigger on reconnect', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        // Go offline then online
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isTrue);

        connectivityController.close();
      });

      test('should respect WiFi-only setting', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('wifi_only_sync'))
            .thenReturn(true);

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        // Connect to mobile (should not trigger with WiFi-only)
        connectivityController.add([ConnectivityResult.mobile]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isFalse);

        // Connect to WiFi (should trigger)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isTrue);

        connectivityController.close();
      });

      test('should debounce rapid connection changes', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);

        int syncCount = 0;
        networkMonitor.setupAutoSync(() {
          syncCount++;
        });

        // Rapid offline/online changes
        connectivityController.add([ConnectivityResult.none]);
        connectivityController.add([ConnectivityResult.wifi]);
        connectivityController.add([ConnectivityResult.none]);
        connectivityController.add([ConnectivityResult.wifi]);
        connectivityController.add([ConnectivityResult.none]);
        connectivityController.add([ConnectivityResult.wifi]);

        await Future.delayed(Duration(milliseconds: 500));

        // Should only trigger once after debounce
        expect(syncCount, equals(1));

        connectivityController.close();
      });

      test('should handle queue processing on connect', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('has_pending_sync'))
            .thenReturn(true);

        bool queueProcessed = false;
        networkMonitor.onQueueProcess(() {
          queueProcessed = true;
        });

        networkMonitor.setupAutoSync(() {});

        // Come online
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(queueProcessed, isTrue);

        connectivityController.close();
      });

      test('should not trigger when sync in progress', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);

        int syncCount = 0;
        networkMonitor.setupAutoSync(() {
          syncCount++;
        });

        // Set sync in progress
        networkMonitor.setSyncInProgress(true);

        // Come online (should not trigger)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncCount, equals(0));

        // Clear sync in progress
        networkMonitor.setSyncInProgress(false);

        // Come online again (should trigger now)
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncCount, equals(1));

        connectivityController.close();
      });

      test('should not trigger when queue is empty', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('has_pending_sync'))
            .thenReturn(false);

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        networkMonitor.setQueueEmpty(true);

        // Come online (should not trigger with empty queue)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isFalse);

        connectivityController.close();
      });

      test('should respect user preferences', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(false); // Auto-sync disabled

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        // Come online (should not trigger with auto-sync disabled)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isFalse);

        connectivityController.close();
      });

      test('should respect battery optimization', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('battery_saver_mode'))
            .thenReturn(true);
        when(mockPrefs.getInt('battery_level'))
            .thenReturn(15); // Low battery

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        // Come online with low battery (should not trigger)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isFalse);

        // Simulate battery level increase
        when(mockPrefs.getInt('battery_level'))
            .thenReturn(50); // Adequate battery

        // Trigger connection change
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isTrue);

        connectivityController.close();
      });
    });

    group('Connection Quality Tests', () {
      test('should perform ping test', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(mockHttpClient.get(Uri.parse('https://www.google.com')))
            .thenAnswer((_) async => http.Response('', 200));

        final pingResult = await networkMonitor.pingTest();

        expect(pingResult.success, isTrue);
        expect(pingResult.latency, isNotNull);
        expect(pingResult.latency! < 1000, isTrue); // Less than 1 second
      });

      test('should estimate bandwidth', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        
        // Mock downloading a test file
        final testData = List.generate(1000000, (i) => i % 256); // 1MB
        when(mockHttpClient.get(Uri.parse('https://www.google.com/generate_204')))
            .thenAnswer((_) async {
              await Future.delayed(Duration(milliseconds: 100)); // Simulate download time
              return http.Response(String.fromCharCodes(testData), 200);
            });

        final bandwidth = await networkMonitor.estimateBandwidth();

        expect(bandwidth, isNotNull);
        expect(bandwidth! > 0, isTrue);
      });

      test('should measure latency', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        
        final latencies = <int>[];
        for (int i = 0; i < 3; i++) {
          when(mockHttpClient.get(argThat(isA<Uri>())))
              .thenAnswer((_) async {
                await Future.delayed(Duration(milliseconds: 50 + (i * 10)));
                return http.Response('', 200);
              });
          
          final latency = await networkMonitor.measureLatency();
          latencies.add(latency);
        }

        // Should get average latency
        expect(latencies.every((l) => l > 0 && l < 1000), isTrue);
      });

      test('should detect connection degradation', () async {
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        // Start with good connection
        when(mockHttpClient.get(argThat(isA<Uri>())))
            .thenAnswer((_) async => http.Response('', 200));
        
        final quality1 = await networkMonitor.getConnectionQuality();
        expect(quality1, equals(ConnectionQuality.good));

        // Simulate degradation
        when(mockHttpClient.get(argThat(isA<Uri>())))
            .thenAnswer((_) async {
              await Future.delayed(Duration(seconds: 2));
              return http.Response('', 200);
            });
        
        final quality2 = await networkMonitor.getConnectionQuality();
        expect(quality2, equals(ConnectionQuality.poor));

        // Simulate timeout
        when(mockHttpClient.get(argThat(isA<Uri>())))
            .thenThrow(TimeoutException('Connection timeout'));
        
        final quality3 = await networkMonitor.getConnectionQuality();
        expect(quality3, equals(ConnectionQuality.none));
      });
    });

    group('Auto-Sync Control', () {
      test('should pause auto-sync', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        networkMonitor.pauseAutoSync();

        // Come online (should not trigger when paused)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isFalse);

        connectivityController.close();
      });

      test('should resume auto-sync', () async {
        final connectivityController = StreamController<List<ConnectivityResult>>();
        when(mockConnectivity.onConnectivityChanged)
            .thenAnswer((_) => connectivityController.stream);
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);

        bool syncTriggered = false;
        networkMonitor.setupAutoSync(() {
          syncTriggered = true;
        });

        networkMonitor.pauseAutoSync();
        
        // Come online while paused (should not trigger)
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        expect(syncTriggered, isFalse);

        networkMonitor.resumeAutoSync();
        
        // Trigger connection change after resume
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));

        expect(syncTriggered, isTrue);

        connectivityController.close();
      });

      test('should check if auto-sync should run', () async {
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('wifi_only_sync'))
            .thenReturn(false);
        when(mockPrefs.getBool('has_pending_sync'))
            .thenReturn(true);
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);

        final shouldSync = await networkMonitor.shouldAutoSync();

        expect(shouldSync, isTrue);
      });

      test('should not auto-sync with restrictions', () async {
        // Test various restriction scenarios
        
        // Scenario 1: Auto-sync disabled
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(false);
        expect(await networkMonitor.shouldAutoSync(), isFalse);

        // Scenario 2: WiFi-only with mobile connection
        when(mockPrefs.getBool('auto_sync_enabled'))
            .thenReturn(true);
        when(mockPrefs.getBool('wifi_only_sync'))
            .thenReturn(true);
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        expect(await networkMonitor.shouldAutoSync(), isFalse);

        // Scenario 3: No pending sync
        when(mockPrefs.getBool('wifi_only_sync'))
            .thenReturn(false);
        when(mockPrefs.getBool('has_pending_sync'))
            .thenReturn(false);
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        expect(await networkMonitor.shouldAutoSync(), isFalse);

        // Scenario 4: Offline
        when(mockPrefs.getBool('has_pending_sync'))
            .thenReturn(true);
        when(mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
        expect(await networkMonitor.shouldAutoSync(), isFalse);
      });
    });
  });
}