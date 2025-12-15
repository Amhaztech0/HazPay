/// WHATSAPP-STYLE NOTIFICATION SETUP GUIDE
/// 
/// This guide explains how to implement WhatsApp/Telegram-style notifications
/// in your Flutter app using Firebase Cloud Messaging (FCM).

/// KEY REQUIREMENTS FOR WHATSAPP-STYLE NOTIFICATIONS:
///
/// 1. HIGH PRIORITY NOTIFICATIONS
///    - Android: Importance.max + Priority.high + alarmClockSound
///    - iOS: sound + badge + alert
///
/// 2. SMART NOTIFICATION ROUTING
///    - If chat is open: Show notification in-app (no system notification)
///    - If app is in background: Show in system tray + sound
///    - If app is terminated: Queue and show when app opens
///
/// 3. NOTIFICATION GROUPING
///    - Group messages from same sender/chat
///    - Show message preview (not just "New message")
///    - Display unread count
///
/// 4. INSTANT DELIVERY
///    - Send from Supabase Edge Functions triggered on message insert
///    - Use data-only messages for custom handling
///    - Implement retry logic for failed deliveries
///
/// 5. RICH NOTIFICATIONS
///    - Show sender's profile picture
///    - Display message preview
///    - Show timestamp
///    - Custom notification sound

/// IMPLEMENTATION STEPS:
///
/// Step 1: Set up Firebase Console
///    - Create Firebase project
///    - Add Android app → download google-services.json
///    - Add iOS app → download GoogleService-Info.plist
///    - Enable Cloud Messaging
///    - Enable Realtime Database (optional, for device status)
///
/// Step 2: Update pubspec.yaml (Already done in your project)
///    - firebase_core
///    - firebase_messaging
///    - flutter_local_notifications
///
/// Step 3: Android Setup
///    - Increase minSdkVersion to 21+
///    - Add notification channel configuration
///    - Configure high-priority sounds
///
/// Step 4: iOS Setup
///    - Enable Background Modes (Push Notifications, Background Fetch)
///    - Request APNS certificate
///    - Enable Critical Alert capability (for Do Not Disturb bypass)
///
/// Step 5: Create Supabase Edge Function to send notifications
///    - Trigger on server_messages insert
///    - Query FCM tokens from user_tokens table
///    - Call Firebase Admin SDK to send messages
///    - Handle message grouping + threading
///
/// Step 6: Implement smart notification handling
///    - Check if chat is currently open
///    - Route notifications appropriately
///    - Handle notification taps and deep linking
