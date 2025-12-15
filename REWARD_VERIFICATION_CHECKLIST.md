# Reward System Verification Checklist

## Before Testing
- [ ] App is rebuilt: `flutter clean && flutter pub get && flutter run`
- [ ] Have access to Supabase SQL Editor
- [ ] Have console logs visible (Shift+D in terminal)
- [ ] Network connection is stable

## Test Sequence

### Test 1: Points Initialization Check
**Location:** Supabase SQL Editor

```sql
-- Should return your user record with points value
SELECT user_id, points, updated_at FROM user_points 
WHERE user_id = auth.uid();
```

**Expected Result:**
- ✅ Returns 1 row with your user_id and current points
- ❌ Returns empty = User points not initialized

**If empty, initialize:**
```sql
SELECT init_user_points(auth.uid());
```

---

### Test 2: Ad Watch with New Code
**Location:** ZinChat App > Earn Points screen

1. **Before watching:**
   - [ ] Tap "Sync Points" 
   - [ ] Note down current points (e.g., "10 points")
   - [ ] Check console for: No errors
   
2. **During watch:**
   - [ ] Tap "Watch Ad Now"
   - [ ] Ad loads within 60 seconds
   - [ ] Console shows: `🎬 Ad shown - watching started`
   - [ ] Watch ad to completion
   
3. **After watching:**
   - [ ] Console shows: `✅ REWARD CALLBACK FIRED: User earned 1 coin`
   - [ ] App shows: `🎉 +1 Point! Keep watching to earn more!` (green snackbar)
   - [ ] Console shows: `✅ Showing success message and reloading data`

**Note down these console logs:**
```
[Write down all messages from console]
```

4. **Verification:**
   - [ ] Tap "Sync Points"
   - [ ] Points increased by 1 (e.g., "10" → "11")
   - [ ] No error messages

---

### Test 3: Database Verification
**Location:** Supabase SQL Editor

Run each query and record results:

**Query 1: Check your points**
```sql
SELECT user_id, points FROM user_points WHERE user_id = auth.uid();
```
**Result:** Points = _____ (should be +1 from before)

---

**Query 2: Check ads watched**
```sql
SELECT COUNT(*) as total_ads, SUM(points_earned) as total_points
FROM reward_ads_watched WHERE user_id = auth.uid();
```
**Result:** 
- Total ads: _____
- Total points earned: _____
(Should match number of times "Reward callback fired" appeared)

---

**Query 3: Check daily limit**
```sql
SELECT ads_watched_today, last_reset 
FROM daily_ad_limits 
WHERE user_id = auth.uid()
AND CAST(last_reset AS DATE) = CURRENT_DATE;
```
**Result:**
- Ads watched today: _____
(Should be 1 if just watched 1 ad)

---

**Query 4: List all ads you've watched**
```sql
SELECT watched_at, points_earned, ad_unit_id
FROM reward_ads_watched 
WHERE user_id = auth.uid()
ORDER BY watched_at DESC LIMIT 5;
```
**Result:**
```
[Paste results]
```

---

## Troubleshooting Decision Tree

### Decision 1: Console Logs
**Did you see `✅ REWARD CALLBACK FIRED`?**

- **YES:** Go to Decision 2
- **NO:** 
  - ❌ Ad server didn't trigger reward
  - ✅ Solution: Try watching ad again, make sure to watch to completion
  - 💡 The test ad unit might not always trigger rewards properly

### Decision 2: Points Updated in UI?
**Did you see the green snackbar `🎉 +1 Point`?**

- **YES:** Go to Decision 3
- **NO:**
  - ❌ Database update failed
  - ✅ Solution: Run database verification queries
  - 💡 Check RLS policies

### Decision 3: Database Records Match?
**Run Query 4 above - do you see the ad you watched?**

- **YES:** 
  - ✅ Everything working correctly!
  - ✅ Points should be in database
  - ✅ "Sync Points" should show updated balance
  
- **NO:**
  - ❌ Ad was watched but not recorded
  - ✅ Solution: Check that callback is returning correct response
  - 💡 Likely network issue or database transaction failure

---

## Expected vs Actual

| Step | Expected | Actual | ✓/✗ |
|------|----------|--------|-----|
| Ad loads | Within 60s | __________ | __ |
| Console: Ad shown | `🎬 Ad shown` | __________ | __ |
| Console: Reward fired | `✅ REWARD CALLBACK FIRED` | __________ | __ |
| Console: Recording ad | `📝 Recording ad watched` | __________ | __ |
| Console: Record result | `📊 Record result: true` | __________ | __ |
| UI: Success popup | Shows green snackbar | __________ | __ |
| UI: Points refresh | Points +1 | __________ | __ |
| DB Query 1: Points | Increased by 1 | __________ | __ |
| DB Query 2: Ads watched | Shows as 1 | __________ | __ |
| DB Query 3: Daily limit | Shows as 1 | __________ | __ |
| DB Query 4: Ad details | Shows watched ad | __________ | __ |

---

## Common Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| Ad not loading | Error code 3 | Wait 24-48 hours for ad unit activation |
| No reward callback | Console shows: "Ad dismissed" but no reward | Watch ad to completion, not partial |
| Points not updating | Database shows no record | Check RLS policies in Supabase |
| UI not refreshing | Console shows success but UI doesn't update | Tap "Sync Points" to refresh manually |
| Daily limit bug | Can't watch more ads | Check `daily_ad_limits` table for reset time |

---

## Success Criteria

✅ You have successfully set up rewarded ads when:

1. [ ] Ad loads consistently
2. [ ] Reward callback fires (seen in console)
3. [ ] Points increase in wallet after watching
4. [ ] Database shows ad in `reward_ads_watched` table
5. [ ] Daily counter increments (0-10 limit works)
6. [ ] "Sync Points" shows correct balance
7. [ ] No error messages in console

---

## Support Information

If system is not working, provide:

1. **Console logs:**
   ```
   [Paste console output from watching an ad]
   ```

2. **Database check results:**
   ```
   [Paste output from Query 1-4 above]
   ```

3. **Points before/after:**
   - Before: _____ points
   - After: _____ points
   - Expected: _____ points
   - Difference: _____ points

4. **Error messages:**
   ```
   [Any error messages shown]
   ```

---

## Quick Command Reference

**Rebuild app:**
```bash
flutter clean && flutter pub get && flutter run
```

**Check console:**
Press `Shift+D` in terminal running Flutter

**Open Supabase SQL:**
1. Go to https://supabase.com
2. Select your project
3. SQL Editor > New Query

**Reset test (if needed):**
```sql
-- This CLEARS all reward history (BE CAREFUL!)
DELETE FROM reward_ads_watched WHERE user_id = auth.uid();
DELETE FROM daily_ad_limits WHERE user_id = auth.uid();
UPDATE user_points SET points = 0 WHERE user_id = auth.uid();
```

---

**Last Updated:** November 23, 2025
