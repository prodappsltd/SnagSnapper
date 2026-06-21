import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:freerasp/freerasp.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Security service using freeRASP for Runtime Application Self-Protection (RASP)
///
/// Detects and reports:
/// - Root/Jailbreak detection
/// - Emulator/Simulator detection
/// - App cloning (Parallel Space, Dual Space, etc.)
/// - Debugging/Hooking attempts (Frida, etc.)
/// - App tampering
/// - Untrusted installation sources
///
/// Response types:
/// - log: Silent logging to Crashlytics only
/// - warn: Show dismissible warning dialog (once per install)
/// - block: Show non-dismissible dialog requiring app exit
class SecurityService {
  // Flag to track if service has been initialized
  static bool _isInitialized = false;

  // List of detected threats for reference
  static final List<String> _detectedThreats = [];

  /// Queue for threats detected before callback is set
  /// Threats are stored here and processed when callback becomes available
  static final List<ThreatInfo> _pendingThreats = [];

  /// Flag indicating if a block dialog is currently being shown
  /// Prevents multiple block dialogs from appearing simultaneously
  static bool _isShowingBlockDialog = false;

  /// Callback when a threat is detected - set by the app to show UI
  /// Called with ThreatInfo containing threat type, message, and response type
  static void Function(ThreatInfo threatInfo)? _onThreatDetected;

  /// Sets the threat detection callback and processes any queued threats
  /// Call this from home screen initState after UI is ready to show dialogs
  static set onThreatDetected(void Function(ThreatInfo threatInfo)? callback) {
    _onThreatDetected = callback;

    // Process any threats that were detected before callback was set
    if (callback != null && _pendingThreats.isNotEmpty) {
      _processPendingThreats();
    }
  }

  /// Response configuration for each threat type
  /// Defines whether to log, warn, or block for each detected threat
  static const Map<String, ThreatResponse> _threatResponses = {
    // BLOCK responses - app cannot continue
    'simulator': ThreatResponse.block,        // Emulator/simulator
    'multi_instance': ThreatResponse.block,   // App cloning (Parallel Space, etc.)
    'hooks': ThreatResponse.block,            // Frida/Xposed hooking
    'debug': ThreatResponse.block,            // Debugger attached
    'app_integrity': ThreatResponse.block,    // Tampered/modified APK
    'unofficial_store': ThreatResponse.block, // Sideloaded installation

    // WARN responses - show warning but allow continue
    'privileged_access': ThreatResponse.warn, // Root/jailbreak

    // LOG only responses - silent monitoring
    'dev_mode': ThreatResponse.log,           // Developer mode enabled
    'adb_enabled': ThreatResponse.log,        // USB debugging enabled
    'device_binding': ThreatResponse.log,     // Device binding violation
  };

  /// User-friendly titles for each threat type (shown in dialog)
  static const Map<String, String> _threatTitles = {
    'simulator': 'Unsupported Environment',
    'multi_instance': 'Unsupported Environment',
    'hooks': 'Security Violation',
    'debug': 'Security Violation',
    'app_integrity': 'Security Violation',
    'unofficial_store': 'Invalid Installation',
    'privileged_access': 'Security Warning',
    'dev_mode': 'Developer Mode',
    'adb_enabled': 'USB Debugging',
    'device_binding': 'Device Changed',
  };

  /// User-friendly messages for each threat type (shown in dialog body)
  static const Map<String, String> _threatMessages = {
    'simulator': 'This app cannot run on emulators or virtual devices.',
    'multi_instance': 'This app cannot run in cloned or multi-instance environments like Parallel Space or Dual Space.',
    'hooks': 'A debugging or hooking tool has been detected. The app cannot continue for security reasons.',
    'debug': 'A debugger has been detected attached to this app. The app cannot continue.',
    'app_integrity': 'This app has been modified and cannot run. Please install from Google Play Store.',
    'unofficial_store': 'This app was not installed from Google Play Store. Please reinstall from the official source.',
    'privileged_access': 'Your device appears to be rooted or jailbroken. This may expose your data to security risks. Please proceed with caution.',
    'dev_mode': 'Developer mode is enabled on this device.',
    'adb_enabled': 'USB debugging is enabled on this device.',
    'device_binding': 'Device binding has changed.',
  };

  /// Severity order for prioritizing threats (higher = more severe)
  /// Used when multiple threats are detected to show only the most severe
  static const Map<String, int> _threatSeverity = {
    'app_integrity': 100,      // Highest - tampered app is most severe
    'hooks': 95,               // Frida/hooking is active attack
    'debug': 90,               // Debugger attached
    'unofficial_store': 85,    // Sideloaded
    'simulator': 80,           // Emulator
    'multi_instance': 75,      // Cloned app
    'privileged_access': 50,   // Root (warn only, lower priority)
    'device_binding': 10,      // Log only
    'dev_mode': 5,             // Log only
    'adb_enabled': 5,          // Log only
  };

