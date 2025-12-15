# PayScribe Support Response Template

## Copy This Exact Message to PayScribe Support

---

**Subject:** Sandbox API Issues - Data Vending Phone Numbers & Bill Payment Authentication

Hello PayScribe Support,

Thank you for the clarification questions. I've verified both points in my implementation:

### ✅ 1. Request Format (RAW JSON)
**Confirmed:** I'm sending POST requests as raw JSON with proper headers:
```
POST https://sandbox.payscribe.ng/api/v1/data/vend
Authorization: Bearer [PAYSCRIBE_API_KEY]
Content-Type: application/json

{
  "network": "mtn",
  "recipient": "08012345678",
  "plan": "PSPLAN_531",
  "ref": "test-123"
}
```

**Framework:** Deno/TypeScript using `fetch()` API
**Validation:** Phone numbers converted from international (2348012345678) to local format (08012345678)

---

### ✅ 2. Base URL & Token Confirmation
**Base URL:** `https://sandbox.payscribe.ng/api/v1` ✓ CORRECT
**Token:** Using Bearer token from Supabase secrets ✓ CORRECT

**However, I have two specific issues:**

---

## **ISSUE #1: Data Vending - Invalid Phone Number**

**API Response:**
```json
{
  "status": false,
  "description": "No valid number to process. See errors",
  "errors": "08012345678"
}
```

**My Questions:**
1. Does sandbox only accept specific test phone numbers?
2. What are the valid test numbers for sandbox for each network?
   - MTN: ?
   - GLO: ?
   - Airtel: ?
   - 9Mobile: ?
   - SMILE: ?
3. Do I need to request/whitelist test numbers first?
4. Or are there default test numbers provided?

---

## **ISSUE #2: Bill Payment - 401 Unauthorized**

**Endpoint Tested:** POST `https://sandbox.payscribe.ng/api/v1/electricity/vend`

**My Request:**
```json
{
  "meter_number": "1234567890",
  "meter_type": "postpaid",
  "amount": 5000,
  "service": "ikedc",
  "customer_name": "TEST",
  "phone": "08012345678",
  "ref": "bill-123"
}
```

**Headers:**
```
Authorization: Bearer [SAME_PAYSCRIBE_API_KEY]
Content-Type: application/json
```

**API Response:**
```json
{
  "status": false,
  "description": "User not authenticated. Please use your valid token",
  "status_code": 401
}
```

**My Questions:**
1. Does the bill payment endpoint require a **different API key** than data vending?
2. If using the same key, do I need to:
   - Enable additional scopes/permissions?
   - Request specific bill payment access?
   - Use different IP whitelisting?
3. What are the **required vs optional fields** for bill payment?
4. Any specific formatting for meter_number, service, or other fields?

**Additional Info:**
- IP Whitelisted: `2a05:d014:61b:2704:3054:1096:1537:8e9b`
- Same API key works perfectly for data vending
- Using Bearer token format for both endpoints

---

## **Testing Environment Details**
- **Sandbox Base URL:** https://sandbox.payscribe.ng/api/v1
- **Framework:** Supabase Edge Functions (Deno)
- **Request Method:** POST with raw JSON body
- **Content-Type:** application/json
- **Auth Type:** Bearer token in Authorization header

---

Please advise on both issues so I can proceed with testing.

Thank you!

---

## Quick Reference: Test Before Responding

If PayScribe asks you for more info, have ready:

1. **Your PAYSCRIBE_API_KEY (first 10 chars):** [ASK THEM TO VERIFY THEY CAN SEE IT IN SANDBOX DASHBOARD]
2. **Supabase Outbound IP:** 2a05:d014:61b:2704:3054:1096:1537:8e9b
3. **Account Status:** Active in sandbox
4. **Date Created:** [CHECK YOUR PAYSCRIBE ACCOUNT]
5. **Recent API Calls:** Check logs for timestamps

