# Switch to PayScribe Production (Live) Testing

## ✅ What Changed in the Edge Function

The edge function now supports both **sandbox** and **production** environments:

```
PAYSCRIBE_ENV = "sandbox" (default)  → Uses sandbox API key at https://sandbox.payscribe.ng/api/v1
PAYSCRIBE_ENV = "production"         → Uses production API key at https://api.payscribe.ng/api/v1
```

---

## 🚀 Steps to Test with Live/Production

### Step 1: Get Your Production API Key from PayScribe

1. Go to https://dashboard.payscribe.ng
2. Log in
3. Navigate to **Settings → API Keys**
4. Find or generate your **production API key** (starts with `ps_pk_live_` NOT `ps_pk_test_`)
5. Copy it

### Step 2: Add Production API Key to Supabase

1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **Settings → Secrets/Environment Variables**
3. Click **Add secret** and create:
   - **Name:** `PAYSCRIBE_API_KEY_PROD`
   - **Value:** Paste your live API key from step 1
   - Click **Save**

### Step 3: Enable Production Mode

Add the environment variable to switch to production:

1. In **Secrets**, add another secret:
   - **Name:** `PAYSCRIBE_ENV`
   - **Value:** `production`
   - Click **Save**

### Step 4: Deploy/Update the Edge Function

1. The edge function code is already updated
2. Supabase will auto-deploy once you save the secrets
3. Wait 1-2 minutes for deployment

### Step 5: Test in Supabase Test Lab

1. Go to **Edge Functions** → **buyData** → **Test**
2. Use the same test request:

```json
{
  "network": 1,
  "mobile_number": "08132931751",
  "plan": "PSPLAN_177",
  "idempotency_key": "test-production-001"
}
```

3. Click **Send** and check the logs for:

```
🔐 Using PRODUCTION environment
🔐 API Key loaded from secrets: ps_pk_live_***XXXXX (length: 45)
🔐 Base URL: https://api.payscribe.ng/api/v1
🌐 Calling: https://api.payscribe.ng/api/v1/data/vend
```

---

## 📊 Expected Behavior

### If it works:
```json
{
  "success": true,
  "data": {
    "reference": "transaction-id",
    "message": "Data purchase successful",
    "amount_charged": 550,
    "status": "success"
  }
}
```

### If API key is wrong:
```
❌ Payscribe error: unknown_error - User not authenticated
```

---

## ⚠️ Important Notes

1. **Real Money:** You'll be using your LIVE account, so actual credit will be deducted
2. **Small Amounts:** Test with small amounts as PayScribe support suggested
3. **Real Phone:** Use a real phone number (the test number may not work in production)
4. **Keep Logs:** The edge function will log:
   - Which environment you're using (sandbox vs production)
   - The masked API key for verification
   - The exact API endpoint being called

---

## 🔄 Switching Back to Sandbox

If you want to go back to sandbox testing:

1. In Supabase Secrets, change `PAYSCRIBE_ENV` to `sandbox`
2. Or delete `PAYSCRIBE_ENV` (defaults to sandbox)
3. Make sure `PAYSCRIBE_API_KEY` (sandbox key) is still there

---

## 📞 Next Steps

1. **Copy your live API key** from PayScribe dashboard
2. **Add both secrets** to Supabase (`PAYSCRIBE_API_KEY_PROD` and `PAYSCRIBE_ENV`)
3. **Test in Supabase Test Lab**
4. **Share the logs** if anything fails

Let me know once you've added the secrets and I'll help troubleshoot if needed!
