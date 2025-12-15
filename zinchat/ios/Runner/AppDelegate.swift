import Flutter
import UIKit
import Flutter
import FlutterPluginRegistrant

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Set up method channel for deep link forwarding from iOS native to Dart
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.example.zinchat/deeplink", binaryMessenger: controller.binaryMessenger)
      // If app was launched via URL, attempt to forward it
      if let url = launchOptions?[.url] as? URL {
        channel.invokeMethod("onLink", arguments: url.absoluteString)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.example.zinchat/deeplink", binaryMessenger: controller.binaryMessenger)
      channel.invokeMethod("onLink", arguments: url.absoluteString)
    }
    return true
  }
}
