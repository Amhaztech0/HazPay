# Payscribe Migration - Deployment Steps

Complete migration from Amigo API to Payscribe with multi-network support (5 networks) and bills payment features.

## 🚀 Deployment Checklist

### 1. Deploy SQL Migration ✅
**File:** `PAYSCRIBE_MIGRATION.sql`

Steps:
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Navigate to your project
3. Click "SQL Editor" in the left sidebar
4. Click "+ New Query"
5. Copy entire contents of `PAYSCRIBE_MIGRATION.sql`
6. Paste into SQL Editor
7. Click "Run"
8. Wait for completion

**What it does:**
- Adds `payscribe_plan_id` column to pricing table
- Inserts 180+ plans for 5 networks:
  - MTN (network_id=1): 50+ plans
  - GLO (network_id=2): 37+ plans
  - Airtel (network_id=3): 50+ plans
  - 9Mobile (network_id=4): 17 plans
  - SMILE (network_id=5): 26+ plans
- Creates `bills_payments` table for electricity/cable payments
- Creates `electricity_discos` lookup table
- Sets up RLS policies

---

### 2. Deploy Edge Functions ✅

#### 2a. Deploy buyData Function

**Files:** 
- `supabase/functions/buyData/index_payscribe.ts`
- `supabase/functions/buyData/deno.json` (if needed)

**Steps:**
1. In Supabase Dashboard, go to "Edge Functions"
2. Click "Deploy a new function"
3. Name: `buyData`
4. Copy `supabase/functions/buyData/index_payscribe.ts` contents
5. Replace existing `supabase/functions/buyData/index.ts`
6. Set environment variables:
   - `PAYSCRIBE_API_KEY`: Your Payscribe Bearer token
7. Deploy

**What it does:**
- Handles data purchases via Payscribe
- Supports all 5 networks (MTN, GLO, Airtel, 9Mobile, SMILE)
- Maps network IDs to provider codes
- Fetches pricing from database
- Returns reference, status, profit calculations

---

#### 2b. Deploy payBill Function

**Files:**
- `supabase/functions/payBill/index.ts`

**Steps:**
1. In Supabase Dashboard, go to "Edge Functions"
2. Click "Deploy a new function"
3. Name: `payBill`
4. Copy `supabase/functions/payBill/index.ts` contents
5. Set environment variables:
   - `PAYSCRIBE_API_KEY`: Your Payscribe Bearer token
6. Deploy

**What it does:**
- Handles electricity bill payments (9 discos)
- Handles cable subscription payments (DSTV, GOTV, Startimes, DSTVShowMax)
- Validates bill type, provider, account number
- Calls Payscribe API endpoints
- Records payments in `bills_payments` table

---

#### 2c. Update requestLoan Function

**File:** `supabase/functions/requestLoan/index.ts` (already updated)

**Steps:**
1. In Supabase Dashboard, go to "Edge Functions"
2. Find existing `requestLoan` function
3. Replace content with updated `supabase/functions/requestLoan/index.ts`
4. Ensure `PAYSCRIBE_API_KEY` is set in environment
5. Redeploy

**What it does:**
- Issues 1GB data loans via Payscribe
- Calculates loan fee (20% of plan cost)
- Creates loan record in database
- Auto-repayment when user deposits funds

---

### 3. Configure Environment Variables ⚙️

In Supabase Dashboard:
1. Go to "Settings" → "API"
2. Under "Service role key" section, also check "Secrets"
3. Add the following secrets:

```
PAYSCRIBE_API_KEY = "your_payscribe_bearer_token_here"
```

**Sandbox vs Production:**
- **Development:** Use `https://sandbox.payscribe.ng/api/v1`
- **Production:** Change to `https://api.payscribe.ng/api/v1`

---

### 4. Update Dart Service Code 📱

Replace or update `lib/services/hazpay_service.dart` with `lib/services/hazpay_service_payscribe.dart`

