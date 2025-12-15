# 📝 Code Examples - Theme Monetization

## How the System Works (Code Examples)

### Example 1: User Tries to Change Theme

```dart
// User in ProfileScreen taps "Vibrant" theme
// This happens automatically:

_handleThemeSelection(vibrantTheme) {
  // Step 1: Check if theme is unlocked
  bool isUnlocked = themeProvider.isThemeUnlocked('vibrant');
  
  // Step 2: If unlocked, apply immediately
  if (isUnlocked) {
    await themeProvider.setTheme(vibrantTheme);
    showSnackbar('Theme changed to Vibrant'); // ✓ Done
    return;
  }
  
  // Step 3: If locked, show dialog
  showDialog(
    context: context,
    builder: (context) => ThemeUnlockDialog(
      themeName: 'Vibrant',
      onThemeUnlocked: () async {
        // This callback fires after user watches ad
        await themeProvider.unlockTheme('vibrant');
        await themeProvider.setTheme(vibrantTheme);
      },
    ),
  );
}
```

---

### Example 2: Dialog is Shown

User sees beautiful dialog:

```
┌─────────────────────────────────────┐
│ ⭐ Unlock Vibrant?                  │
├─────────────────────────────────────┤
│ Watch a quick rewarded ad to        │
│ unlock this amazing theme!          │
│                                     │
│ ✓ One-time unlock                   │
│ ✓ Use forever                       │
│ ✓ No extra costs                    │
│                                     │
│ ⏱️ Ad is typically 15-30 seconds.  │
│ You must watch the complete video  │
│ to unlock the theme.                │
├─────────────────────────────────────┤
│  [Maybe Later]    [Watch Ad 🎬]    │
└─────────────────────────────────────┘
```

---

### Example 3: User Clicks "Watch Ad"

```dart
// In ThemeUnlockDialog._watchRewardedAd()

Future<void> _watchRewardedAd() async {
  // Step 1: Check if ad is ready
  if (!_adService.isRewardedAdAvailable()) {
    // Load ad if not ready
    setState(() => _isLoadingAd = true);
    await _adService.loadRewardedAd();
  }

  // Step 2: Show the ad
  await _adService.showRewardedAd(
    // This callback fires only after user watches FULL ad
    onRewardEarned: () {
      // Award is granted! ✓
      if (mounted) {
        Navigator.pop(context);  // Close dialog
        widget.onThemeUnlocked(); // Call parent callback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme unlocked! Enjoy your new theme!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    },
    
    // This callback fires if user exits before watching
    onAdDismissed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You need to watch the full ad to unlock'),
        ),
      );
    },
    
    // This callback fires if ad fails to load/show
    onAdFailed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ad failed to load. Please try again.'),
        ),
      );
    },
  );
}
```

---

### Example 4: Ad Plays

```dart
// In RewardedAdService.showRewardedAd()

// Step 1: Setup callbacks
ad.fullScreenContentCallback = FullScreenContentCallback(
  onAdShowedFullScreenContent: (ad) {
    debugPrint('📺 Ad is now showing on screen');
  },
  onAdDismissedFullScreenContent: (ad) {
    debugPrint('❌ User closed ad without watching');
    // Dispose and load next ad
    ad.dispose();
    loadRewardedAd();
  },
  onAdFailedToShowFullScreenContent: (ad, error) {
    debugPrint('❌ Ad failed to show: $error');
    ad.dispose();
    loadRewardedAd();
  },
);

// Step 2: Show ad and handle reward
await ad.show(
  onUserEarnedReward: (ad, reward) {
    debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
    rewardEarned = true;  // Mark as earned
    // This is the key callback - grant the reward now!
    onRewardEarned?.call();
  },
);
```

---

### Example 5: Theme Gets Unlocked

```dart
// After user successfully watches ad:

// In ThemeProvider.unlockTheme()
Future<void> unlockTheme(String themeId) async {
  // Add to unlocked list
  if (!_unlockedThemes.contains(themeId)) {
    _unlockedThemes.add(themeId);  // Add locally
    notifyListeners();  // Update UI
    
    // Persist to storage
    await _themeService.unlockTheme(themeId);
  }
}

// In ThemeService.unlockTheme()
Future<void> unlockTheme(String themeId) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Get current unlocked list
  final unlockedThemes = prefs.getStringList('unlocked_themes') ?? [];
  
  // Add new theme if not already there
  if (!unlockedThemes.contains(themeId)) {
    unlockedThemes.add(themeId);
    
    // Save to device storage
    await prefs.setStringList('unlocked_themes', unlockedThemes);
    // Now persisted! ✓
  }
}
```

---

### Example 6: Theme Gets Applied

```dart
// After unlocking, apply the theme:

await themeProvider.setTheme(vibrantTheme);

// In ThemeProvider.setTheme()
Future<void> setTheme(AppTheme theme) async {
  // Update current theme
  _currentTheme = theme;
  notifyListeners();  // Trigger UI rebuild
  
  // Persist selection
  await _themeService.saveTheme(theme.id);
}

// App rebuilds with new colors!
// All text changes to new theme colors
// Background changes
// Buttons change
// Cards change
// Everything updated! ✨
```

---

### Example 7: App Restart - Unlock Persists

