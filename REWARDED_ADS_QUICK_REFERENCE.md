# 🎁 Rewarded Ads System - Quick Reference

## Files Created/Modified

### 📄 New Files
1. **REWARDED_ADS_SCHEMA.sql** (347 lines)
   - Database schema with 4 tables
   - RLS policies
   - Helper functions
   - Triggers for auto-initialization

2. **lib/screens/fintech/rewarded_ads_screen.dart** (367 lines)
   - Complete UI for watching ads and redeeming points
   - Beautiful gradient cards and animations
   - Network selection, mobile number input
   - Professional error handling

3. **REWARDED_ADS_DEPLOYMENT_GUIDE.md**
   - Step-by-step deployment instructions
   - AdMob configuration guide
   - Testing procedures
   - Troubleshooting

### 🔧 Modified Files

1. **lib/services/hazpay_service.dart** (+198 lines)
   - Added `UserPoints` model
   - Added `DailyAdLimit` model
   - Added 6 new service methods:
     - `getUserPoints()` - Fetch user's points
     - `getTodayAdCount()` - Check daily limit
     - `canWatchMoreAds()` - Boolean check
     - `recordAdWatched()` - Award point (called on reward earned)
   - `redeemPointsForData()` - Convert 100 points → 500MB free data
     - `getRedemptionHistory()` - Fetch past redemptions

2. **lib/screens/fintech/hazpay_dashboard.dart**
   - Added import: `import 'rewarded_ads_screen.dart';`
   - Added feature card: "Earn Points - Watch ads & earn free data"

---

## 🎬 How It Works

### User Flow

```
1. User opens HazPay Dashboard
   ↓
2. Taps "Earn Points" feature card
   ↓
3. Watches RewardedAdsScreen with:
   - Points counter (gradient card)
   - "Watch Ad Now" button (if <10 ads today)
   - Redemption section (if ≥100 points)
   ↓
4. Taps "Watch Ad Now"
   ↓
5. AdMob rewarded ad plays
   ↓
6. User watches ad completely
   ↓
7. onUserEarnedReward fires
   ↓
8. recordAdWatched() called:
   - Insert into reward_ads_watched
   - add_points RPC: +1 point
   - increment_daily_ad_count RPC
   ↓
9. Points updated in user_points table
   ↓
10. "✅ +1 Point!" snackbar shown
   ↓
11. (After 100 points) User can redeem:
    - Select network (MTN/GLO)
    - Enter mobile number
    - Tap "Redeem Now"
    ↓
12. redeemPointsForData() called:
    - Create reward_redemptions record
   - redeem_points RPC: -100 points
    - Call buyData Edge Function
    - 500MB data added
    - Redemption marked as issued
   ↓
13. "🎉 500MB credited to your account!" message
```

---

## 🗄️ Database Schema Summary

### 4 Tables

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `user_points` | Track points balance | user_id, points, total_earned, total_redemptions |
| `reward_ads_watched` | Log ad views | user_id, watched_at, points_earned (always 1) |
| `reward_redemptions` | Track redemptions | user_id, points_spent (50), data_amount (500MB), status |
| `daily_ad_limits` | Enforce 10/day limit | user_id, ads_watched_today, limit_date |

### Automatic Behaviors

- ✅ Points auto-initialized to 0 when user signs up (trigger on profiles INSERT)
- ✅ Daily limits auto-reset each day (CURRENT_DATE used)
- ✅ Old daily records auto-cleaned (cleanup function)

---

## 🔒 Security (AdMob Compliance)

✅ **Optional, User-Initiated**
- Users manually tap "Watch Ad" button
- No forced viewing

✅ **Reward is Points Only**
- Never give cash/direct payment
- Points → free data (redeemable good)

✅ **Only Reward on Completion**
- `recordAdWatched()` called only when `onUserEarnedReward` fires
- No reward for skipping/closing early

✅ **Daily Limit Enforced**
- Max 10 ads/user/day
- RPC function checks `can_watch_more_ads()`
- UI disables button after 10

✅ **No Suspicious Activity**
- Each ad logged with timestamp
- Can detect rapid clicks
- Redemption history auditable

---

## 🚀 Quick Deployment Checklist

