import 'package:flutter/foundation.dart';

/// Custom logger for cleaner log filtering in Android Studio
/// Usage: AppLogger.log('ProfileScreen', 'Loading user data');
class AppLogger {
  static const String _appTag = 'SnagSnapper';
  
  static void log(String module, String message, {bool isError = false}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final prefix = isError ? '❌' : '📱';
      debugPrint('$prefix [$_appTag.$module] $timestamp: $message');
    }
  }
  
  static void profile(String message) => log('Profile', message);
  static void sync(String message) => log('Sync', message);
  static void image(String message) => log('Image', message);
  static void database(String message) => log('Database', message);
  static void network(String message) => log('Network', message);
  static void error(String module, String message) => log(module, message, isError: true);
}