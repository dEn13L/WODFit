import 'package:flutter/foundation.dart';

class AppLogger {
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG][$tag] $message');
    }
  }

  static void i(String tag, String message) {
    debugPrint('[INFO][$tag] $message');
  }

  static void w(String tag, String message, [Object? error]) {
    debugPrint('[WARN][$tag] $message ${error != null ? 'Error: $error' : ''}');
  }

  static void e(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR][$tag] $message');
    if (error != null) {
      debugPrint('[ERROR][$tag] Exception: $error');
    }
    if (stackTrace != null) {
      debugPrint('[ERROR][$tag] StackTrace:\n$stackTrace');
    }
  }
}
