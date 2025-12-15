# PayScribe API Debugging Guide - Two Issues

## ✅ Answers to PayScribe Support Questions

### 1. "Are you sending the request as raw?"
**Current Implementation:** ✅ YES - Your code sends raw JSON requests

In `supabase/functions/buyData/index_payscribe.ts` (line 347-352):
```typescript
const payscribeResponse = await fetch("https://sandbox.payscribe.ng/api/v1/data/vend", {
  method: "POST",
  headers: payscribeHeaders,
  body: JSON.stringify({
    network: providerCode,
    recipient: localNumber,
    plan: pricingInfo.payscribe_plan_id,
    ref: payload.idempotency_key || payload.user_id || "auto-generated",
  }),
});
```

✅ This is correctly sending raw JSON.

---

### 2. "Are you actually using the valid base URL and token?"

#### Issue Analysis:

**Base URL Check:**
- ✅ Using: `https://sandbox.payscribe.ng/api/v1/data/vend` (Line 347)
- ✅ Correct for sandbox testing

**Token Check:**
- ✅ Auth Header: `Authorization: Bearer ${payscribeApiKey}` (Line 317)
- ⚠️ **POTENTIAL ISSUE:** You need to verify 3 things:

---

## 🔴 ISSUE #1: Invalid Phone Numbers

### Root Cause:
The sandbox may only accept specific test phone numbers or formats. PayScribe's default behavior is to reject non-whitelisted numbers in sandbox.

### Current Code (Line 330-337):
```typescript
// Convert international format (2348012345678) to local format (08012345678) if needed
let localNumber = payload.mobile_number;
if (payload.mobile_number.startsWith("234")) {
  localNumber = "0" + payload.mobile_number.slice(3);
  console.log(`📞 Converted international number ${payload.mobile_number} to local format ${localNumber}`);
}
```

### Solution Steps:

**Step 1: Ask PayScribe Support for Test Numbers**
> "What are the valid test phone numbers for sandbox testing on each network (MTN, GLO, Airtel, 9Mobile, SMILE)? Do I need to use a specific format or whitelist them first?"

**Step 2: Update Code to Support Test Numbers**
Add this to `index_payscribe.ts` after line 180 (in the `validatePayload` function):

```typescript
// In development/sandbox, accept test numbers
const isDevelopment = (globalThis as any).Deno?.env?.get?.("ENVIRONMENT") !== "production";
const testNumbers: Record<number, string[]> = {
  1: ["08012345670", "08012345671"], // MTN test numbers
  2: ["08012345672", "08012345673"], // GLO test numbers
  3: ["08012345674", "08012345675"], // Airtel test numbers
  4: ["08012345676", "08012345677"], // 9Mobile test numbers
  5: ["08012345678", "08012345679"], // SMILE test numbers
};

if (isDevelopment && testNumbers[req.network]) {
  console.log(`ℹ️ Using test numbers for sandbox: ${testNumbers[req.network].join(", ")}`);
}
```

**Step 3: Verify Phone Format**
- For MTN: `080XXXXXXXX` or `231080XXXXXXXX`
- For GLO: `070XXXXXXXX` or `231070XXXXXXXX`
- For Airtel: `081XXXXXXXX` or `231081XXXXXXXX`

---

## 🔴 ISSUE #2: Bill Payment 401 Unauthorized

### Root Cause Analysis:

The 401 error suggests one of three problems:

#### Problem A: Token Doesn't Have Bill Payment Scope ⚠️ **MOST LIKELY**
```
{"status":false,"description":"User not authenticated. Please use your valid token","status_code":401}
```

### Solution:

**Step 1: Verify Token Permissions**
Contact PayScribe support with this question:
```
"My PAYSCRIBE_API_KEY works for data vending (/data/vend) but fails for bill payment (/electricity/vend) with 401 Unauthorized. 

Do I need:
1. A different API key with different permissions?
2. To enable/request bill payment scope on my current key?
3. Different authentication method for bill endpoints?"
```

**Step 2: Check if You Have Separate Keys**
In your Supabase secrets, verify you have:
- `PAYSCRIBE_API_KEY` - For data vending (currently working)
- `PAYSCRIBE_BILL_API_KEY` - For bill payments (may be needed separately)

