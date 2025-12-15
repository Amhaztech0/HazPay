# AdMob Integration Guide for ZinChat

## 🎯 Overview

ZinChat now has AdMob integrated in two creative, user-friendly ways:

1. **Story Ads**: Ads appear as stories/statuses that users can choose to view
2. **Sponsored Contact**: A special contact always at the top of the chat list that shows ads when tapped

## ✅ What's Already Done

✔️ Added `google_mobile_ads` package to pubspec.yaml
✔️ Created AdMob service for managing ads
✔️ Created ad story models
✔️ Integrated story ads into status viewing
✔️ Created sponsored contact for chat list
✔️ Updated Android manifest with AdMob App ID
✔️ Initialized AdMob in main.dart

## 🔧 Setup Instructions

### Step 1: Get Your AdMob App ID

1. Go to [AdMob Console](https://apps.admob.com/)
2. Create a new app or select an existing one
3. Copy your App ID (format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`)

### Step 2: Get Your Ad Unit IDs

You need two ad unit IDs:
- **Story Ad Unit ID**: For story/status ads
- **Chat Ad Unit ID**: For the sponsored contact ads

1. In AdMob Console, go to "Ad units"
2. Create two Interstitial ad units
3. Copy both Ad Unit IDs

### Step 3: Update the Configuration

#### Update Android Manifest

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/> <!-- Replace with YOUR App ID -->
```

#### Update AdMob Service

Edit `lib/services/admob_service.dart` and replace the test IDs:

```dart
static String get storyAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // Your Story Ad Unit ID
  } else if (Platform.isIOS) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // Your iOS Story Ad Unit ID
  }
  return '';
}

static String get chatAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // Your Chat Ad Unit ID
  } else if (Platform.isIOS) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // Your iOS Chat Ad Unit ID
  }
  return '';
}
```

### Step 4: For iOS Support (Optional)

Edit `ios/Runner/Info.plist` and add:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

## 🎨 How It Works

### Story Ads

1. When users open the status/stories screen, an ad is loaded
2. The ad appears as a special "Sponsored" story with a megaphone icon
3. Users can tap on it to view the ad (just like viewing a regular story)
4. The ad is shown as an interstitial ad

**Location**: `lib/services/ad_story_integration_service.dart`

### Sponsored Contact

1. When the home screen loads, a sponsored ad is loaded
2. A "📢 Sponsored" contact appears at the TOP of the chat list
3. When users tap this contact, an ad is shown instead of opening a chat
4. The contact always stays at the top for maximum visibility

**Location**: `lib/services/sponsored_chat_service.dart`

## 🧪 Testing

### Test IDs (Already Configured)

The app currently uses Google's test ad unit IDs:
- They will show test ads in your app
- Perfect for development and testing
- No need to worry about invalid clicks

### Testing Steps

1. Build and run the app on a real device
2. Navigate to the home screen - you should see the "📢 Sponsored" contact at the top
3. Tap on it - a test ad should appear
4. Navigate to the status screen - you should see a "Sponsored" story
5. Tap on the sponsored story - a test ad should appear

### Important Notes

⚠️ **Test ads won't show real ads** - they'll show placeholder content
⚠️ **Never click your own ads in production** - use test IDs during development
⚠️ **Real ads take time** - It may take hours after publishing for real ads to start showing

## 📊 Customization Options

### Change Ad Frequency

In `lib/services/ad_story_integration_service.dart`, modify where the ad is inserted:

```dart
// Currently at position 2 (after user's own status)
final insertPosition = newGroups.length > 2 ? 2 : newGroups.length;

// To show at position 1 (first in list):
final insertPosition = 0;

// To show at position 5:
final insertPosition = newGroups.length > 5 ? 5 : newGroups.length;
```

### Change Sponsored Contact Text

In `lib/models/ad_story_model.dart`:

```dart
SponsoredContactModel({
  this.id = 'sponsored-ads',
  this.displayName = '📢 Sponsored', // Change this
  this.about = 'Tap to view offers', // Change this
  this.profilePhotoUrl,
  this.ad,
});
```

### Change Story Ad Display

In `lib/services/ad_story_integration_service.dart`:

```dart
final sponsoredUser = UserModel(
  id: 'sponsored',
  displayName: '📢 Sponsored', // Change this
  about: 'Tap to view', // Change this
  profilePhotoUrl: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

## 🚀 Going to Production

1. Replace all test ad unit IDs with your real ad unit IDs
2. Update the AdMob App ID in AndroidManifest.xml
3. Test thoroughly on real devices
4. Submit to Play Store/App Store
5. Wait for ad approval (can take 24-48 hours)

## 📝 Files Modified/Created

- ✅ `lib/services/admob_service.dart` - Core ad management
- ✅ `lib/services/ad_story_integration_service.dart` - Story ad integration
- ✅ `lib/services/sponsored_chat_service.dart` - Sponsored contact integration
- ✅ `lib/models/ad_story_model.dart` - Ad models
- ✅ `lib/screens/status/status_list_screen.dart` - Story ads display
- ✅ `lib/screens/home/home_screen.dart` - Sponsored contact display
- ✅ `lib/main.dart` - AdMob initialization
- ✅ `android/app/src/main/AndroidManifest.xml` - AdMob configuration
- ✅ `pubspec.yaml` - Dependencies

## 💡 Best Practices

1. **Don't overdo it**: Too many ads annoy users
2. **User control**: Ads only show when users choose to view them
3. **Test extensively**: Use test IDs until you're ready for production
4. **Monitor performance**: Check AdMob dashboard for metrics
5. **Respect users**: Make ads feel native and non-intrusive

## 🐛 Troubleshooting

### Ads not showing?

1. Check if you're using test IDs (they should show test ads)
2. Ensure AdMob App ID is correct in AndroidManifest.xml
3. Wait a few seconds after app start for ads to load
4. Check logs for error messages (search for "AdMob" or "❌")

### Real ads not showing in production?

1. Wait 24-48 hours after publishing
2. Ensure your app is approved in AdMob
3. Check if your account is in good standing
4. Verify ad units are active in AdMob console

## 📱 Contact

If you have questions or issues, check the AdMob documentation:
- [AdMob Flutter Plugin](https://pub.dev/packages/google_mobile_ads)
- [AdMob Help Center](https://support.google.com/admob)

---

**Created**: November 2025
**Status**: ✅ Fully Integrated and Ready to Use!
