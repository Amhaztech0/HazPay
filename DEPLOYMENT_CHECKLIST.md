# DEPLOYMENT CHECKLIST

## Pre-Deployment (Do This First)

### Environment Preparation
- [ ] Back up your Supabase database
- [ ] Get PAYSCRIBE_API_KEY from Payscribe dashboard
- [ ] Verify internet connectivity
- [ ] Clear browser cache

### Code Review
- [ ] Review PAYSCRIBE_MIGRATION.sql
- [ ] Review Edge Function code
- [ ] Review Dart service code
- [ ] Check all imports are correct

---

## Phase 1: Database Deployment

### SQL Migration
- [ ] Copy entire PAYSCRIBE_MIGRATION.sql file
- [ ] Go to Supabase Dashboard → SQL Editor
- [ ] Click "+ New Query"
- [ ] Paste SQL content
- [ ] Click "Run"
- [ ] Wait for "Query completed successfully"

### Verification
Run these queries in SQL Editor to confirm:

```sql
-- Check MTN plans were imported
SELECT COUNT(*) as mtn_plans FROM pricing 
WHERE network_id = 1;
-- Expected: 50+

-- Check Airtel (new)
SELECT COUNT(*) as airtel_plans FROM pricing 
WHERE network_id = 3;
-- Expected: 50+

-- Check bills table exists
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_name = 'bills_payments';
-- Expected: 1

-- Check discos table exists
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_name = 'electricity_discos';
-- Expected: 1

-- Sample plan check
SELECT plan_id, payscribe_plan_id, sell_price, cost_price 
FROM pricing WHERE network_id = 1 LIMIT 3;
```

**Verification Checklist:**
- [ ] 50+ MTN plans found
- [ ] 50+ Airtel plans found
- [ ] bills_payments table exists
- [ ] electricity_discos table exists
- [ ] Sample plans show PSPLAN_* format

---

## Phase 2: Environment Configuration

### Set Secrets
- [ ] Go to Supabase Dashboard → Settings → Secrets
- [ ] Click "New secret"
- [ ] Name: `PAYSCRIBE_API_KEY`
- [ ] Value: `Bearer your_actual_key_here`
- [ ] Click "Save"

### Verify Secrets
- [ ] PAYSCRIBE_API_KEY appears in secrets list
- [ ] No syntax errors shown
- [ ] Can see beginning of key (masked)

---

## Phase 3: Edge Function Deployment

### 1. Deploy buyData Function

**File Source:** `supabase/functions/buyData/index_payscribe.ts`

Steps:
- [ ] Go to Supabase Dashboard → Edge Functions
- [ ] Click "Deploy a new function"
- [ ] Name: `buyData` (exact match)
- [ ] Region: Select your region
- [ ] Copy entire contents of `index_payscribe.ts`
- [ ] Paste into editor
- [ ] Click "Deploy"
- [ ] Wait for green checkmark
- [ ] Go to existing "buyData" function (if exists)
- [ ] Replace `index.ts` with new content
- [ ] Click "Save"

**Verification:**
- [ ] Function shows as deployed
- [ ] No error messages in logs
- [ ] Function is callable

### 2. Deploy payBill Function

**File Source:** `supabase/functions/payBill/index.ts`

Steps:
- [ ] Click "Deploy a new function"
- [ ] Name: `payBill`
- [ ] Copy entire contents of `payBill/index.ts`
- [ ] Paste into editor
- [ ] Click "Deploy"
- [ ] Wait for confirmation

**Verification:**
- [ ] Function shows as deployed
- [ ] No error messages in logs

### 3. Update requestLoan Function

**File Source:** `supabase/functions/requestLoan/index.ts`

Steps:
- [ ] Find existing "requestLoan" function
- [ ] Click to edit
- [ ] Copy entire contents of updated `index.ts`
- [ ] Replace all existing code
- [ ] Click "Save"
- [ ] Function redeploys automatically

**Verification:**
- [ ] Function shows as deployed
- [ ] No error messages in logs

### Test Edge Functions (Optional)

Test in Supabase → Edge Functions → Testing tab:

