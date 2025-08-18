import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

enum ConnectionType {
  none,
  wifi,
  mobile,
  ethernet,
  other,
}

enum ConnectionQuality {
  none,
  poor,
  fair,
  good,
  excellent,
}

class PingResult {
  final bool success;
  final int? latency;
  final String? error;

  PingResult({required this.success, this.latency, this.error});
}

class NetworkMonitor {
  final Connectivity connectivity;
  final SharedPreferences prefs;
  final http.Client httpClient;
  
  final _connectivityController = StreamController<ConnectivityResult>.broadcast();
  final _debouncedController = BehaviorSubject<ConnectivityResult>();
  
  Timer? _debounceTimer;
  bool _syncInProgress = false;
  bool _queueEmpty = false;
  bool _autoSyncPaused = false;
  Function? _syncCallback;
  Function? _queueProcessCallback;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  NetworkMonitor({
    Connectivity? connectivity,
    SharedPreferences? prefs,
    http.Client? httpClient,
  })  : connectivity = connectivity ?? Connectivity(),
        prefs = prefs ?? SharedPreferences.getInstance() as SharedPreferences,
        httpClient = httpClient ?? http.Client() {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      // Handle list of connectivity results (API v6.0+)
      final result = _getBestConnection(results);
      _connectivityController.add(result);
      
      // Debounce connectivity changes
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _debouncedController.add(result);
        _checkAutoSync(result);
      });
    });
  }
  
  ConnectivityResult _getBestConnection(List<ConnectivityResult> results) {
    // Return the best available connection
    if (results.contains(ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    } else if (results.contains(ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    } else if (results.isNotEmpty) {
      return results.first;
    }
    return ConnectivityResult.none;
  }

  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;
  Stream<ConnectivityResult> get debouncedConnectivityStream => _debouncedController.stream;

  Future<bool> isOnline() async {
    final results = await connectivity.checkConnectivity();
    final result = _getBestConnection(results);
    return result != ConnectivityResult.none;
  }

  Future<ConnectionType> getConnectionType() async {
    final results = await connectivity.checkConnectivity();
    final result = _getBestConnection(results);
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.mobile:
        return ConnectionType.mobile;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.none:
        return ConnectionType.none;
      default:
        return ConnectionType.other;
    }
  }

  Future<bool> hasGoodConnection() async {
    final results = await connectivity.checkConnectivity();
    final result = _getBestConnection(results);
    if (result == ConnectivityResult.none) {
      return false;
    }

    // Perform a quick ping test
    try {
      final stopwatch = Stopwatch()..start();
      final response = await httpClient
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 2));
      stopwatch.stop();

      if (response.statusCode == 200 && stopwatch.elapsedMilliseconds < 1000) {
        return true;
      }
    } catch (e) {
      // Failed ping test
    }

    return false;
  }

  Future<PingResult> pingTest() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await httpClient
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return PingResult(
          success: true,
          latency: stopwatch.elapsedMilliseconds,
        );
      }
      return PingResult(success: false, error: 'Bad response');
    } catch (e) {
      return PingResult(success: false, error: e.toString());
    }
  }

  Future<double?> estimateBandwidth() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await httpClient
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (response.statusCode == 200 || response.statusCode == 204) {
        final bytes = response.contentLength ?? response.bodyBytes.length;
        final seconds = stopwatch.elapsedMilliseconds / 1000;
        return bytes / seconds; // bytes per second
      }
    } catch (e) {
      // Failed to estimate
    }
    return null;
  }

  Future<int> measureLatency() async {
    final ping = await pingTest();
    return ping.latency ?? 9999;
  }

  Future<ConnectionQuality> getConnectionQuality() async {
    final online = await isOnline();
    if (!online) {
      return ConnectionQuality.none;
    }

    final ping = await pingTest();
    if (!ping.success) {
      return ConnectionQuality.none;
    }

    final latency = ping.latency!;
    if (latency < 50) {
      return ConnectionQuality.excellent;
    } else if (latency < 150) {
      return ConnectionQuality.good;
    } else if (latency < 300) {
      return ConnectionQuality.fair;
    } else {
      return ConnectionQuality.poor;
    }
  }

  void setupAutoSync(Function syncCallback) {
    _syncCallback = syncCallback;
  }

  void onQueueProcess(Function queueCallback) {
    _queueProcessCallback = queueCallback;
  }

  void _checkAutoSync(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      return; // Offline
    }

    if (_autoSyncPaused || _syncInProgress) {
      return; // Paused or already syncing
    }

    final autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
    if (!autoSyncEnabled) {
      return;
    }

    final wifiOnly = prefs.getBool('wifi_only_sync') ?? false;
    if (wifiOnly && result != ConnectivityResult.wifi) {
      return; // WiFi-only mode but not on WiFi
    }

    // Check battery saver mode
    final batterySaver = prefs.getBool('battery_saver_mode') ?? false;
    if (batterySaver) {
      final batteryLevel = prefs.getInt('battery_level') ?? 100;
      if (batteryLevel < 20) {
        return; // Low battery
      }
    }

    // Check if there are items to sync
    final hasPending = prefs.getBool('has_pending_sync') ?? false;
    if (hasPending && !_queueEmpty) {
      // Process queue first
      _queueProcessCallback?.call();
    }

    // Trigger sync
    _syncCallback?.call();
  }

  void setSyncInProgress(bool inProgress) {
    _syncInProgress = inProgress;
  }

  void setQueueEmpty(bool empty) {
    _queueEmpty = empty;
  }

  void pauseAutoSync() {
    _autoSyncPaused = true;
  }

  void resumeAutoSync() {
    _autoSyncPaused = false;
  }

  Future<bool> shouldAutoSync() async {
    final autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
    if (!autoSyncEnabled) {
      return false;
    }

    final online = await isOnline();
    if (!online) {
      return false;
    }

    final wifiOnly = prefs.getBool('wifi_only_sync') ?? false;
    if (wifiOnly) {
      final connectionType = await getConnectionType();
      if (connectionType != ConnectionType.wifi) {
        return false;
      }
    }

    final hasPending = prefs.getBool('has_pending_sync') ?? false;
    return hasPending && !_queueEmpty;
  }

  // Test helper methods
  Future<void> simulateConnectivityChange(ConnectivityResult result) async {
    _connectivityController.add(result);
    _debouncedController.add(result);
    _checkAutoSync(result);
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _debouncedController.close();
  }
}