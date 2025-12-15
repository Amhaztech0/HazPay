# HazPay Supabase Edge Function Setup Guide

This guide explains how to deploy the secure `buyData` Edge Function and configure the Flutter app to use it.

## 📋 Overview

The architecture has been updated for **maximum security**:

```
Flutter App (HazPay)
    ↓
Supabase Edge Function (buyData)
    ↓
Amigo API (https://amigo.ng/api/data/)
```

**Why this is secure:**
- ✅ API key **never** exposed in Flutter or client-side code
- ✅ API key stored only in Supabase Secrets (server-side)
- ✅ Edge Function validates input before calling Amigo
- ✅ Idempotency support prevents duplicate charges
- ✅ Error handling is clean and user-friendly

---

## 🚀 Step 1: Set Up Supabase Secrets

### Option A: Using Supabase Dashboard (Easiest)

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **Secrets**
3. Click **Add a secret**
4. Fill in:
   - **Name**: `AMIGO_API_KEY`
   - **Value**: Your Amigo API key (e.g., `82ce1d0b91d0228e92e538b742382f73d0e025f7ea1a2928b203d14797e38428`)
5. Click **Save**

### Option B: Using Supabase CLI

```powershell
# From your project root directory
supabase secrets set AMIGO_API_KEY="82ce1d0b91d0228e92e538b742382f73d0e025f7ea1a2928b203d14797e38428"
```

**Verify the secret was set:**
```powershell
supabase secrets list
```

---

## 📦 Step 2: Deploy the Edge Function

### Via Supabase Dashboard

1. Go to **Edge Functions** section
2. Click **Create a new function**
3. Name it: `buyData`
4. Copy the entire content from `supabase/functions/buyData/index.ts` into the editor
5. Click **Deploy**

### Via Supabase CLI

```powershell
# Navigate to your project directory
cd c:\Users\Amhaz\Desktop\zinchat

# Deploy the function
supabase functions deploy buyData --import-map supabase/functions/import_map.json
```

**Verify deployment:**
```powershell
supabase functions list
```

You should see `buyData` in the list.

---

## ✅ Step 3: Test the Edge Function

### Using cURL (PowerShell)

```powershell
$url = "https://YOUR_PROJECT_ID.supabase.co/functions/v1/buyData"
$headers = @{
    "Authorization" = "Bearer YOUR_ANON_KEY"
    "Content-Type" = "application/json"
}
$body = @{
    "network" = 1
    "mobile_number" = "09000012345"
    "plan" = 5000
    "Ported_number" = $false
    "idempotency_key" = "test-123"
} | ConvertTo-Json

Invoke-WebRequest -Uri $url -Method POST -Headers $headers -Body $body | Select-Object -ExpandProperty Content
```

Replace:
- `YOUR_PROJECT_ID` - Your Supabase project ID (from Settings)
- `YOUR_ANON_KEY` - Your Supabase anon key (from Settings → API)

### Expected Success Response

```json
{
  "success": true,
  "data": {
    "reference": "AMG-20250920203716-c40306",
    "message": "Dear Customer, You have successfully gifted 1GB data to 09012345678.",
    "network": 1,
    "plan": 5000,
    "amount_charged": 299,
    "status": "delivered"
  }
}
```

### Expected Error Response

```json
{
  "success": false,
  "error": {
    "code": "INVALID_NUMBER",
    "message": "The mobile number provided is invalid.",
    "details": "Original Amigo error: invalid_number"
  }
}
```

---

## 🔧 Step 4: Verify Flutter Code is Updated

Check that your `lib/services/hazpay_service.dart` has:

1. ✅ **No hardcoded API key** (removed from class)
2. ✅ **`purchaseData()` calls `supabase.functions.invoke('buyData', ...)`**
3. ✅ **Passes `idempotency_key` to prevent duplicate charges**

If you need to re-check, search for these patterns:

```dart
// ✅ CORRECT - Calling Edge Function
final response = await supabase.functions.invoke(
  'buyData',
  body: {
    'network': networkId,
    'mobile_number': mobileNumber,
    'plan': int.parse(planId),
    'Ported_number': isPortedNumber,
    'idempotency_key': transactionId,
  },
);

// ❌ WRONG - Calling Amigo directly (should not exist)
final response = await http.post(
  Uri.parse('https://amigo.ng/api/data/'),
  ...
);
```