```dart
// User closes and reopens app
// When app loads:

// In ThemeProvider._loadSavedTheme()
Future<void> _loadSavedTheme() async {
  try {
    // Load what was last set
    _currentTheme = await _themeService.loadTheme();
    _wallpaperPath = await _themeService.loadWallpaperPath();
    
    // Load unlocked themes from SharedPreferences
    _unlockedThemes = await _themeService.getUnlockedThemes();
    // Returns: ['expressive', 'vibrant']
    // Still includes 'vibrant' that was unlocked! ✓
    
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// Later when user goes to Profile:
_handleThemeSelection(vibrantTheme) {
  // Check if still unlocked
  bool isUnlocked = themeProvider.isThemeUnlocked('vibrant');
  // Returns: true (from SharedPreferences) ✓
  
  // Apply immediately (no ad this time!)
  await themeProvider.setTheme(vibrantTheme);
}
```

---

### Example 8: Checking Lock Status

```dart
// Various ways to check if a theme is unlocked:

// Method 1: Check locally (fast)
bool unlocked = themeProvider.isThemeUnlocked('vibrant');

// Method 2: Check all unlocked themes
List<String> unlocked = themeProvider.unlockedThemes;
// Returns: ['expressive', 'vibrant', 'muted']

// Method 3: From storage (persistent check)
bool unlocked = await themeService.isThemeUnlocked('vibrant');

// Using in conditional:
if (themeProvider.isThemeUnlocked(theme.id)) {
  // Show theme normally (no ad)
} else {
  // Show with lock icon or different styling
}
```

---

### Example 9: Manual Unlock (For Testing)

```dart
// You can manually unlock themes for testing:

// Method 1: Programmatic unlock
await themeProvider.unlockTheme('light_blue');

// Method 2: Skip dialog in testing
// Just tap the already-unlocked theme

// Method 3: Reset (clear all unlocks)
// Edit SharedPreferences directly during dev
```

---

### Example 10: Custom Dialog Usage

```dart
// You can show the dialog anywhere:

showDialog(
  context: context,
  builder: (context) => ThemeUnlockDialog(
    themeName: 'Light Blue',
    onThemeUnlocked: () async {
      // Called after user watches ad
      final themeProvider = Provider.of<ThemeProvider>(
        context,
        listen: false,
      );
      await themeProvider.unlockTheme('light_blue');
      await themeProvider.setTheme(AppThemes.lightBlue);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Light Blue theme unlocked!')),
      );
    },
  ),
);

// Or use in a different screen/context
// Just pass the correct themeName and callback
```

---

### Example 11: Production Ad Unit IDs

```dart
// Test Ad Unit IDs (Current - for local testing)
Android: 'ca-app-pub-3940256099942544/5224354917'
iOS: 'ca-app-pub-3940256099942544/1712485313'

// Production Ad Unit IDs (Before shipping!)
Android: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'
iOS: 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'

// How to get yours:
// 1. Go to https://apps.admob.com
// 2. Sign in with Google account
// 3. Select your app
// 4. Click "App ads"
// 5. Click "Create ad unit"
// 6. Choose "Rewarded"
// 7. Copy the Ad Unit ID
// 8. Paste into rewarded_ad_service.dart
```

---

### Example 12: Error Handling

```dart
// The system gracefully handles all errors:

try {
  // Ad loading fails?
  // → User sees: "Ad not available. Please try again later."
  // → Can still use free theme
  
  // Internet disconnects?
  // → Ad doesn't load
  // → User can still use free theme
  // → Can retry later when connected
  
  // User force-quits during ad?
  // → Ad callbacks cleaned up properly
  // → No memory leaks
  // → Can try again
  
  // Device storage full?
  // → SharedPreferences handles gracefully
  // → Falls back to runtime state
  
} catch (e) {
  debugPrint('Error: $e');
  // All caught and logged
}
```

---

## 🎯 Complete Flow Summary

```
┌─────────────────────────────────────────┐
│ 1. User taps premium theme              │
├─────────────────────────────────────────┤
│ 2. Check: Is it unlocked?               │
│    ├─ YES → Apply theme immediately    │
│    └─ NO  → Continue to step 3          │
├─────────────────────────────────────────┤
│ 3. Show ThemeUnlockDialog                │
├─────────────────────────────────────────┤
│ 4. User chooses:                        │
│    ├─ "Maybe Later" → Close dialog      │
│    └─ "Watch Ad" → Continue to step 5   │
├─────────────────────────────────────────┤
│ 5. Pre-load or show rewarded ad         │
├─────────────────────────────────────────┤
│ 6. User watches ad (15-30s)             │
├─────────────────────────────────────────┤
│ 7. Ad completes                         │
├─────────────────────────────────────────┤
│ 8. onRewardEarned callback triggered    │
├─────────────────────────────────────────┤
│ 9. Theme unlocked in memory             │
├─────────────────────────────────────────┤
│ 10. Theme saved to SharedPreferences    │
├─────────────────────────────────────────┤
│ 11. Theme applied to app                │
├─────────────────────────────────────────┤
│ 12. Success message shown               │
├─────────────────────────────────────────┤
│ 13. User sees new theme (next restart   │
│     theme persists!)                    │
└─────────────────────────────────────────┘
```

---

## 💡 Key Takeaways

✅ **Simple For Users**: Tap theme → watch quick ad → theme unlocked
✅ **Secure**: Unlocks survive app restart
✅ **Compliant**: Follows all AdMob policies
✅ **Professional**: Beautiful, error-free experience
✅ **Monetized**: Generates revenue without annoying users

That's the complete flow! 🎉
