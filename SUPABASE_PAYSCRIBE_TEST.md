# Supabase Edge Function Test - PayScribe Data Vending

## 🎯 Quick Test in Supabase Test Lab

### Step 1: Open Supabase Console
1. Go to your Supabase project
2. Navigate to **Edge Functions** → **buyData** (or your function name)
3. Click the **Test** tab

### Step 2: Send Test Request

**Use this exact JSON body:**

```json
{
  "network": 1,
  "mobile_number": "08132931751",
  "plan": "PSPLAN_177",
  "idempotency_key": "test-payscribe-001"
}
```

**Expected Response (Success):**
```json
{
  "success": true,
  "data": {
    "reference": "f5c3e455-e284-454b-9763-99c95b1b75a7",
    "message": "Order received. Transaction in progress.",
    "network": 1,
    "amount_charged": 270,
    "status": "processing"
  }
}
```

---

## 🔍 What to Check

### If you get 400 Bad Request:
1. **Check the console logs** - Look for error messages about:
   - Pricing not found
   - Missing API key
   - Network conversion error
   
2. **Verify PAYSCRIBE_API_KEY is set:**
   - Supabase Dashboard → Settings → Secrets/Environment
   - Make sure `PAYSCRIBE_API_KEY` with value `ps_pk_test_...` is there

### If you get authentication error:
- Token might be wrong
- Check it starts with `ps_pk_test_`

### If request seems to work but Payscribe API fails:
- Watch the console logs for: `📡 Raw Payscribe API response`
- Copy that response and share it

---

## 📝 Testing Steps

1. **Copy the JSON body** from above
2. **Paste into Supabase Test Lab request body**
3. **Click Send** (or Test Request button)
4. **Check the response** - does it say success: true?
5. **Check Console logs** - look for error messages

If it works → Your code is correct, Postman had a config issue
If it fails → Check the exact error message in console logs

---

## 💡 Alternative: Trigger from Flutter

You can also test by calling your edge function from Flutter:

```dart
// In your HazPayService or similar
final response = await Supabase.instance.client.functions.invoke(
  'buyData',
  body: {
    'network': 1, // MTN
    'mobile_number': '08132931751',
    'plan': 'PSPLAN_177',
    'idempotency_key': 'test-flutter-001',
  },
);

print('Response: ${response.data}');
```

Check the Flutter console for the response.

---

## 🚀 Next Steps

1. Run the Supabase test
2. Report the **exact response** and **console logs**
3. If success → Move to production testing
4. If failure → Share the error message from console logs
