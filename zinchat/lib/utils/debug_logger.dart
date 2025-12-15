import 'package:flutter/foundation.dart';

/// Simple debug logger that only prints in debug mode
class DebugLogger {
  static void log(String message, {String tag = 'DEBUG'}) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void error(String message, {String tag = 'ERROR'}) {
    if (kDebugMode) {
      debugPrint('❌ [$tag] $message');
    }
  }

  static void info(String message, {String tag = 'INFO'}) {
    if (kDebugMode) {
      debugPrint('ℹ️  [$tag] $message');
    }
  }

  static void success(String message, {String tag = 'SUCCESS'}) {
    if (kDebugMode) {
      debugPrint('✅ [$tag] $message');
    }
  }

  static void call(String message) {
    log(message, tag: 'CALL');
  }
}
