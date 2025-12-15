# HazPay Loan System - Deployment Guide

## Overview
The loan system allows users with ₦10,000+ transaction volume to request 1GB data loans. Repayment is automatic when they deposit funds.

## Deployment Steps

### 1. Deploy Database Schema

**Run in Supabase SQL Editor:**
```sql
-- Copy and paste the entire LOAN_SYSTEM_SCHEMA.sql file
-- This creates:
-- - loans table
-- - Eligibility and repayment functions
-- - Automatic triggers for status updates
```

**File:** `LOAN_SYSTEM_SCHEMA.sql`

### 2. Deploy Edge Function

```bash
cd c:\Users\Amhaz\Desktop\zinchat
npx supabase functions deploy requestLoan
```

**Function:** `supabase/functions/requestLoan/index.ts`
- Checks loan eligibility
- Creates loan record
- Calls Amigo API
- Handles auto-repayment

### 3. Add Loan Screen to Navigation

Update `lib/main.dart` to include loan screen in bottom navigation:

```dart
// Add LoanScreen import
import 'package:example_zinchat/screens/fintech/loan_screen.dart';

// Add to bottom nav items in HazPayDashboard
// Index 5 for example
```

### 4. Update HazPayService

Already done! The following methods are ready:
- `checkLoanEligibility()` - Check if user is eligible
- `requestLoan()` - Request a 1GB loan
- `getActiveLoan()` - Get active loan status
- `_checkAndRepayLoan()` - Auto-repay on deposit

### 5. Test the Flow

1. **Create test transaction:**
   - User buys multiple data plans totaling ₦10,000+
   - This triggers eligibility check

2. **Request loan:**
   - Open Loan screen
   - Should show "Eligible" message
   - Click "Request 1GB Loan"
   - Loan request should process

3. **Auto-repayment:**
   - Deposit funds (e.g., ₦1000)
   - If wallet balance >= loan_fee, it auto-repays
   - Check Supabase: loans table should show `status='repaid'`

## Database Structure

### Loans Table
```
id              - UUID primary key
user_id         - References user (foreign key)
plan_id         - Which plan (always 2 for 1GB)
loan_fee        - Amount in Naira (your sell_price for 1GB)
status          - pending → issued → repaid (or failed)
created_at      - When requested
issued_at       - When data was given
repaid_at       - When auto-repaid
failure_reason  - Why it failed (if failed)
```

### Profile Changes
```
has_active_loan  - true/false (auto-updated)
loan_eligible    - true/false (auto-updated based on volume)
```

## How Auto-Repayment Works

1. User deposits funds via Paystack
2. `depositToWallet()` adds balance
3. `_checkAndRepayLoan()` is called
4. If user has active loan AND balance >= loan_fee:
   - Loan fee is deducted
   - Loan marked as 'repaid'
   - `repaid_at` timestamp set
   - `has_active_loan` set to false

## API Integration

### Edge Function: requestLoan
**Endpoint:** `supabase/functions/requestLoan`

**Request:**
```json
{
  "user_id": "uuid"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "loan_id": "uuid",
    "status": "issued",
    "reference": "amigo_reference",
    "message": "1GB loan issued successfully..."
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": {
    "code": "NOT_ELIGIBLE",
    "message": "You need to spend ₦10,000 or more..."
  }
}
```

## Service Methods (HazPayService)

### checkLoanEligibility()
```dart
final result = await hazPayService.checkLoanEligibility();
// Returns:
// {
//   'eligible': bool,
//   'totalSpent': double,
//   'hasActiveLoan': bool,
//   'requiredAmount': 10000.0,
//   'remainingAmount': double
// }
```

### requestLoan()
```dart
final result = await hazPayService.requestLoan();
// Returns:
// {
//   'success': bool,
//   'loan_id': string,
//   'status': string,
//   'message': string
// }
```

### getActiveLoan()
```dart
final loan = await hazPayService.getActiveLoan();
// Returns HazPayLoan? or null if no active loan
```

## Troubleshooting

### "Not eligible" error
- Check if user has ₦10,000+ in successful purchases
- Query: `SELECT SUM(sell_price) FROM hazpay_transactions WHERE user_id='xxx' AND status='success'`

### Loan not auto-repaying
- Check `has_active_loan` in profiles table
- Verify triggers are working: `SELECT * FROM pg_trigger WHERE tgrelname='hazpay_transactions'`
- Manually test: Deposit funds and check logs

### Edge Function errors
- Check Supabase → Functions → requestLoan → Logs
- Verify Amigo API key is in secrets
- Test with: `curl -X POST https://your-supabase-url/functions/v1/requestLoan -H "Authorization: Bearer YOUR_TOKEN" -d '{"user_id":"uuid"}'`

## Future Enhancements

- Multiple loans per user (after first is repaid)
- Different loan amounts (2GB, 3GB, etc.)
- Interest/fee on loans
- Loan history UI
- Admin loan management dashboard
- Notifications for loan status changes
