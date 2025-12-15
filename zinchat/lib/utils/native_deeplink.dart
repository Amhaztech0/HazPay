import 'package:flutter/services.dart';

class NativeDeepLink {
  static const MethodChannel _channel = MethodChannel('com.example.zinchat/deeplink');

  /// Returns the initial link that started the app (or null).
  static Future<String?> getInitialLink() async {
    try {
      final res = await _channel.invokeMethod<String>('getInitialLink');
      return res;
    } on PlatformException {
      return null;
    }
  }

  /// Start listening for link events coming from native. The [onLink] callback
  /// will be invoked with the raw URI string whenever the native code sends one.
  static void startListening(void Function(String) onLink) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final arg = call.arguments as String?;
        if (arg != null) onLink(arg);
      }
    });
  }
}
