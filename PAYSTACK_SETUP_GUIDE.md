# Paystack Integration Setup Guide

This guide explains how to set up Paystack for real wallet deposits in HazPay.

## 🏦 What is Paystack?

Paystack is a payment gateway that allows you to accept card payments securely. Users can deposit money into their HazPay wallet using their bank cards.

---

## 📋 Step 1: Create a Paystack Account

1. Go to **https://paystack.com**
2. Click **Sign Up**
3. Fill in your business details:
   - Business name
   - Email
   - Password
4. Verify your email
5. Complete your profile with:
   - Business address
   - Phone number
   - Bank details (for payouts)

---

## 🔑 Step 2: Get Your API Keys

1. Log in to your **Paystack Dashboard**: https://dashboard.paystack.co
2. Navigate to **Settings** → **Developer**
3. You'll see two keys:
   - **Public Key** (pk_live_xxx or pk_test_xxx)
   - **Secret Key** (sk_live_xxx or sk_test_xxx)

**Important:**
- **Use TEST keys first** for development (pk_test_xxx)
- **Switch to LIVE keys** when deploying to production (pk_live_xxx)

---

## ⚙️ Step 3: Update Flutter Code

### 3.1 Add Public Key to PaystackService

Open `lib/services/paystack_service.dart` and update:

```dart
class PaystackService {
  // Replace this with your PUBLIC key from Paystack dashboard
  static const String PUBLIC_KEY = 'pk_live_YOUR_PAYSTACK_PUBLIC_KEY';
  
  // Example:
  // static const String PUBLIC_KEY = 'pk_live_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6';
```

**Get your PUBLIC key from:**
- Paystack Dashboard → Settings → Developer → Public Key (Live or Test)

### 3.2 Install Paystack Package

Run in your Flutter project:

```powershell
cd c:\Users\Amhaz\Desktop\zinchat\zinchat
flutter pub get
```

This installs `flutter_paystack: ^1.0.1` from pubspec.yaml.

---

## 🧪 Step 4: Test Payment Flow

### 4.1 Using Test Keys (Recommended First)

1. In `paystack_service.dart`, use TEST public key:
   ```dart
   static const String PUBLIC_KEY = 'pk_test_...'; // Your test key
   ```

2. In your Flutter app, try depositing:
   1. Open HazPay → Wallet
   2. Click "Deposit"
   3. Enter amount: `₦100`
   4. **Paystack checkout page will open in your browser** (automatically)
   5. Enter test card details:
      - Card number: `4084 0343 8220 2259`
      - Expiry: Any future date (e.g., 12/25)
      - CVV: `123`
   6. Click "Complete Payment"
   7. Return to app - wallet will be updated
   
   **Note:** The checkout page opens in your default browser. Complete the payment there, then the app will verify and credit your wallet.

3. Should see success/failure response

### 4.2 Using Live Keys (Production)

1. After testing works, switch to LIVE key:
   ```dart
   static const String PUBLIC_KEY = 'pk_live_...'; // Your live key
   ```

2. Users can now deposit real money
3. Funds go directly to your business bank account

---

## 💳 Test Cards (for TEST mode only)

Use these test cards when using `pk_test_xxx`:

| Card Number | Expiry | CVV | Status |
|---|---|---|---|
| 4084 0343 8220 2259 | 12/25 | 123 | Success |
| 5061 0614 6623 9891 | 12/25 | 090 | Success |
| 3782 822463 10005 | 12/25 | 100 | Success |

**Note:** These only work with TEST keys. Don't use live keys for testing.

---

## 🔄 Payment Flow

```
User taps "Deposit"
    ↓
Enters amount (e.g., ₦500)
    ↓
PaystackService.chargeCard() is called
    ↓
Paystack payment UI appears
    ↓
User enters card details
    ↓
Payment processed
    ↓
Success → Funds added to wallet
OR
Failure → Shows error message
```

---

## 🛡️ Security Best Practices

1. **Never commit your keys to Git:**
   ```bash
   # Add to .gitignore
   paystack_service.dart  # Optional if keys are hardcoded
   ```