  /// Initialize freeRASP security monitoring
  /// Call this early in app startup (after Firebase init)
  static Future<void> initialize() async {
    // Prevent double initialization
    if (_isInitialized) return;

    // Skip security checks in debug mode to allow development
    if (kDebugMode) {
      if (kDebugMode) print('[SecurityService] Skipping RASP in debug mode');
      return;
    }

    try {
      // Configure freeRASP with app credentials
      final config = TalsecConfig(
        // Android configuration
        androidConfig: AndroidConfig(
          packageName: 'uk.co.productiveapps.snagsnapper',
          // SHA-256 hashes must be base64 encoded (not hex) - freeRASP requirement
          // Both local upload key and Play Store signing key are included
          signingCertHashes: [
            'vtWsMFm4E3IfYFnYQw3VMbQaoY986V86tJ4nw0uFSeg=', // Local debug key (for testing)
            'uZZJp3+zjA0CeViWQKFuFJHeqrU3yOM/66Ktyx/KYek=', // Play Store App Signing key
          ],
          // Detect apps installed from outside Play Store
          supportedStores: ['com.android.vending'], // Google Play Store only
        ),
        // iOS configuration
        iosConfig: IOSConfig(
          bundleIds: ['uk.co.productiveapps.snagsnapper'],
          teamId: 'CBD8TD8P52', // Apple Team ID for iOS protection
        ),
        // Email for security reports (optional)
        watcherMail: 'developer@productiveapps.co.uk',
        // Enable all security features
        isProd: true,
      );

      // Define threat callbacks - each threat type calls _handleThreat
      final threatCallbacks = ThreatCallback(
        // Device is rooted (Android) or jailbroken (iOS)
        onPrivilegedAccess: () => _handleThreat('privileged_access',
          'Device has root/jailbreak detected'),

        // App is running in debugger
        onDebug: () => _handleThreat('debug',
          'Debugger detected'),

        // Hooking framework detected (Frida, etc.)
        onHooks: () => _handleThreat('hooks',
          'Hooking framework (Frida) detected'),

        // App is running in emulator/simulator
        onSimulator: () => _handleThreat('simulator',
          'Emulator or simulator detected'),

        // App signature doesn't match expected (tampering)
        onAppIntegrity: () => _handleThreat('app_integrity',
          'App integrity violation - possible tampering'),

        // App installed from untrusted source (sideloaded)
        onUnofficialStore: () => _handleThreat('unofficial_store',
          'App installed from unofficial source'),

        // Device binding check failed
        onDeviceBinding: () => _handleThreat('device_binding',
          'Device binding violation'),

        // Developer mode enabled (Android)
        onDevMode: () => _handleThreat('dev_mode',
          'Developer mode enabled on device'),

        // ADB enabled (Android Debug Bridge)
        onADBEnabled: () => _handleThreat('adb_enabled',
          'ADB (Android Debug Bridge) enabled'),

        // Multi-instance / App cloning detected (Parallel Space, Dual Space, etc.)
        onMultiInstance: () => _handleThreat('multi_instance',
          'App cloning or multi-instance detected'),
      );

      // Attach callbacks and start monitoring
      Talsec.instance.attachListener(threatCallbacks);
      await Talsec.instance.start(config);

      _isInitialized = true;
      if (kDebugMode) print('[SecurityService] freeRASP initialized successfully');

    } catch (e, stack) {
      // Log error but don't crash the app
      if (kDebugMode) {
        print('[SecurityService] Failed to initialize freeRASP: $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'freeRASP initialization failed',
      );
    }
  }

  /// Handle detected security threat
  /// Logs to Crashlytics and either queues or immediately processes the threat
  static void _handleThreat(String threatType, String logMessage) {
    // Add to detected threats list
    _detectedThreats.add(threatType);

    // Log to Crashlytics for monitoring (always, regardless of response type)
    FirebaseCrashlytics.instance.log('[SECURITY] $logMessage');
    FirebaseCrashlytics.instance.setCustomKey('security_threat', threatType);

    if (kDebugMode) {
      print('[SecurityService] THREAT DETECTED: $logMessage');
    }

    // Get the configured response for this threat type
    final response = _threatResponses[threatType] ?? ThreatResponse.log;

    // For log-only threats, no UI action needed
    if (response == ThreatResponse.log) {
      return;
    }

    // Create threat info for UI handling
    final threatInfo = ThreatInfo(
      threatType: threatType,
      title: _threatTitles[threatType] ?? 'Security Alert',
      message: _threatMessages[threatType] ?? 'A security issue was detected.',
      response: response,
      severity: _threatSeverity[threatType] ?? 0,
    );

    // If callback is set, process immediately; otherwise queue
    if (_onThreatDetected != null) {
      _processOrQueueThreat(threatInfo);
    } else {
      // Queue the threat to be processed when callback is set
      _pendingThreats.add(threatInfo);
      if (kDebugMode) {
        print('[SecurityService] Queued threat (no callback yet): $threatType');
      }
    }
  }

  /// Process a threat or queue it if a block dialog is already showing
  static void _processOrQueueThreat(ThreatInfo threatInfo) {
    // If block dialog is showing, don't show another dialog
    if (_isShowingBlockDialog) {
      if (kDebugMode) {
        print('[SecurityService] Skipping threat (block dialog active): ${threatInfo.threatType}');
      }
      return;
    }

    // For block responses, set flag to prevent multiple dialogs
    if (threatInfo.response == ThreatResponse.block) {
      _isShowingBlockDialog = true;
    }

    // Call the callback to show dialog
    _onThreatDetected?.call(threatInfo);
  }

  /// Process any threats that were queued before callback was set
  /// Shows only the most severe threat to avoid multiple dialogs
  static void _processPendingThreats() {
    if (_pendingThreats.isEmpty) return;

    if (kDebugMode) {
      print('[SecurityService] Processing ${_pendingThreats.length} pending threats');
    }

    // Find the most severe threat
    ThreatInfo? mostSevere;
    for (final threat in _pendingThreats) {
      if (mostSevere == null || threat.severity > mostSevere.severity) {
        mostSevere = threat;
      }
    }

    // Clear the queue
    _pendingThreats.clear();

    // Process only the most severe threat
    if (mostSevere != null) {
      _processOrQueueThreat(mostSevere);
    }
  }

  /// Check if a warning for this threat type has been dismissed before
  /// Used to show warnings only once per install
  static Future<bool> isWarningDismissed(String threatType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('security_warning_dismissed_$threatType') ?? false;
    } catch (e) {
      // If SharedPreferences fails, show the warning (safe default)
      if (kDebugMode) {
        print('[SecurityService] Failed to check warning dismissed state: $e');
      }
      return false;
    }
  }

