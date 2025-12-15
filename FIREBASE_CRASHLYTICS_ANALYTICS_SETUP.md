# 📊 Firebase Crashlytics & Analytics Integration Guide

## Overview

This guide explains how to use the newly integrated **Firebase Crashlytics** (error tracking) and **Firebase Analytics** services in the ZinChat app.

---

## What Was Added

### 1. **Error Tracking Service** (`error_tracking_service.dart`)
- Automatic crash detection
- Non-fatal error logging
- Custom error context and metadata
- User session tracking
- Network/sync error tracking

### 2. **Analytics Service** (`analytics_service.dart`)
- User engagement tracking
- Feature usage monitoring
- Message/call tracking
- Search and share tracking
- Ad performance monitoring
- Custom event logging

### 3. **Firebase Dependencies**
Added to `pubspec.yaml`:
```yaml
firebase_crashlytics: ^4.0.5
firebase_analytics: ^11.2.1
```

### 4. **Initialization**
Updated `main.dart` to initialize both services on app startup.

---

## Setup Instructions

### Step 1: Update Dependencies

```bash
cd zinchat
flutter pub get
```

### Step 2: Firebase Console Setup

#### For Android:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your ZinChat project
3. Go to **Project Settings** → **Your apps** → **Android app**
4. Download the updated `google-services.json`
5. Replace the file in `android/app/google-services.json`
6. Rebuild: `flutter build apk --release`

#### For iOS:
1. Go to **Project Settings** → **Your apps** → **iOS app**
2. Download `GoogleService-Info.plist`
3. Add to Xcode: Drag into `ios/Runner` folder
4. Rebuild: `flutter build ios --release`

### Step 3: Enable Crashlytics in Firebase Console

1. Open **Crashlytics** in Firebase Console
2. Click **Enable** to activate crash reporting
3. First crash will appear in the dashboard

### Step 4: Enable Analytics in Firebase Console

1. Open **Analytics** in Firebase Console
2. Click **Enable** to activate event tracking
3. Events will appear in real-time events dashboard

---

## Using Error Tracking Service

### Basic Usage

```dart
import 'services/error_tracking_service.dart' as error_tracking;

final errorTracking = error_tracking.ErrorTrackingService();

// Record a non-fatal error
try {
  // Your code here
} catch (e, stack) {
  await errorTracking.recordError(
    exception: e,
    stack: stack,
    context: 'Feature Name',
    customData: {
      'user_action': 'button_pressed',
      'data_id': '123',
    },
  );
}
```

### Logging User Actions

```dart
// Set user ID (after login)
await errorTracking.setUserId(userId);

// Log user actions for debugging
await errorTracking.logUserAction(
  action: 'message_sent',
  details: 'Message to chat #123',
);
```

### Tracking Specific Errors

#### Messaging Errors
```dart
await errorTracking.logMessagingError(
  messageType: 'direct_message',
  errorDescription: 'Failed to send message',
  messageId: msg['id'],
  recipientId: recipientId,
);
```

#### Call Errors
```dart
await errorTracking.logCallError(
  callType: 'direct_call',
  errorDescription: 'Call connection failed',
  callId: callId,
  participantId: participantId,
);
```

#### Network Errors
```dart
await errorTracking.logNetworkError(
  endpoint: '/api/messages',
  errorDescription: 'Timeout',
  statusCode: 504,
  duration: Duration(seconds: 30),
);
```

#### Auth Errors
```dart
await errorTracking.logAuthError(
  errorDescription: 'Login failed - invalid credentials',
  userId: userId,
);
```

### Custom Logging

```dart
// Add custom context to crash reports
errorTracking.log('User navigated to settings');
errorTracking.setCustomKey('theme', 'dark');

// Multiple keys
await errorTracking.setCustomKeys({
  'user_id': userId,
  'server_id': serverId,
  'app_version': '1.0.0',
});
```

---

## Using Analytics Service

### Basic Usage

```dart
import 'services/analytics_service.dart' as analytics;

final analyticsService = analytics.AnalyticsService();

// Log screen view
await analyticsService.logScreenView('ChatScreen');

// Track feature usage
await analyticsService.logFeatureUsage('voice_message');
```

### User Tracking

```dart
// After user logs in
await analyticsService.setUserId(userId);

// Track signup method
await analyticsService.logUserSignup(method: 'email');

// Set user properties
await analyticsService.setUserProperties(
  properties: {
    'subscription': 'premium',
    'language': 'en',
    'theme': 'dark',
  },
);
```

### Message Tracking

```dart
// Track message sent
await analyticsService.logMessageSent(
  messageType: 'direct_message',
  serverId: null,
  hasMedia: true,
);

// Track message viewed
await analyticsService.logMessageViewed(
  messageType: 'server_message',
  serverId: serverId,
);
```

### Call Tracking

```dart
// Log when call initiated
await analyticsService.logCallInitiated(
  callType: 'group_call',
  participantCount: '5',
);

// Log call duration
await analyticsService.logCallDuration(
  callType: 'direct_call',
  durationSeconds: 180,
);
```

### Engagement Tracking

```dart
// Track search
await analyticsService.logSearch(
  searchTerm: 'flutter',
  searchType: 'user_search',
  resultCount: 12,
);

// Track share
await analyticsService.logShare(
  contentType: 'message',
  itemId: messageId,
);

// Track ad impression/click
await analyticsService.logAdImpression(
  adUnit: 'banner_top',
  adFormat: 'banner',
);

await analyticsService.logAdClick(adUnit: 'banner_top');
```