```bash
# Test buyData
POST /buyData
{
  "network": 1,
  "mobile_number": "08012345678",
  "plan": "PSPLAN_531",
  "user_id": "test-user-id"
}

# Test payBill
POST /payBill
{
  "bill_type": "electricity",
  "provider": "ikedc",
  "account_number": "1234567890",
  "amount": 5000,
  "user_id": "test-user-id"
}
```

- [ ] buyData responds successfully
- [ ] payBill responds successfully
- [ ] No error messages
- [ ] Response contains expected fields

---

## Phase 4: Dart/Flutter App Update

### Update Service File
- [ ] Locate `lib/services/hazpay_service.dart`
- [ ] Check it contains Payscribe code (not Amigo)
- [ ] Verify DataNetwork enum has 5 entries
- [ ] Verify new methods exist:
  - [ ] payElectricityBill()
  - [ ] payCableBill()
  - [ ] getBillPaymentHistory()

### Add New Screen Files
- [ ] Copy `pay_bills_screen.dart` to `lib/screens/fintech/`
- [ ] Copy `pay_electricity_bill_screen.dart` to `lib/screens/fintech/`
- [ ] Copy `pay_cable_bill_screen.dart` to `lib/screens/fintech/`
- [ ] Verify all imports are correct
- [ ] Run `flutter pub get`

### Integration
- [ ] Add import in your dashboard:
  ```dart
  import 'pay_bills_screen.dart';
  ```
- [ ] Add navigation item to menu
- [ ] Test navigation works

### Cleanup
- [ ] Delete old Amigo service file (if backup exists)
- [ ] Remove Amigo imports from other files
- [ ] Search for "amigo" in codebase (should find none)
- [ ] Search for "AMIGO" in codebase (should find none)

---

## Phase 5: Testing

### Unit Tests (If You Have Them)
- [ ] Update existing service tests
- [ ] Add tests for new methods:
  - [ ] payElectricityBill()
  - [ ] payCableBill()
- [ ] Run all tests
- [ ] Verify 100% pass

### Manual Testing

#### 1. Data Purchase
```
1. Open Buy Data screen
2. Select MTN network
3. Pick a plan (e.g., 1GB for ₦280)
4. Enter phone number
5. Click "Buy Data"
```
Expected:
- [ ] Transaction pending
- [ ] Check completes or fails gracefully
- [ ] Wallet balance updates
- [ ] Transaction appears in history

#### 2. Electricity Bill Payment
```
1. Open Pay Bills screen
2. Click Electricity
3. Select IKEDC disco
4. Enter meter number
5. Select prepaid
6. Enter amount (₦5,000)
7. Click "Pay Now"
```
Expected:
- [ ] Payment processes
- [ ] Success or error shown
- [ ] Wallet updates (if successful)
- [ ] Payment logged in history

#### 3. Cable Bill Payment
```
1. Open Pay Bills screen
2. Click Cable TV
3. Select DSTV
4. Pick a plan
5. Enter smartcard number
6. Click "Pay Now"
```
Expected:
- [ ] Payment processes
- [ ] Success or error shown
- [ ] Wallet updates (if successful)
- [ ] Payment logged in history

#### 4. Wallet & Balance
```
1. Check wallet balance displays
2. Verify balance updates after transactions
3. Test insufficient balance handling
```
Expected:
- [ ] Balance always shows correctly
- [ ] Updates reflect transactions
- [ ] Cannot spend more than balance

### Integration Testing
- [ ] Data purchase → Wallet deduction → History update
- [ ] Bill payment → Wallet deduction → History update
- [ ] Multiple transactions in sequence
- [ ] App restart maintains state
- [ ] Error recovery works

---

## Phase 6: Production Readiness

### Code Quality
- [ ] No console errors
- [ ] No console warnings
- [ ] All imports resolved
- [ ] No unused imports
- [ ] Code formatting consistent
- [ ] Comments clear and helpful

### Performance
- [ ] Screens load within 2 seconds
- [ ] Transactions complete in <5 seconds
- [ ] No memory leaks
- [ ] List scrolling smooth
- [ ] No excessive API calls

### Security
- [ ] No API keys in code
- [ ] PAYSCRIBE_API_KEY in Supabase secrets (not code)
- [ ] User authentication required
- [ ] RLS policies active
- [ ] Transactions logged