2. **For Production:**
   - Use environment variables or Supabase Secrets
   - Verify payments server-side
   - Use Paystack webhooks for payment confirmation

3. **Current Implementation:**
   - ✅ Public key safe (non-sensitive)
   - ⚠️ Client-side payment initiation
   - 📌 TODO: Add server-side verification

---

## 🔍 Verifying Transactions

In production, always verify payments server-side:

```dart
// Server-side (Node.js/Python/etc.)
const secret = process.env.PAYSTACK_SECRET_KEY;
const ref = req.body.reference;

fetch(`https://api.paystack.co/transaction/verify/${ref}`, {
  headers: { 'Authorization': `Bearer ${secret}` }
})
.then(res => res.json())
.then(data => {
  if (data.status && data.data.status === 'success') {
    // Payment verified - add funds to wallet
  }
});
```

---

## 📱 Testing in Your App

### Scenario 1: Successful Deposit
1. Wallet shows ₦0
2. Click "Deposit"
3. Enter ₦1000
4. Use test card 4084 0343 8220 2259
5. Payment succeeds
6. Wallet now shows ₦1000

### Scenario 2: Failed Payment
1. Wallet shows ₦500
2. Click "Deposit"
3. Enter ₦200
4. Use expired test card or wrong CVV
5. Payment fails
6. Error message shown
7. Wallet still shows ₦500

### Scenario 3: Insufficient Funds
1. Wallet shows ₦500
2. Try buying ₦1000 data plan
3. Shows "Insufficient balance" error
4. Suggest depositing more

---

## 🐛 Troubleshooting

### Issue: "Payment UI doesn't appear"
**Solution:** Make sure:
- Paystack public key is set correctly
- `PaystackService.initialize()` was called on app startup
- You're using correct key type (test vs live)
- Browser can open (url_launcher may be blocked on some devices)

### Issue: "Browser opens but checkout page is blank"
**Solution:**
- Make sure you're on internet
- Paystack servers might be down (check status.paystack.co)
- Try refreshing the browser page

### Issue: "I completed payment but wallet wasn't updated"
**Solution:**
- The app waits 3 seconds after opening checkout
- If you take longer, the app may stop waiting
- The wallet should still update within 1 minute (background verification)
- Check if transaction appears in Paystack Dashboard
- Check if transaction logged in Supabase `hazpay_transactions` table

### Issue: "Payment processed but funds not added"
**Solution:** Check:
- Console logs show "Payment verified successfully"
- Supabase transaction table has success status
- Wallet balance was updated via `_addToWallet()`
- Check Paystack Dashboard - did payment actually succeed?

---

## 📊 Monitoring Transactions

### In Paystack Dashboard:
1. Go to **Transactions**
2. See all deposits made
3. Track payments status
4. View settlement schedule

### In Supabase:
1. Go to SQL Editor
2. Query your transactions:
```sql
SELECT * FROM hazpay_transactions 
WHERE type = 'deposit' 
ORDER BY created_at DESC;
```

---

## 🚀 Deployment Checklist

Before going live:

- [ ] Switch to LIVE public key in `paystack_service.dart`
- [ ] Test with real test cards first
- [ ] Set up Paystack webhook for payment verification
- [ ] Test with real card (small amount first)
- [ ] Monitor first few transactions
- [ ] Set up email notifications for deposits
- [ ] Document for support team

---

## 💰 Pricing

Paystack charges **1.5% + ₦25** per transaction for card payments.

Example:
- Deposit: ₦1000
- Fee: (1000 × 1.5%) + 25 = 40
- User receives: ₦960

You can choose to:
- Charge user the fee (user pays ₦1040 to receive ₦1000)
- Absorb the fee (you receive ₦960)
- Split the fee

---

## 📞 Support

- **Paystack Support:** https://paystack.com/support
- **Paystack Docs:** https://paystack.com/docs
- **Community:** https://paystack.com/blog

---

**Last Updated:** November 21, 2025
**Version:** 1.0
