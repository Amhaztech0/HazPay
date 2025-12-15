package com.example.zinchat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var initialLink: String? = null
	private var methodChannel: MethodChannel? = null
	private var notificationChannel: MethodChannel? = null
	private var pendingNotificationPayload: String? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		initialLink = intent?.dataString
		createNotificationChannel()
		
		// Check if launched from notification
		if (intent?.action == "SELECT_NOTIFICATION") {
			pendingNotificationPayload = intent.getStringExtra("payload")
			android.util.Log.d("MainActivity", "App launched from notification with payload: $pendingNotificationPayload")
		}
	}

	private fun createNotificationChannel() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val name = "Messages"
			val descriptionText = "Zinchat message notifications"
			val importance = NotificationManager.IMPORTANCE_MAX
			val channel = NotificationChannel("zinchat_messages", name, importance).apply {
				description = descriptionText
				enableVibration(true)
				setShowBadge(true)
			}
			val notificationManager: NotificationManager =
				getSystemService(NOTIFICATION_SERVICE) as NotificationManager
			notificationManager.createNotificationChannel(channel)
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		
		// Deeplink channel
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zinchat/deeplink")
		methodChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"getInitialLink" -> result.success(initialLink)
				else -> result.notImplemented()
			}
		}
		
		// Notification channel
		notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.zinchat/notification")
		notificationChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"getPendingNotificationPayload" -> {
					android.util.Log.d("MainActivity", "Flutter requested pending payload: $pendingNotificationPayload")
					result.success(pendingNotificationPayload)
					pendingNotificationPayload = null // Clear after retrieving
				}
				else -> result.notImplemented()
			}
		}
		
		// Send pending notification immediately if Flutter is ready
		if (pendingNotificationPayload != null) {
			android.util.Log.d("MainActivity", "Sending pending notification to Flutter: $pendingNotificationPayload")
			notificationChannel?.invokeMethod("onNotificationTapped", pendingNotificationPayload)
			pendingNotificationPayload = null
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		
		// Handle deeplinks
		val data = intent.dataString
		if (data != null) {
			methodChannel?.invokeMethod("onLink", data)
		}
		
		// Handle notification taps
		if (intent.action == "SELECT_NOTIFICATION") {
			val payload = intent.getStringExtra("payload")
			android.util.Log.d("MainActivity", "Notification tapped with payload: $payload")
			if (payload != null) {
				notificationChannel?.invokeMethod("onNotificationTapped", payload)
			}
		}
	}
}