---

## 📱 Step 5: Test in Flutter App

1. **Rebuild the app:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Navigate to Buy Data screen**

3. **Try a test transaction:**
   - Select MTN or Glo
   - Use sandbox number: `09000012345` (starts with 090000 for testing)
   - Select a plan
   - Tap "Buy Data"
   - Should see success message with reference

4. **Check console logs:**
   ```
   I/flutter ( 7148): 🔐 Calling Supabase Edge Function for secure purchase...
   I/flutter ( 7148): 📡 Edge Function Response: {...}
   I/flutter ( 7148): ✅ Data purchase successful: AMG-20250920203716-c40306
   ```

---

## 🔐 Security Checklist

Before going live, verify:

- [ ] AMIGO_API_KEY is set in Supabase Secrets (NOT in code)
- [ ] Edge Function is deployed (`supabase functions list`)
- [ ] Flutter code calls `supabase.functions.invoke('buyData', ...)`
- [ ] No hardcoded API keys in Flutter code (search for `82ce1d0b...`)
- [ ] Transaction records are created in `hazpay_transactions` table
- [ ] Wallet is updated only after successful Edge Function response
- [ ] Error messages are user-friendly (no technical details leaked)

---

## 📊 Edge Function Features

### 1. Input Validation
- Validates network (1 = MTN, 2 = Glo)
- Validates mobile_number format (10-11 digits)
- Validates plan ID (positive number)
- Validates Ported_number (boolean)

### 2. Error Mapping
The function maps Amigo API errors to user-friendly messages:

| Amigo Error | User Message |
|---|---|
| `invalid_token` | "API authentication failed. Contact support." |
| `plan_not_found` | "Selected plan is not available for this network." |
| `coming_soon` | "This network is not yet supported." |
| `insufficient_balance` | "Insufficient balance to complete this purchase." |
| `invalid_number` | "The mobile number provided is invalid." |

### 3. Idempotency
- Accepts optional `idempotency_key` parameter
- Amigo uses this to prevent duplicate charges
- Flutter automatically passes transaction ID as key

### 4. Response Format
All responses follow a consistent format:

**Success:**
```json
{
  "success": true,
  "data": { reference, message, network, plan, amount_charged, status }
}
```

**Error:**
```json
{
  "success": false,
  "error": { code, message, details? }
}
```

---

## 🐛 Troubleshooting

### Issue: "AMIGO_API_KEY not configured in Supabase secrets"

**Solution:** Run step 1 again to set the secret.

```powershell
supabase secrets set AMIGO_API_KEY="your_key_here"
```

### Issue: "Cannot find function 'buyData'"

**Solution:** The function may not be deployed. Run:

```powershell
supabase functions deploy buyData
```

### Issue: "401 Unauthorized" when calling Edge Function

**Solution:** Make sure you're using your Supabase `anon_key` in the request headers. The function uses Supabase's built-in auth, so the client request must be authenticated.

### Issue: "Failed to fetch plans: HTTP 404" (For plan fetching)

**Solution:** This is a separate issue with the Amigo plans endpoint. The plan-fetching code (getDataPlans) still uses direct API calls. To secure this as well:

1. Create another Edge Function: `getDataPlans`
2. Move plan-fetching logic to that function
3. Update `lib/services/hazpay_service.dart` to call `supabase.functions.invoke('getDataPlans', ...)` 

For now, the plan endpoint can remain public since it's read-only.

---

## 📞 Support

If you encounter issues:

1. **Check Supabase logs:**
   - Dashboard → Edge Functions → buyData → Logs
   - Look for error details

2. **Check Flutter console:**
   ```
   flutter logs | grep flutter
   ```

3. **Test endpoint directly** (see Step 3)

4. **Verify Supabase project settings:**
   - Settings → API → Check anon key and project URL

---

## ✨ Next Steps (Optional Enhancements)

1. **Add email receipts** - Send confirmation email after successful purchase
2. **Add SMS notifications** - Notify user when data is delivered
3. **Create secure getDataPlans function** - Move plan-fetching to Edge Function
4. **Add transaction webhooks** - Listen for purchase status updates
5. **Implement referral system** - Track and reward referrals

---

**Last Updated:** November 21, 2025
**Version:** 1.0