**New features:**
- `getDataPlans()` - Fetch all 5 networks
- `purchaseData()` - Buy airtime/data via Payscribe
- `payElectricityBill()` - Pay electricity bills (all 9 discos)
- `payCableBill()` - Pay cable subscriptions
- `getBillPaymentHistory()` - Track bill payments
- `requestLoan()` - Get 1GB loan
- Wallet management with Paystack integration

---

### 5. Update Models and UI 🎨

#### Models to Update:
- [ ] Update `DataNetwork` enum to include Airtel, 9Mobile, SMILE
- [ ] Add `BillPayment` model
- [ ] Update imports in services

#### UI Screens to Create:
- [ ] Bills payment screen (electricity/cable selection)
- [ ] Electricity disco selector
- [ ] Cable provider/plan selector
- [ ] Meter number/Smartcard input
- [ ] Bill payment confirmation
- [ ] Payment history view

---

### 6. Remove Amigo References 🗑️

Files to update:
- `supabase/functions/buyData/index.ts` (old version - can be deleted)
- `lib/services/hazpay_service.dart` (old version - backup and replace)

Search and remove:
- All `amigo_plan_id` references (use `payscribe_plan_id` instead)
- All Amigo API URLs
- All `AMIGO_API_KEY` environment variable references

---

## 🔄 Migration Timeline

1. **Phase 1 (Today):** Deploy SQL + Edge Functions
2. **Phase 2 (Tomorrow):** Update Dart service + models
3. **Phase 3 (Optional):** Create UI for bills payment
4. **Phase 4:** Testing in sandbox
5. **Phase 5:** Switch to production endpoint

---

## ✅ Verification Steps

After deployment, verify each component:

### SQL Migration
```sql
SELECT COUNT(*) FROM pricing WHERE network_id = 1; -- Should return 50+
SELECT COUNT(*) FROM pricing WHERE network_id = 3; -- Airtel - should return 50+
SELECT * FROM bills_payments LIMIT 1; -- Check table exists
```

### Edge Functions
1. Test `buyData`:
```bash
curl -X POST https://your-project.supabase.co/functions/v1/buyData \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "network": 1,
    "mobile_number": "08012345678",
    "plan": 3,
    "user_id": "test-user"
  }'
```

2. Test `payBill`:
```bash
curl -X POST https://your-project.supabase.co/functions/v1/payBill \
  -H "Authorization: Bearer your-token" \
  -H "Content-Type: application/json" \
  -d '{
    "bill_type": "electricity",
    "provider": "ikedc",
    "account_number": "1234567890",
    "amount": 5000,
    "user_id": "test-user"
  }'
```

---

## 📋 Rollback Plan

If something goes wrong:

1. **Database:** 
   - Don't delete old `amigo_plan_id` column until confirmed working
   - Keep backup of old pricing data

2. **Edge Functions:**
   - Keep old `buyData/index.ts` as backup
   - Can switch back by redeploying old version

3. **Dart Service:**
   - Keep old `hazpay_service.dart`
   - New version is in `hazpay_service_payscribe.dart`

---

## 🆘 Troubleshooting

### "PAYSCRIBE_API_KEY not found"
- Check Supabase Secrets are configured
- Verify key is set in project settings
- Restart Edge Functions

### "payscribe_plan_id not found in pricing"
- Run SQL migration again
- Verify data inserted correctly: `SELECT * FROM pricing LIMIT 5;`

### Bill payment failing
- Verify Payscribe sandbox credentials
- Check internet connectivity
- Review Payscribe API response logs

### Loan issuance failing
- Ensure 1GB plan exists in pricing table
- Check mobile number format (must be 10-11 digits)
- Verify user doesn't have active loan

---

## 📞 Support

- **Payscribe Docs:** https://docs.payscribe.ng
- **Supabase Docs:** https://supabase.com/docs
- **Issue Tracking:** Check logs in Supabase → Edge Functions → Logs

---

**Status:** ✅ Ready for deployment
**Created:** 2025-12-12
**Updated:** 2025-12-12
