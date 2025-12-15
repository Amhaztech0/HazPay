# Bill Payment Testing Guide

## 🔌 Electricity Bill Payment

### Test Request (Electricity):

```json
{
  "bill_type": "electricity",
  "provider": "ekedc",
  "meter_number": "1234567890",
  "amount": 5000,
  "phone": "08012345678",
  "email": "user@example.com",
  "ref": "test-electricity-001"
}
```

**Parameters:**
- `bill_type`: "electricity" (fixed)
- `provider`: "ekedc" | "ikedc" | "ikeja-eko" | "prepaid"
- `meter_number`: Customer's meter number (required)
- `amount`: Amount to pay (in Naira) - can vary
- `phone`: Customer phone number (required)
- `email`: Customer email (optional)
- `ref`: Unique reference ID (required)

**Expected Success Response:**
```json
{
  "success": true,
  "data": {
    "reference": "trans_id_from_payscribe",
    "message": "Bill payment successful",
    "bill_type": "electricity",
    "provider": "ekedc",
    "amount_charged": 5000,
    "status": "success"
  }
}
```

---

## 📺 Cable Subscription Payment

### Step 1: Get Available Cable Plans

**First, you need to get the plan_id from PayScribe:**

Cable providers: `dstv` | `gotv` | `startimes`

You can check PayScribe dashboard under **Commissions** → **Cable Subscription** to see all available plans.

Example plans:
- GOTV Jolli: plan_id = `RDExckQyT1Zwc0hXMjI3UXhqMS9LZz09`
- DSTV Compact: plan_id = `TnpRK0N5Z2hwbElEa0srdjJXQnBUdz09`

### Step 2: Validate Smart Card (Optional but Recommended)

Before paying, validate the customer's smart card to get their name and details:

```
POST https://sandbox.payscribe.ng/api/v1/multichoice/validate

Body:
{
  "service": "gotv",
  "account": "2009594253",
  "plan_id": "RDExckQyT1Zwc0hXMjI3UXhqMS9LZz09"
}

Response:
{
  "status": true,
  "message": {
    "details": {
      "customer_name": "ADEBAYO MOSUNMOLA",
      "info": {
        "accountNumber": "2009594253",
        ...
      }
    }
  }
}
```

### Step 3: Send Cable Payment Request

```json
{
  "bill_type": "cable",
  "provider": "gotv",
  "smart_card_number": "2009594253",
  "plan_id": "RDExckQyT1Zwc0hXMjI3UXhqMS9LZz09",
  "customer_name": "ADEBAYO MOSUNMOLA",
  "phone": "08199228811",
  "email": "customer@example.com",
  "ref": "test-cable-001"
}
```

**Parameters:**
- `bill_type`: "cable" (fixed)
- `provider`: "dstv" | "gotv" | "startimes"
- `smart_card_number`: Customer's smart card number (required)
- `plan_id`: Plan ID from bouquets lookup (required)
- `customer_name`: Customer name from validation (required)
- `phone`: Customer phone number (required)
- `email`: Customer email (optional)
- `ref`: Unique reference ID (required)

**Expected Success Response:**
```json
{
  "success": true,
  "data": {
    "reference": "trans_id_from_payscribe",
    "message": "Bill payment successful",
    "bill_type": "cable",
    "provider": "gotv",
    "amount_charged": 12300,
    "status": "success"
  }
}
```

---

## 🧪 How to Test in Supabase

1. **Go to Supabase Dashboard** → Your Project
2. **Edge Functions** → **billPayment**
3. **Click Test tab**
4. **Paste your request body** (electricity or cable)
5. **Click Send**
6. **Check Response** and **Console Logs**

---

## ⚠️ Test Data Notes

### For Electricity:
- Use any valid meter number format
- Amount can be any value (100-50,000)
- PayScribe will validate the meter number exists

### For Cable:
- You **must use a real smart card number** from the provider's system
- You **must get the plan_id** from PayScribe dashboard
- Customer name must match the account holder's name
- In sandbox, use test numbers from PayScribe

---

## 🔍 Debugging Tips

### If you get validation error:
- Check the smart card number is correct
- Make sure plan_id is valid from PayScribe dashboard
- Verify customer name matches

### If you get authentication error:
- Same as data vending - check API key in Supabase secrets
- Make sure PAYSCRIBE_ENV is set correctly

### If you get IP whitelisting error:
- You're on production mode - switch to sandbox or whitelist IP with PayScribe

---

## 📊 Key Differences from Data Vending

| Feature | Data Vending | Bill Payment |
|---------|--------------|--------------|
| Endpoint | /data/vend | /electricity/vend or /multichoice/vend |
| Network | mtn, glo, airtel, etc | ekedc, gotv, dstv, etc |
| Identifier | recipient (phone) | meter_number or smart_card_number |
| Plan | plan_id | plan_id |
| Validation | Auto-validates phone | Manual validation recommended |

---

## 📞 Next Steps

1. **Test electricity payment** with a test meter number
2. **Get cable plans** from PayScribe dashboard
3. **Test cable payment** with a valid smart card
4. **Check response** in console logs
5. **Report any issues**