  /// Mark a warning as dismissed so it won't show again
  static Future<void> markWarningDismissed(String threatType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_warning_dismissed_$threatType', true);
    } catch (e) {
      // Log but don't fail - worst case warning shows again next time
      if (kDebugMode) {
        print('[SecurityService] Failed to save warning dismissed state: $e');
      }
    }
  }

  /// Check if any threats have been detected
  static bool get hasThreats => _detectedThreats.isNotEmpty;

  /// Get list of detected threats
  static List<String> get detectedThreats => List.unmodifiable(_detectedThreats);

  /// Check if a specific threat type was detected
  static bool hasThreat(String threatType) => _detectedThreats.contains(threatType);

  /// Get the response type for a threat (for testing/debug purposes)
  static ThreatResponse getResponseForThreat(String threatType) {
    return _threatResponses[threatType] ?? ThreatResponse.log;
  }

  /// Get threat info for a threat type (for testing/debug purposes)
  static ThreatInfo getThreatInfo(String threatType) {
    return ThreatInfo(
      threatType: threatType,
      title: _threatTitles[threatType] ?? 'Security Alert',
      message: _threatMessages[threatType] ?? 'A security issue was detected.',
      response: _threatResponses[threatType] ?? ThreatResponse.log,
      severity: _threatSeverity[threatType] ?? 0,
    );
  }

  /// Reset block dialog flag (called when block dialog is closed/app exits)
  static void resetBlockDialogFlag() {
    _isShowingBlockDialog = false;
  }
}

/// Response types for security threats
enum ThreatResponse {
  /// Silent logging only - no UI shown
  log,
  /// Show dismissible warning dialog - user can continue
  warn,
  /// Show non-dismissible block dialog - user must exit app
  block,
}

/// Information about a detected threat for UI handling
class ThreatInfo {
  /// Internal threat type identifier (e.g., 'privileged_access', 'simulator')
  final String threatType;

  /// User-friendly title for dialog (e.g., 'Security Warning')
  final String title;

  /// User-friendly message explaining the threat
  final String message;

  /// How the app should respond to this threat
  final ThreatResponse response;

  /// Severity level for prioritization (higher = more severe)
  final int severity;

  const ThreatInfo({
    required this.threatType,
    required this.title,
    required this.message,
    required this.response,
    required this.severity,
  });

  @override
  String toString() => 'ThreatInfo($threatType, $response, severity: $severity)';
}