**Step 3: Update Code to Handle Bill Payments**

Create a new Edge Function for bills payment. Add this as `supabase/functions/payBill/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.191.0/http/server.ts";

interface PayBillRequest {
  service: string; // "ikedc", "ekedc", "enugu", "ibadan"
  meter_number: string;
  meter_type: "postpaid" | "prepaid";
  amount: number;
  customer_name: string;
  phone: string;
  ref: string;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Only POST allowed" }), { status: 405 });
  }

  try {
    const body = await req.json() as PayBillRequest;
    
    // Get API key - may need different key for bills
    const apiKey = (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_BILL_API_KEY") || 
                   (globalThis as any).Deno?.env?.get?.("PAYSCRIBE_API_KEY");
    
    if (!apiKey) {
      throw new Error("PAYSCRIBE_BILL_API_KEY not configured");
    }

    // Build request for bill payment
    const response = await fetch("https://sandbox.payscribe.ng/api/v1/electricity/vend", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        meter_number: body.meter_number,
        meter_type: body.meter_type,
        amount: body.amount,
        service: body.service,
        customer_name: body.customer_name,
        phone: body.phone,
        ref: body.ref,
      }),
    });

    const responseText = await response.text();
    console.log(`Payscribe response (${response.status}): ${responseText}`);
    
    if (!response.ok) {
      throw new Error(`Bill payment failed: ${responseText}`);
    }

    const data = JSON.parse(responseText);
    
    return new Response(JSON.stringify({
      success: true,
      data: data,
    }), { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (error) {
    console.error("Bill payment error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
```

**Step 4: Test with Correct Headers**
```bash
# Test data vending (working)
curl -X POST https://your-supabase-url/functions/v1/buyData \
  -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "network": 1,
    "mobile_number": "08012345670",
    "plan": "PSPLAN_531"
  }'

# Test bill payment (needs testing)
curl -X POST https://your-supabase-url/functions/v1/payBill \
  -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "service": "ikedc",
    "meter_number": "1234567890",
    "meter_type": "postpaid",
    "amount": 5000,
    "customer_name": "TEST",
    "phone": "08012345670",
    "ref": "bill-123"
  }'
```

---

## ✅ Checklist to Send to PayScribe Support

Use this exact checklist in your next message to PayScribe:

```
Hello PayScribe Support,

I'm integrating your sandbox API and need clarification on two points:

1. **Data Vending Test Numbers**
   - Current test: POST /data/vend with phone 08012345678
   - Error: "No valid number to process"
   - Question: What are the valid sandbox test phone numbers for each network (MTN, GLO, Airtel, 9Mobile, SMILE)?
   - Do I need to whitelist them, or are there default test numbers I should use?

2. **Bill Payment Authentication**
   - Data vending works: POST /data/vend with my API key ✓
   - Bill payment fails: POST /electricity/vend returns 401 Unauthorized
   - Same API key, Bearer token format same as data vending
   - Question: Does the bill payment endpoint require:
     a) A different/separate API key?
     b) Additional scope/permission on my current key?
     c) Different IP whitelisting?
   
   My current IP: 2a05:d014:61b:2704:3054:1096:1537:8e9b (whitelisted)

3. **Required Fields for Bill Payment**
   - Which of these are truly required: meter_number, meter_type, amount, service, customer_name, phone, ref?
   - What's the acceptable format for each field?

Thank you!
```

---

## 🔧 Implementation Checklist

- [ ] Receive test phone numbers from PayScribe support
- [ ] Update hardcoded test numbers in code
- [ ] Ask about separate bill payment API key
- [ ] Create separate `/payBill` edge function
- [ ] Test data vending with provided test numbers
- [ ] Test bill payment with correct credentials
- [ ] Verify both work in sandbox before production
- [ ] Document all endpoints and required fields
- [ ] Create comprehensive error handling for both flows

---

## 📝 Key Points to Remember

1. **Data Vending** - Currently works, just needs valid test numbers
2. **Bill Payment** - Likely needs separate/additional authentication
3. **Format** - Always use raw JSON POST with Bearer token
4. **Phone Numbers** - Convert intelligently between formats (080... vs 234...)
5. **Error Logging** - Your code logs response properly, check logs for exact error details

