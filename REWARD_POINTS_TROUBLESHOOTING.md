# AdMob Reward Not Added - Troubleshooting Guide

## Problem
You watched 2 ads but no reward points were added to your account.

## Root Cause Analysis

This can happen for several reasons:

### 1. **Reward Callback Not Triggered** (Most Common)
The `onUserEarnedReward` callback might not have been called even though the ad played.

**Why this happens:**
- Google's test ad unit doesn't always trigger the reward callback properly
- The ad might have been dismissed before completion
- Ad had no fill (couldn't load properly)

### 2. **Reward Recorded But Points Not Updated** (Less Common)
The ad was recorded, but the points weren't credited due to:
- RLS (Row Level Security) policy blocking the update
- Database transaction error
- User not properly authenticated

### 3. **Points Updated But UI Not Refreshed**
Points were actually added, but the screen didn't refresh to show them.

---

## Diagnostic Steps (Do These Now)

### Step 1: Check Database Records
Go to Supabase Console and run the SQL queries in `CHECK_AD_REWARDS.sql`:

1. Navigate to SQL Editor
2. Copy and run each query to check:
   - Your current points balance
   - All ads you watched (reward_ads_watched table)
   - Your daily ad count (daily_ad_limits table)
   - Total rewards earned

**What to look for:**
- ✅ If `reward_ads_watched` shows 2 records = Backend recorded the ads
- ❌ If `reward_ads_watched` is empty = Reward callback never fired
- ✅ If `user_points.points` is updated = Points were credited
- ❌ If `user_points.points` didn't change = Points weren't credited

### Step 2: Check Console Logs
When you watched the ads, you should have seen logs like:

**✅ GOOD - Complete sequence:**
```
🎬 Ad shown - watching started
✅ REWARD CALLBACK FIRED: User earned 1 coin
📝 Recording ad watched...
📊 Record result: true
🎉 Showing success message and reloading data
```

**❌ BAD - Missing reward callback:**
```
🎬 Ad shown - watching started
📱 Ad dismissed
⚠️ WARNING: Ad dismissed but no reward callback
```

**What to do:**
- If you see logs, send them to check what happened
- If no logs, ad SDK might not be initialized properly

### Step 3: Manual Point Verification
In Supabase SQL Editor, run this to see your exact point balance:

```sql
SELECT * FROM user_points WHERE user_id = auth.uid();
```

Record the number shown in the `points` column.

---

## Solutions

### Solution 1: Use the "Sync Points" Button (New!)
We added a **"Sync Points"** button to the Earn Points screen:

1. Open the app
2. Go to **HazPay Dashboard**
3. Tap **"Earn Points"** card
4. Tap **"Sync Points"** button
5. This will refresh your points from database

The button will show your actual balance even if the UI didn't update.

### Solution 2: Rebuild App with Enhanced Logging
We enhanced the ad-watching code with better error messages:

```bash
flutter clean
flutter pub get
flutter run
```

Now when you watch ads, you'll see detailed console logs telling you exactly what's happening.

### Solution 3: Check Database Permissions
If ads are recorded but points not credited, it's a permissions issue.

Run this in Supabase SQL Editor to check your user_points row:

```sql
-- Check if your user_points record exists
SELECT id, user_id, points, updated_at FROM user_points 
WHERE user_id = auth.uid();

-- If empty, run this to initialize:
SELECT init_user_points(auth.uid());
```

### Solution 4: Test with a Fresh Ad Watch
Now that we improved the code:

1. Tap **"Sync Points"** to get current balance
2. Tap **"Watch Ad Now"**
3. **Watch the entire ad to completion** (don't skip)
4. Wait for the success popup
5. Check console logs (Shift+D in terminal)
6. Tap **"Sync Points"** again to verify

You should see:
- Success popup: "🎉 +1 Point! Keep watching to earn more!"
- Points increase by 1

---

## What We Changed Today

### 1. Enhanced Logging in rewarded_ads_screen.dart
Added detailed debugging to track:
- ✅ When reward callback fires
- ✅ When record is created in database
- ✅ When points are credited
- ✅ Success/failure of each step
- ✅ When ad is dismissed

### 2. Added "Sync Points" Button
- New button to manually refresh points from database
- Shows actual database value, not cached value
- Helps verify if points were actually credited

### 3. Improved Error Handling
- Better error messages if ad fails
- Shows why reward wasn't recorded
- Helps identify permission issues

---

## How Rewards Actually Work (Technical)

```
User taps "Watch Ad Now"
        ↓
Google ad server sends ad
        ↓
Ad plays on screen
        ↓
User watches to end
        ↓
Google triggers onUserEarnedReward callback ← THIS MUST HAPPEN
        ↓
recordAdWatched() is called
        ↓
Insert into reward_ads_watched table
        ↓
Call add_points() RPC function
        ↓
user_points.points += 1
        ↓
increment_daily_ad_count() called
        ↓
daily_ad_limits.ads_watched_today += 1
        ↓
Success popup shows
        ↓
Points display refreshes
```

**If reward callback never fires** = Points are never recorded. This is usually because:
- Ad didn't play to completion
- Ad network didn't send callback
- SDK not initialized properly

---

## Database Schema Reference

### reward_ads_watched Table
Records every ad watched:
```
id (UUID)
user_id (UUID) - Who watched it
ad_unit_id (String) - Which ad unit
points_earned (Integer) - Always 1
watched_at (Timestamp) - When watched
```

### daily_ad_limits Table
Tracks ads watched today:
```
id (UUID)
user_id (UUID)
ads_watched_today (Integer) - 0-10
last_reset (Timestamp) - When counter reset
```

### user_points Table
Stores total points:
```
id (UUID)
user_id (UUID)
points (Integer) - Total lifetime points
updated_at (Timestamp)
```

---

## FAQ

**Q: I watched 2 ads but no points showed. Where are my points?**

A: They're most likely not recorded in the database yet. Check `reward_ads_watched` table to see if ads were recorded. If they are, the points should be in `user_points` table.

**Q: The app showed a success message but points didn't increase**

A: The success message was triggered, but the database update failed. This is usually a RLS policy issue. Run the database checks from Step 1.

**Q: Can I manually add points?**

A: Yes, in Supabase SQL Editor, but this is not recommended. Better to verify why the automatic system failed.

**Q: How do I know if my RLS policies are correct?**

A: If you can't update `user_points`, you'll see an error in the database query. Run this test:

```sql
-- This should return 1 (can update)
UPDATE user_points 
SET points = points + 1 
WHERE user_id = auth.uid()
RETURNING points;
```

If it fails, RLS is blocking it.

---

## Next Steps

1. **Run database checks** (use CHECK_AD_REWARDS.sql)
2. **Tap "Sync Points"** to refresh UI
3. **Watch a test ad** with new enhanced code
4. **Check console logs** for detailed output
5. **Report back** with:
   - Database query results
   - Console logs from watching an ad
   - Whether "Sync Points" shows correct balance

---

## Files Modified Today

| File | Change |
|------|--------|
| `rewarded_ads_screen.dart` | Added enhanced logging, "Sync Points" button, improved error handling |
| `main.dart` | Ensured AdMob initialization |
| `CHECK_AD_REWARDS.sql` | New - SQL queries to verify database records |

## Support

If points are still not working after these steps:

1. Send console logs from watching an ad
2. Send database query results from CHECK_AD_REWARDS.sql
3. Specify which watch (1st or 2nd) failed
4. Include error messages if any

---

**Last Updated:** November 23, 2025  
**Status:** Investigating and enhanced with better diagnostics
