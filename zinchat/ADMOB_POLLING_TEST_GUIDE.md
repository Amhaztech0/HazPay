# AdMob Polling Mechanism - Testing & Verification Guide

## What Was Fixed

The original issue: **Ads loaded successfully but returned NULL before callback completed**

The solution: **Background loading + UI polling pattern**

## How to Verify It's Working

### 1. Check Device Logs

While the app is running:
```bash
adb logcat | grep flutter
```

### Expected Log Output (in order):

```
I/flutter: 🔄 Loading sponsored contact...
I/flutter: ✅ Sponsored contact placeholder created
I/flutter: 📥 Attempting to load chat ad with ID: ca-app-pub-3940256099942544/1033173712
I/flutter: ✅ Chat ad loaded successfully
I/flutter: ✅ Background: Sponsored contact ad loaded
I/flutter: ✅ Ad is now ready! Updating UI
```

### Log Timing:

```
T=0s     → 🔄 Loading sponsored contact...
T=0s     → ✅ Sponsored contact placeholder created
T=0s     → 📥 Attempting to load chat ad...
T=0s     → [Polling starts]
T=0.5s   → [Poll #1: no ad yet]
T=1.0s   → [Poll #2: no ad yet]
T=1.5s   → [Poll #3: no ad yet]
T=2.0s   → [Poll #4: no ad yet]
T=2.5s   → [Poll #5: no ad yet]
T=3.0s   → ✅ Chat ad loaded successfully
T=3.0s   → ✅ Background: Sponsored contact ad loaded
T=3.5s   → ✅ Ad is now ready! Updating UI   ← UI UPDATES HERE
```

### 2. Visual Verification

**Initial State (T=0-1s):**
- Chat list visible
- "📢 Sponsored" contact at top of list
- May or may not have ad preview

**After Ad Loads (T=3-5s):**
- "📢 Sponsored" contact still at top
- Ad should be ready to display
- UI should look responsive (no lag)

**When User Taps:**
- Sponsored contact is tappable
- Fullscreen interstitial ad displays
- Ad has close button
- Closing returns to chat list

### 3. Code-Level Verification

Check that these files have the changes:

#### `lib/screens/home/home_screen.dart`

Look for:
```dart
Timer? _adRefreshTimer;

// In initState():
_adRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
  _checkAdReady();
});

Future<void> _checkAdReady() async {
  if (!mounted) return;
  final updated = await _sponsoredChatService.getSponsoredContact();
  if (updated != null && updated.ad != null && _sponsoredContact?.ad == null) {
    setState(() {
      _sponsoredContact = updated;
      debugPrint('✅ Ad is now ready! Updating UI');
    });
  }
}

// In dispose():
_adRefreshTimer?.cancel();
```

#### `lib/services/sponsored_chat_service.dart`

Look for:
```dart
Future<SponsoredContactModel?> getSponsoredContact() async {
  return _sponsoredContact;
}

Future<SponsoredContactModel?> loadSponsoredContact() async {
  // Load ad in background - don't wait
  _adMobService.loadChatAd().then((ad) {
    if (ad != null) {
      _sponsoredContact = SponsoredContactModel(ad: ad);
      debugPrint('✅ Background: Sponsored contact ad loaded');
    }
  });
  
  // Return immediately with placeholder
  _sponsoredContact = SponsoredContactModel();
  return _sponsoredContact;
}
```

### 4. Performance Verification

#### Check CPU Impact:

Terminal while app is running:
```bash
adb shell top -n 1 | grep zinchat
```

Look for: CPU should stay low (<5% during polling)

#### Check Memory Impact:

```bash
adb shell dumpsys meminfo | grep zinchat
```

Should be consistent, no rapid growth

### 5. Functionality Checklist

- [ ] **Placeholder Shows**: "📢 Sponsored" visible immediately on app start
- [ ] **No Crashes**: App doesn't crash during polling (3-5 seconds)
- [ ] **Ad Loads**: After 3-5 seconds, ad appears in logs
- [ ] **UI Updates**: Poll timer detects ad and updates UI
- [ ] **Tap Works**: Tapping "📢 Sponsored" shows fullscreen ad
- [ ] **Close Works**: Close button on ad returns to app
- [ ] **Sponsored Stays**: "📢 Sponsored" remains at top after closing ad
- [ ] **No Memory Leak**: App performance consistent over time
- [ ] **Graceful Failure**: If ad fails, placeholder remains without crashing