### User Experience
- [ ] Loading states clear
- [ ] Error messages helpful
- [ ] Success confirmations shown
- [ ] Navigation smooth
- [ ] Input validation works
- [ ] Responsive design (mobile)

---

## Phase 7: Sandbox to Production (If Ready)

### Optional: Switch to Production Payscribe

**Only do this after thorough testing!**

1. **Update Edge Functions**
   - [ ] In buyData function, change:
     ```
     https://sandbox.payscribe.ng/api/v1  
     →  
     https://api.payscribe.ng/api/v1
     ```
   - [ ] In payBill function, change same URL
   - [ ] In requestLoan function, change same URL
   - [ ] Save/redeploy all functions

2. **Update API Key**
   - [ ] Get production PAYSCRIBE_API_KEY
   - [ ] Update in Supabase Secrets
   - [ ] Verify in Edge Function logs

3. **Final Testing**
   - [ ] Test with production networks
   - [ ] Monitor transaction logs
   - [ ] Test error scenarios
   - [ ] Verify customer support ready

---

## Post-Deployment

### Documentation
- [ ] Share DEPLOYMENT_STEPS.md with team
- [ ] Share QUICK_INTEGRATION_GUIDE.md with team
- [ ] Bookmark PAYSCRIBE docs link
- [ ] Save API credentials securely

### Monitoring
- [ ] Set up error logging/alerts
- [ ] Monitor Edge Function logs
- [ ] Track transaction success rate
- [ ] Review user feedback

### Maintenance
- [ ] Schedule plan price updates
- [ ] Monitor Payscribe status page
- [ ] Keep backup of database
- [ ] Review security regularly

---

## Troubleshooting During Deployment

### SQL Migration Fails
- [ ] Check table already exists (will add COLUMN IF NOT EXISTS)
- [ ] Verify syntax (copy exact file)
- [ ] Check table/column permissions
- [ ] Review error message carefully

### Edge Function Deploy Fails
- [ ] Check TypeScript syntax
- [ ] Verify imports are available
- [ ] Check function name matches
- [ ] Review Supabase logs

### App Won't Connect
- [ ] Check PAYSCRIBE_API_KEY is set
- [ ] Verify network connectivity
- [ ] Check Supabase URL/key in app
- [ ] Review browser console errors

### Transactions Fail
- [ ] Check wallet balance
- [ ] Verify phone number format
- [ ] Check Payscribe status
- [ ] Review Edge Function logs

---

## Success Indicators

✅ **You'll know it's working when:**

1. **Database**
   - SQL queries return expected results
   - 180+ plans in pricing table
   - New tables exist with data

2. **Edge Functions**
   - All 3 functions deployed
   - No errors in logs
   - Test requests return responses

3. **Dart App**
   - No compilation errors
   - Screens load without crashes
   - Service methods callable

4. **End-to-End**
   - Can purchase data and see wallet update
   - Can pay electricity bill successfully
   - Can pay cable bill successfully
   - Transaction history populated
   - All screens responsive and fast

---

## Emergency Rollback

If something goes wrong:

1. **Database**
   - Keep old amigo_plan_id column intact (don't delete)
   - Can add Amigo plans back if needed

2. **Edge Functions**
   - Old buyData/index.ts backed up
   - Can redeploy old version if needed

3. **Dart Service**
   - Old service backed up as `hazpay_service_old_amigo_backup.dart`
   - Can switch imports if needed

4. **Full Rollback**
   - Restore from database backup
   - Redeploy old Edge Functions
   - Revert app to previous version

---

## Sign-Off

**Deployment Complete When:**

- [ ] All SQL verified
- [ ] All Edge Functions deployed
- [ ] All Dart files updated
- [ ] Manual testing passed
- [ ] No errors in logs
- [ ] Team notified
- [ ] Documentation shared

---

## Contact & Support

- **Payscribe Support:** support@payscribe.ng
- **Supabase Status:** status.supabase.com
- **This Documentation:** See QUICK_INTEGRATION_GUIDE.md

---

**Status:** Ready for deployment  
**Last Updated:** December 12, 2025  
**Version:** 1.0

**BEGIN DEPLOYMENT WHEN READY** ✅
