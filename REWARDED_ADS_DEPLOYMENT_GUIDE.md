# Rewarded Ads System - Deployment & Setup Guide

## 🎯 Overview

The Rewarded Ads system allows users to:
- 📺 Watch AdMob rewarded ads to earn 1 point per ad
- 📈 Accumulate points in their account
- 🎁 Redeem 100 points for 500MB free MTN/GLO data
- ⏱️ Maximum 10 ads watched per day (auto-resets)

**Compliance**: Optional, user-initiated ads only. Rewards are points (not cash).

---

## 📋 Deployment Steps

### 1. Deploy Database Schema

**Run in Supabase SQL Editor:**

```sql
-- Copy entire contents of REWARDED_ADS_SCHEMA.sql and paste into Supabase SQL Editor
-- This creates:
-- - user_points table
-- - reward_ads_watched table
-- - reward_redemptions table
-- - daily_ad_limits table
-- - Helper functions for points management
-- - RLS policies for security
-- - Automatic triggers for user initialization
```

**File:** `REWARDED_ADS_SCHEMA.sql`

✅ **Result**: All 4 tables created with indexes, RLS policies, and helper functions

---

### 2. Update pubspec.yaml

Add Google Mobile Ads dependency:

```yaml
dependencies:
  google_mobile_ads: ^3.0.0
```

Then run:
```bash
flutter pub get
```

---

### 3. Configure AdMob in Your App

**Android (android/app/AndroidManifest.xml):**

```xml
<manifest ...>
  <!-- Add AdMob meta-data -->
  <application ...>
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyyyyyy"/>
  </application>
</manifest>
```

**iOS (ios/Runner/Info.plist):**

```plist
<dict>
  ...
  <key>GADApplicationIdentifier</key>
  <string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyyyyyy</string>
</dict>
```

Replace `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyyyyyy` with your Google AdMob App ID.

---

### 4. Get Your Rewarded Ad Unit ID