## Troubleshooting

### Problem: "✅ Ad is now ready!" never appears

**Cause**: Polling might not be running or ad never loads
**Fix**:
1. Verify logs show "Chat ad loaded successfully"
2. Check `_adRefreshTimer` is created in `initState()`
3. Increase poll interval (change 500ms to 250ms for faster detection)
4. Check ad unit ID is correct

### Problem: Multiple "Ad is now ready!" messages

**Cause**: Polling continuing after ad ready (timer should stop)
**Fix**: 
1. Add `&& _sponsoredContact?.ad == null` check (already in code)
2. Verify condition properly gates multiple updates
3. Can optionally cancel timer after first update:
```dart
if (/* ad ready */) {
  _adRefreshTimer?.cancel();  // Optional
  setState(...);
}
```

### Problem: App crashes on home screen

**Cause**: Timer not disposed properly
**Fix**:
1. Verify `_adRefreshTimer?.cancel()` in `dispose()`
2. Check `if (!mounted)` guard in `_checkAdReady()`
3. Monitor logs for exceptions

### Problem: "📢 Sponsored" doesn't tap to show ad

**Cause**: Ad object null or chat tile not handling tap
**Fix**:
1. Verify ad loaded (logs show success)
2. Check `showSponsoredAd()` method exists
3. Verify tap handler calls correct method
4. Check ad unit ID matches

## Expected Behavior Timeline

### First 1 Second:
```
✅ AdMob initialized successfully
🔄 Loading sponsored contact...
✅ Sponsored contact placeholder created
📥 Attempting to load chat ad...
```

### Seconds 1-3:
```
[Polling active, no ad yet - silent polls]
```

### Seconds 3-5:
```
✅ Chat ad loaded successfully
✅ Background: Sponsored contact ad loaded
✅ Ad is now ready! Updating UI
[UI REFRESHES - sponsored contact now ready]
```

### User Interaction:
```
[User taps "📢 Sponsored"]
📢 Fullscreen ad appears
[User taps close button]
[Ad dismissed, returns to chat list]
```

## Diagnostic Script

Copy this test into your terminal to collect diagnostics:

```bash
#!/bin/bash

echo "=== AdMob Integration Test ==="
echo ""
echo "1. Checking app installed:"
adb shell pm list packages | grep zinchat

echo ""
echo "2. Starting app and capturing logs:"
adb logcat -c
adb shell am start -n com.example.zinchat/.MainActivity
sleep 10

echo ""
echo "3. Ad-related logs:"
adb logcat -d | grep -E "(AdMob|Sponsored|Chat ad|Ad is now ready)"

echo ""
echo "4. Memory usage:"
adb shell dumpsys meminfo | grep zinchat

echo ""
echo "5. CPU usage:"
adb shell top -n 1 | grep zinchat

echo ""
echo "=== Test Complete ==="
```

## Success Criteria

✅ **All of the following should be true:**

1. App launches without crashes
2. "📢 Sponsored" contact visible at top of chat list
3. Logs show all expected messages in order
4. After 3-5 seconds, "✅ Ad is now ready!" appears
5. Tapping "📢 Sponsored" shows fullscreen ad
6. Closing ad returns to app cleanly
7. No memory leaks (memory stable over time)
8. No excessive CPU usage (< 5%)

## Comparison: Before vs After

### Before (Broken):
```
🔄 Loading sponsored contact...
✅ Sponsored contact placeholder created
📥 Attempting to load chat ad...
📤 Returning chat ad: NULL          ← ❌ PROBLEM: Returned NULL
✅ Chat ad loaded successfully      ← But loaded later!
❌ Sponsored contact loaded: NO     ← Never displayed
```

### After (Fixed):
```
🔄 Loading sponsored contact...
✅ Sponsored contact placeholder created
📥 Attempting to load chat ad...
[Polling: check every 500ms]
✅ Chat ad loaded successfully
✅ Background: Sponsored contact ad loaded
✅ Ad is now ready! Updating UI    ← ✅ UI updates when ready
```

## Next: Production Verification

Once verified working:
1. Replace test Ad Unit IDs with production IDs
2. Remove or reduce debug logging
3. Monitor ad revenue in AdMob console
4. Track user engagement metrics
5. Optimize polling interval based on ad load times