### Custom Events

```dart
// Log any custom event
await analyticsService.logCustomEvent(
  eventName: 'user_customization',
  parameters: {
    'customization_type': 'avatar_upload',
    'avatar_size': 512,
    'success': true,
  },
);
```

---

## Integration Points (Where to Add Tracking)

### In Authentication Service
```dart
// After successful login
await analyticsService.setUserId(user.id);
await analyticsService.logUserLogin(method: 'email');
await errorTracking.setUserId(user.id);

// On logout
await analyticsService.logCustomEvent(eventName: 'user_logout');
```

### In Chat/Message Service
```dart
// When sending a message
await analyticsService.logMessageSent(
  messageType: type,
  serverId: serverId,
  hasMedia: mediaUrl != null,
);

// On message error
await errorTracking.logMessagingError(
  messageType: type,
  errorDescription: e.toString(),
  messageId: messageId,
);
```

### In Call Manager
```dart
// On call start
await analyticsService.logCallInitiated(callType: type);

// On call end
await analyticsService.logCallDuration(
  callType: type,
  durationSeconds: duration.inSeconds,
);

// On call error
await errorTracking.logCallError(
  callType: type,
  errorDescription: errorMessage,
);
```

### In Server Service
```dart
// User joins server
await analyticsService.logServerInteraction(
  action: 'join',
  serverId: serverId,
);

// Server creation
await analyticsService.logServerInteraction(
  action: 'create',
  serverId: newServerId,
);
```

### In UI Screens
```dart
// When entering a screen
@override
void initState() {
  super.initState();
  analyticsService.logScreenView('ChatListScreen');
}

// When user interacts with features
await analyticsService.logFeatureUsage('voice_call_button');
```

---

## Firebase Console Dashboard

### Crashlytics Dashboard
Track:
- ✅ Total crashes over time
- ✅ Crash-free users
- ✅ Most impactful crashes
- ✅ Stack traces and context
- ✅ Custom keys and user properties

**URL**: `Firebase Console → Crashlytics`

### Analytics Dashboard
Track:
- ✅ User engagement
- ✅ Retention rates
- ✅ Feature usage
- ✅ User demographics
- ✅ Conversion funnels
- ✅ Custom event trends

**URL**: `Firebase Console → Analytics → Events`

---

## Best Practices

### ✅ DO:
- Log errors with context and custom data
- Set user ID after authentication
- Track important feature usage
- Log network/sync errors
- Monitor crash-free rates

### ❌ DON'T:
- Log too frequently (performance impact)
- Send sensitive data (passwords, tokens)
- Log in tight loops
- Ignore error logs
- Leave unhandled errors

### Privacy Considerations

1. **Personally Identifiable Information (PII)**
   - ❌ Never log passwords, emails, phone numbers
   - ✅ Use anonymized user IDs
   - ✅ Log only necessary context

2. **Data Retention**
   - Crashlytics retains data for 90 days by default
   - Analytics events for 60 months
   - Check Firebase Console for retention policies

3. **User Consent**
   - Add option in Settings to opt-out of analytics
   - Respect user privacy preferences
   - Comply with GDPR, CCPA requirements

---

## Debugging

### View Logs Locally

Add to debug console output:
```dart
// Force crash for testing (development only)
FlutterError.onError?.call(FlutterErrorDetails(exception: Exception('Test crash')));
```

### Test Analytics Events

Events appear in Firebase Console under:
- **Real-time events**: Shows events as they happen
- **Events dashboard**: Shows aggregated data (24-48 hours delay)

### Troubleshooting

**Events not appearing:**
1. Check Firebase project is linked
2. Verify `google-services.json` / `GoogleService-Info.plist` is up-to-date
3. Check internet connection
4. Wait 24-48 hours for analytics data to appear

**Crashes not recorded:**
1. Ensure app is built with release mode
2. Check Crashlytics is enabled in Firebase Console
3. Verify crashlytics packages are up-to-date
4. Device must have internet for first upload

---

## Configuration

### Disable Analytics (if needed)

```dart
// In main.dart
await analyticsService.setAnalyticsCollectionEnabled(false);
```

### Set Session Timeout

```dart
// Users inactive for 30 minutes = new session
await analyticsService.setSessionTimeoutDuration(Duration(minutes: 30));
```

### Disable Crash Collection (for user privacy)

```dart
await errorTracking.setCrashCollectionEnabled(false);
```

---

## Useful Resources

- [Firebase Crashlytics Docs](https://firebase.google.com/docs/crashlytics)
- [Firebase Analytics Docs](https://firebase.google.com/docs/analytics)
- [Flutter Firebase Setup](https://firebase.flutter.dev/docs/overview)
- [Crashlytics Best Practices](https://firebase.google.com/docs/crashlytics/get-started)

---

## Summary

| Feature | Purpose | Usage |
|---------|---------|-------|
| **Error Tracking** | Catch production crashes | `ErrorTrackingService().recordError()` |
| **Custom Logging** | Debug issues | `ErrorTrackingService().log()` |
| **Analytics** | Track user behavior | `AnalyticsService().logScreenView()` |
| **User Properties** | Segment users | `AnalyticsService().setUserProperties()` |
| **Events** | Track interactions | `AnalyticsService().logCustomEvent()` |

---

**Next Steps:**
1. ✅ Run `flutter pub get`
2. ✅ Update Firebase config files
3. ✅ Review and update existing code to add tracking
4. ✅ Build and test in release mode
5. ✅ Monitor Firebase Console for data

---

Generated: 2024
Status: Ready for implementation