1. Go to [Google AdMob Console](https://admob.google.com)
2. Create a new Rewarded Ad Unit
3. Copy the Ad Unit ID (format: `ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyyyyyy`)

---

### 5. Update rewarded_ads_screen.dart

Replace the placeholder Ad Unit ID in `lib/screens/fintech/rewarded_ads_screen.dart`:

**Line 40:**
```dart
adUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyyyyyy', // Replace with your actual Ad Unit ID
```

---

### 6. Service Methods Already Added

All methods are in `lib/services/hazpay_service.dart`:

- `getUserPoints()` - Get user's current points
- `getTodayAdCount()` - Get ads watched today (max 10)
- `canWatchMoreAds()` - Check if user can watch more ads
- `recordAdWatched()` - Record ad + add 1 point (called when `onUserEarnedReward` fires)
 - `redeemPointsForData()` - Redeem 100 points for 500MB free data
- `getRedemptionHistory()` - Get past redemptions

---

### 7. UI Already Integrated

✅ **File:** `lib/screens/fintech/rewarded_ads_screen.dart`
- Beautiful points counter with gradient card
- Watch Ad button with daily limit indicator
- Redemption section with network selection
- How-it-works section
- Professional UI with proper error handling

✅ **File:** `lib/screens/fintech/hazpay_dashboard.dart`
- Added import for `rewarded_ads_screen.dart`
- Added "Earn Points" feature card with navigation

---

## 🧪 Testing Flow

### Test 1: Watch Ad & Earn Points
1. Open HazPay Dashboard
2. Tap "Earn Points" feature card
3. Tap "Watch Ad Now"
4. Complete the ad fully
5. Verify: `✅ +1 Point!` message appears
6. Refresh page → Points should increment

### Test 2: Daily Ad Limit
1. Watch 10 ads (simulate with TEST_MODE)
2. Try to watch 11th ad
3. Verify: "Daily ad limit reached. Try again tomorrow."

### Test 3: Redeem Points
1. Accumulate 100+ points
2. Select network (MTN/GLO)
3. Enter mobile number
4. Tap "Redeem Now"
5. Verify: 500MB data added to account
6. Check Supabase: `reward_redemptions` shows `status='issued'`
7. Check points: Decreased by 100

### Test 4: Insufficient Points
1. Try to redeem with <100 points
2. Verify: Error message "You need at least 100 points"

---

## 🛡️ Compliance Checklist

✅ **Ads are optional, user-initiated only**
- Users must tap button to watch

✅ **Reward is points, not cash**
- Points only redeemable for free data

✅ **Never require clicking the ad**
- Reward fires only on `onUserEarnedReward`

✅ **Follow AdMob rules**
- No incentives for downloading other apps
- No inflating impression/click rates
- Only reward for completing 100% of ad

✅ **Daily limit enforced**
- Max 10 ads per user per day
- Resets at midnight

---

## 📊 Database Structure

### user_points Table
```
id                    UUID
user_id              UUID (unique, auto-initialized)
points               INT (0-9999)
total_points_earned  INT (lifetime count)
total_redemptions    INT (lifetime count)
created_at           TIMESTAMP
updated_at           TIMESTAMP
```

### reward_ads_watched Table
```
id                UUID
user_id          UUID
ad_unit_id       TEXT
points_earned    INT (always 1)
watched_at       TIMESTAMP
```

### reward_redemptions Table
```
id              UUID
user_id         UUID
points_spent    INT (100)
data_amount     TEXT ('500MB')
network_id      INT (1=MTN, 2=GLO)
status          TEXT (pending/issued/failed)
transaction_id  TEXT
failure_reason  TEXT
redeemed_at     TIMESTAMP
created_at      TIMESTAMP
```

### daily_ad_limits Table
```
id               UUID
user_id          UUID
ads_watched_today INT (0-10)
limit_date       DATE (resets each day)
created_at       TIMESTAMP
updated_at       TIMESTAMP
```

---

## 🔧 Helper Functions (RPC Calls)

### get_daily_ad_count(user_id)
Returns today's ad watch count (0-10)

### can_watch_more_ads(user_id)
Returns true if user can watch more ads today

### increment_daily_ad_count(user_id)
Increments and returns new count

### add_points(user_id, points)
Adds points to user account

### redeem_points(user_id, points)
Deducts points from user account

---

## 🐛 Troubleshooting

### Ad Not Loading
- ✅ Ensure AdMob App ID is correctly set
- ✅ Verify Ad Unit ID in `rewarded_ads_screen.dart`
- ✅ Check device has internet connection
- ✅ Use real device (emulator may have issues)

### Points Not Adding
- ✅ Verify `record_ad_watched()` RPC function exists
- ✅ Check user_points table is initialized for user
- ✅ Check RLS policies allow user to update their own points

### Redemption Fails
- ✅ Verify 500MB plan exists in pricing table (plan_id=1)
- ✅ Verify mobile number format is correct
- ✅ Check Amigo account has sufficient credit for test
- ✅ Check Edge Function `buyData` is deployed

### Daily Limit Not Working
- ✅ Verify `increment_daily_ad_count()` RPC function exists
- ✅ Check `daily_ad_limits` table has entry for today

---

## 📱 UI Features

### Points Display Card
- Gradient blue background
- Shows current points
- Shows points needed to redeem
- Progress bar (0-100 points)

### Watch Ad Section
- Shows ads watched today (X/10)
- "Watch Ad Now" button (disabled if ad loading)
- Status: "Ad ready to watch" or "Loading ad..."
- Daily limit notice when limit reached

### Redemption Section
- Network selector (MTN/GLO toggle)
- Mobile number input field
- "Redeem Now" button (disabled until ready)
- Shows points needed if <100

### How It Works
- 5 bullet points explaining the system
- Clear, easy to understand

---

## 🚀 Next Steps (Optional Enhancements)

- [ ] Add more reward denominations (1GB, 2GB, etc.)
- [ ] Implement streak bonuses (bonus points for daily watching)
- [ ] Add leaderboard for top point earners
- [ ] Email notifications for redemption status
- [ ] Share/refer program (bonus points for referrals)
- [ ] Monthly reward report

---

## 📞 Support

If you encounter issues:

1. **Check Supabase logs**: Functions → requestLoan & buyData
2. **Check app logs**: Use `flutter logs` to see debugPrint messages
3. **Verify RLS**: Check Supabase table policies are enabled
4. **Test RPC manually**: Run functions in SQL editor

---

✅ **Complete Setup Checklist**

- [ ] SQL schema deployed to Supabase
- [ ] `google_mobile_ads` added to pubspec.yaml
- [ ] AdMob App ID configured in Android/iOS
- [ ] Ad Unit ID updated in `rewarded_ads_screen.dart`
- [ ] App compiled and tested on device
- [ ] First ad watched successfully
- [ ] Points appeared in user_points table
- [ ] Redemption works end-to-end

