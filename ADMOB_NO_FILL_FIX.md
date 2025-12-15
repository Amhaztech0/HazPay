# 🔧 AdMob Rewarded Ads Troubleshooting Guide

## Issue: "No fill" Error - Ad Not Loading

**Error Message:**
```
Ad failed to load : 3
❌ Failed to load rewarded ad: LoadAdError(code: 3, message: No fill.)
```

---

## 🔍 Diagnosis: What "No fill" Means

"No fill" (Error Code 3) means:
- ✅ Your Ad Unit ID is correct
- ✅ The SDK is initialized properly
- ❌ Google AdMob can't serve an ad because:
  1. The ad unit was created recently (new units take 24-48 hours)
  2. You're in a region where ads aren't available
  3. You're using a test device but didn't add it to test devices list
  4. Your app version isn't live on Play Store yet

---

## ✅ Solution Steps

### Step 1: Add Your Device as a Test Device

**Get your Device ID from the logs:**
```
I/Ads(24317): Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("055C4049ED3542EEC801B1CB41FD2111")) to get test ads on this device.
```

**Copy the ID:** `055C4049ED3542EEC801B1CB41FD2111` (yours will be different)

---

### Step 2: Initialize Google Mobile Ads with Test Device

Update your `lib/main.dart` to add test device configuration:

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Mobile Ads
  await MobileAds.instance.initialize(
    requestConfiguration: RequestConfiguration(
      keywords: <String>['game', 'apps'],
      contentUrl: 'https://www.example.com',
      childDirected: false,
      // Add your test device ID here
      testDeviceIds: <String>[
        '055C4049ED3542EEC801B1CB41FD2111', // Replace with YOUR device ID from logs
      ],
    ),
  );

  runApp(const MyApp());
}
```

Replace `055C4049ED3542EEC801B1CB41FD2111` with the ID from your device logs.

---

### Step 3: Also Add Test Device in AdMob Console (Optional but Recommended)

1. Go to [Google AdMob Console](https://admob.google.com)
2. Select your app
3. Settings → Test devices
4. Add device: Enter the Device ID
5. Save

---

### Step 4: Rebuild & Test

```bash
flutter clean
flutter pub get
flutter run
```

**Wait 30-60 seconds** for the ad to load. Test devices may load ads slower than production.

---

## ⏱️ Ad Loading Times

| Scenario | Load Time | Notes |
|----------|-----------|-------|
| First time | 30-60s | Normal, SDK initializing |
| Test device | 20-40s | May be slower |
| Production | 5-15s | Optimized in production |
| Sample ads | Instant | Use for testing |

---

## 📋 Troubleshooting Checklist

- [ ] Device ID added to `main.dart` RequestConfiguration
- [ ] Device ID is correct (copied from logs)
- [ ] `flutter clean` run
- [ ] `flutter pub get` run
- [ ] App rebuilt (`flutter run`)
- [ ] Waited 60 seconds for first ad load
- [ ] Check logs for error code (3 = no fill, others = different issue)
- [ ] Ad Unit ID is correct: `ca-app-pub-3763345250812931/1709690574`
- [ ] App ID is correct: `ca-app-pub-3763345250812931~3556987699`

---

## 🆘 Still Getting "No Fill"?

### Option A: Use Sample Ad Unit IDs for Testing

Google provides test Ad Unit IDs that always work:

**For Rewarded Ads (Test):**
```
ca-app-pub-3940256099942544/5224354917
```

Temporarily replace your Ad Unit ID with this to verify your implementation works.

Then when ready for production, switch back to your real Ad Unit ID.

---

### Option B: Wait 24-48 Hours

If this is a new ad unit:
1. New ad units take **24-48 hours** to activate
2. Check back tomorrow
3. If still not working, verify Account Status in AdMob Console

---

### Option C: Check AdMob Account Status

1. Go to [AdMob Console](https://admob.google.com)
2. Click your profile → **Payments**
3. Verify account is in **"good standing"**
4. If suspended, review the reason and fix

---

## 🧪 Verify Implementation Works (Using Test Ads)

```dart
// In rewarded_ads_screen.dart, temporarily use this Ad Unit:
adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Google's test ad unit

// This WILL load ads immediately
// Once verified working, switch back to your real ad unit
```

**When test ad works:**
- ✅ SDK is initialized correctly
- ✅ Ad loading logic is correct
- ✅ Ad display logic is correct
- ❌ Your ad unit just needs time or account verification

---

## 📱 Device ID Not in Logs?

If you don't see the device ID message:

1. Make sure you have internet connection
2. Open the app and go to Earn Points screen
3. Check logs again (it usually appears within 5 seconds)
4. Or grep for "055C4049" or "Ads" in logs

If still not there, add this to `main.dart`:

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Print device ID for debugging
  final info = await MobileAds.instance.getRequestConfiguration();
  print('Device ID: ${info.testDeviceIds}');
  
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}
```

---

## ✅ Expected Behavior After Fix

**First Load:**
- ⏳ 30-60 seconds waiting
- ✅ Ad loads
- ✅ "✅ Ad ready to watch" shown

**Subsequent Loads:**
- ⏳ 10-20 seconds waiting
- ✅ Ad loads

**After Fix Confirmed:**
- Replace test Ad Unit with your real one
- Submit app to Play Store
- Once live, production users see real ads within hours

---

## 📞 If Still Not Working

1. Verify Device ID is in logs: `grep "055C" flutter logs`
2. Verify in `main.dart` - exact match (case-sensitive)
3. Run `flutter clean` again
4. Wait 90 seconds before giving up on first load
5. Check AdMob console - is account in good standing?

---

**Reference:**
- [Google Mobile Ads Flutter Docs](https://firebase.google.com/docs/admob/get-started?platform=flutter)
- [Test Ad Unit IDs](https://support.google.com/admob/answer/9683801?hl=en#test_ad_units)
- [Troubleshooting AdMob](https://support.google.com/admob/answer/3124584)

