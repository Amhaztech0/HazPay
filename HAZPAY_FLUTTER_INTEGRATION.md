# Flutter HazPay Integration - Quick Reference

## What Changed

Your Flutter app now calls **Supabase Edge Function** (`buyData`) instead of calling Amigo API directly.

### Before (❌ Insecure)
```dart
// API key exposed in Flutter code
const String _apiKey = '82ce1d0b91d0228e92e538b742382f73d0e025f7ea1a2928b203d14797e38428';

final response = await http.post(
  Uri.parse('https://amigo.ng/api/data/'),
  headers: {
    'X-API-Key': _apiKey,  // ❌ EXPOSED TO USERS
    'Content-Type': 'application/json',
  },
  body: jsonEncode({...}),
);
```

### After (✅ Secure)
```dart
// No API key in Flutter code!

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
```

---

## How It Works

```
┌─────────────────┐
│  Flutter App    │
│  (User's Phone) │
└────────┬────────┘
         │ Calls supabase.functions.invoke('buyData')
         │ No API key sent
         ↓
┌────────────────────────────────────┐
│  Supabase Edge Function (buyData)  │
│  (Your server)                     │
│  • Validates request               │
│  • Gets API key from secrets       │
│  • Calls Amigo API securely        │
│  • Returns clean response          │
└────────┬───────────────────────────┘
         │ JSON response (success/error)
         ↓
┌─────────────────┐
│  Flutter App    │
│  (Display result)
└─────────────────┘
```

---

## Code in `lib/services/hazpay_service.dart`

### Updated `purchaseData()` method

```dart
Future<HazPayTransaction> purchaseData({
  required String mobileNumber,
  required String planId,
  required int networkId,
  required double amount,
  required bool isPortedNumber,
}) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    debugPrint('💳 Purchasing data: $planId for $mobileNumber');

    // Create transaction record first (pending)
    final transactionId = _generateId();
    final transaction = HazPayTransaction(
      id: transactionId,
      userId: userId,
      type: 'purchase',
      amount: amount,
      networkName: networkId == 1 ? 'MTN' : 'GLO',
      dataCapacity: planId,
      mobileNumber: mobileNumber,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Save transaction to Supabase
    await supabase.from('hazpay_transactions').insert(transaction.toJson());

    // ✅ Call Supabase Edge Function (API key secure on server-side)
    debugPrint('🔐 Calling Supabase Edge Function for secure purchase...');
    
    final response = await supabase.functions.invoke(
      'buyData',
      body: {
        'network': networkId,
        'mobile_number': mobileNumber,
        'plan': int.parse(planId),
        'Ported_number': isPortedNumber,
        'idempotency_key': transactionId,  // Prevent duplicate charges
      },
    );

    debugPrint('📡 Edge Function Response: $response');

    // Parse response
    final responseBody = response as Map<String, dynamic>;

    if (responseBody['success'] == true) {
      final data = responseBody['data'] as Map<String, dynamic>;
      
      // Update transaction as successful
      await supabase
          .from('hazpay_transactions')
          .update({
            'status': 'success',
            'reference': data['reference'],
          })
          .eq('id', transactionId);

      // Deduct from wallet
      await _deductFromWallet(userId, amount);

      debugPrint('✅ Data purchase successful: ${data['reference']}');
      
      return HazPayTransaction(
        id: transactionId,
        userId: userId,
        type: 'purchase',
        amount: amount,
        networkName: networkId == 1 ? 'MTN' : 'GLO',
        dataCapacity: planId,
        mobileNumber: mobileNumber,
        reference: data['reference'],
        status: 'success',
        createdAt: DateTime.now(),
      );
    } else {
      final error = responseBody['error'] as Map<String, dynamic>;
      final errorMessage = error['message'] ?? 'Purchase failed';
      final errorCode = error['code'] ?? 'UNKNOWN_ERROR';
      
      // Update transaction as failed
      await supabase
          .from('hazpay_transactions')
          .update({
            'status': 'failed',
            'error_message': '$errorCode: $errorMessage',
          })
          .eq('id', transactionId);

      throw Exception('$errorCode: $errorMessage');
    }
  } catch (e) {
    debugPrint('❌ Error purchasing data: $e');
    rethrow;
  }
}
```

---

## What You Need to Do

### 1. Set Up Supabase Secret (One-time)
```powershell
supabase secrets set AMIGO_API_KEY="your_amigo_api_key_here"
```

### 2. Deploy Edge Function (One-time)
```powershell
supabase functions deploy buyData
```

### 3. Rebuild Flutter App
```powershell
flutter clean
flutter pub get
flutter run
```

### 4. Test
- Open Buy Data screen
- Use test number: `09000012345` (starts with 090000)
- Complete purchase
- Should see success message

---

## Error Handling

### User-Friendly Error Messages

```
Invalid Number
↓
The mobile number provided is invalid.

Plan Not Available
↓
Selected plan is not available for this network.

Network Not Supported
↓
This network is not yet supported.
```

The Edge Function automatically translates technical Amigo errors into user-friendly messages.

---

## Security Benefits

✅ **API Key Protected**
- Stored only in Supabase Secrets
- Never sent to client device
- Never visible in network traffic from app

✅ **Request Validation**
- Edge Function validates all inputs
- Invalid requests rejected server-side
- Prevents malicious requests

✅ **Duplicate Prevention**
- `idempotency_key` parameter prevents accidental charges
- Uses transaction ID to ensure uniqueness

✅ **Clean Error Handling**
- Technical errors not exposed to users
- Consistent JSON response format
- Proper HTTP status codes

---

## Files Modified

- ✅ `lib/services/hazpay_service.dart`
  - Removed hardcoded API key
  - Updated `purchaseData()` to call Edge Function
  - Added proper error handling

## Files Created

- ✅ `supabase/functions/buyData/index.ts` - The Edge Function
- ✅ `supabase/functions/buyData/deno.json` - Deno config
- ✅ `HAZPAY_EDGE_FUNCTION_SETUP.md` - Full setup guide
- ✅ This file - Quick reference

---

## Troubleshooting

### Issue: `supabase.functions.invoke is not available`
**Solution:** Make sure you have `supabase_flutter` package updated:
```powershell
flutter pub upgrade supabase_flutter
```

### Issue: `403 Forbidden` when calling function
**Solution:** Edge Function calls are authenticated. Make sure user is logged in:
```dart
final user = supabase.auth.currentUser;
if (user == null) throw Exception('User not authenticated');
```

### Issue: `404 Function not found`
**Solution:** The function isn't deployed. Run:
```powershell
supabase functions deploy buyData
```

### Issue: `AMIGO_API_KEY not configured`
**Solution:** The secret isn't set. Run:
```powershell
supabase secrets set AMIGO_API_KEY="your_key"
supabase secrets list  # Verify it's there
```

---

## Testing Endpoints

### Direct cURL test (PowerShell)
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
} | ConvertTo-Json

Invoke-WebRequest -Uri $url -Method POST -Headers $headers -Body $body
```

Replace `YOUR_PROJECT_ID` and `YOUR_ANON_KEY` from Supabase Settings.

---

**Last Updated:** November 21, 2025