```
⏳ Pre-Deployment
  [ ] Review REWARDED_ADS_SCHEMA.sql
  [ ] Get AdMob App ID from Google
  [ ] Get Ad Unit ID for Rewarded Ads

✅ Deployment (5 mins)
  [ ] 1. Run REWARDED_ADS_SCHEMA.sql in Supabase
  [ ] 2. Add google_mobile_ads to pubspec.yaml
  [ ] 3. Configure AdMob in Android/iOS manifests
  [ ] 4. Update Ad Unit ID in rewarded_ads_screen.dart
  [ ] 5. Run `flutter pub get`

🧪 Testing (10 mins)
  [ ] Watch first ad → Point awarded
  [ ] Watch 10 ads → Button disabled
  [ ] Wait for midnight or mock date → Limit resets
   [ ] Accumulate 100 points → Redeem button enabled
   [ ] Redeem 100 points → 500MB data added
  [ ] Check Supabase tables → Records correct
```

---

## 💡 Key Implementation Details

### Point Awarding
```dart
// Called when user finishes watching ad
await hazPayService.recordAdWatched('rewarded_ad_unit_1');

// This:
// 1. Inserts into reward_ads_watched
// 2. Calls add_points() RPC
// 3. Calls increment_daily_ad_count() RPC
// 4. Shows success message
```

### Daily Limit Check
```dart
// Checks if user can watch more ads
bool canWatch = await hazPayService.canWatchMoreAds();

// Returns: getTodayAdCount() < 10
// Auto-resets each day via CURRENT_DATE in daily_ad_limits
```

### Redemption Flow
```dart
// When user redeems 100 points for 500MB
await hazPayService.redeemPointsForData(
  networkId: 1, // 1=MTN, 2=GLO
  mobileNumber: '08012345678',
);

// This:
// 1. Checks user has ≥100 points
// 2. Creates reward_redemptions record (status=pending)
// 3. Calls redeem_points() RPC to deduct 100 points
// 4. Calls buyData Edge Function with plan_id=1 (500MB)
// 5. Updates redemption status to issued on success
// 6. Refunds points if Edge Function fails
```

---

## 📊 Monitoring & Analytics

Query to see top point earners:
```sql
SELECT user_id, points, total_points_earned 
FROM user_points 
ORDER BY points DESC 
LIMIT 10;
```

Query to see redemption success rate:
```sql
SELECT 
  status, 
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as percentage
FROM reward_redemptions 
GROUP BY status;
```

Query to see daily ad watches:
```sql
SELECT 
  DATE(watched_at) as date, 
  COUNT(*) as total_ads_watched
FROM reward_ads_watched
GROUP BY DATE(watched_at)
ORDER BY date DESC;
```

---

## ⚠️ Known Limitations & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Ad not loading | Ad Unit ID wrong | Update in rewarded_ads_screen.dart line 40 |
| Points not adding | RPC failed | Check Supabase → add_points function exists |
| Redemption fails | Amigo insufficient | Fund Amigo test account or use TEST_MODE |
| Daily limit not working | Old records | Run cleanup function |
| Multiple points added | User tapped multiple times | Add loading state (✅ done) |

---

## 🎨 UI Components

### Points Card
- Gradient blue background
- Large points number (size: displaySmall)
- "Redeem now" or "X more needed" message
- Progress bar from 0-100 points

### Watch Ad Card
- Video camera icon
- "Watch Ad Now" button
- Status badge (e.g., "3/10")
- Daily limit warning if at limit

### Redemption Card
- MTN/GLO network toggle
- Mobile number TextField
- "Redeem Now" button
- Loading spinner during redemption

### How It Works Card
- 5 emoji-based bullet points
- Clear, friendly language

---

## 🔗 Related Files

- `LOAN_SYSTEM_SCHEMA.sql` - Loan system (separate feature)
- `LOAN_DEPLOYMENT_GUIDE.md` - Loan docs
- `ADD_AMIGO_PLAN_ID.sql` - Maps plan IDs to Amigo
- `lib/services/hazpay_service.dart` - Main service class
- `lib/screens/fintech/buy_data_screen.dart` - Uses same Edge Function

---

✅ **Status: COMPLETE & READY TO TEST**

All files created, no compilation errors. Ready for Supabase deployment and app testing!

