# Quick Integration Guide

## Add Bill Payment Screens to Your App

### Option 1: Add to Fintech Dashboard Menu

**File:** `lib/screens/fintech/hazpay_dashboard.dart`

```dart
// Add this import at the top
import 'pay_bills_screen.dart';

// In your navigation/menu section, add:
ListTile(
  leading: Icon(Icons.receipt_long),
  title: Text('Pay Bills'),
  subtitle: Text('Electricity • Cable TV'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PayBillsScreen(),
      ),
    );
  },
),
```

---

### Option 2: Add to Bottom Navigation

**File:** `lib/screens/fintech/hazpay_dashboard.dart` or your main app file

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.receipt),
  label: 'Bills',
),

// In your onItemTapped handler:
case 2: // Bills tab
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const PayBillsScreen(),
    ),
  );
  break;
```

---

### Option 3: Add as Floating Action Button

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PayBillsScreen(),
      ),
    );
  },
  child: Icon(Icons.receipt_long),
),
```

---

## Import the Service

Make sure you import the HazPayService in screens that need it:

```dart
import 'package:zinchat/services/hazpay_service.dart';

// Usage:
final hazPayService = HazPayService();
final plans = await hazPayService.getDataPlans();
final wallet = await hazPayService.getWallet();
```

---

## Update Imports in Existing Screens

Replace any old imports:

```dart
// OLD - Remove this:
// import 'package:zinchat/services/hazpay_service_old_amigo.dart';

// NEW - Use this:
import 'package:zinchat/services/hazpay_service.dart';
```

---

## File Structure

After integration, your fintech screens directory should have:

```
lib/screens/fintech/
├── hazpay_dashboard.dart
├── buy_data_screen.dart
├── wallet_screen.dart
├── loan_screen.dart
├── loan_history_screen.dart
├── transaction_history_screen.dart
├── rewarded_ads_screen.dart
├── pay_bills_screen.dart              [NEW]
├── pay_electricity_bill_screen.dart   [NEW]
└── pay_cable_bill_screen.dart         [NEW]
```

---

## Test the Integration

1. **Test Data Purchase**
   ```dart
   // Test with MTN
   final result = await hazPayService.purchaseData(
     mobileNumber: '08012345678',
     planId: '1',
     networkId: 1,
     amount: 280,
     isPortedNumber: false,
   );
   ```

2. **Test Electricity Payment**
   ```dart
   final payment = await hazPayService.payElectricityBill(
     discoCode: 'ikedc',
     meterNumber: '1234567890',
     amount: 5000,
     meterType: 'prepaid',
   );
   ```

3. **Test Cable Payment**
   ```dart
   final payment = await hazPayService.payCableBill(
     cableProvider: 'dstv',
     planId: 'ng_dstv_hdprme36',
     amount: 19800,
     smartcardNumber: '0123456789',
   );
   ```

---

## Common Issues & Solutions

### "HazPayService not found"
- Ensure `lib/services/hazpay_service.dart` exists
- Check import path is correct
- Run `flutter pub get`

### "BillPayment class not found"
- Make sure you're importing from the service:
  ```dart
  import 'package:zinchat/services/hazpay_service.dart';
  ```

### "Wallet returns null"
- User may not have a wallet created yet
- Service automatically creates wallet on first call
- Check user is authenticated

### "Plans list is empty"
- SQL migration may not have run
- Check Supabase database for pricing table data
- Verify `network_id` and `payscribe_plan_id` exist

---

## Environment Setup

### 1. Supabase Configuration
Ensure in your main.dart:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_KEY',
);
```

### 2. Set API Key
In Supabase Dashboard → Settings → Secrets:
```
PAYSCRIBE_API_KEY = "Your Payscribe Bearer Token"
```

### 3. Verify Edge Functions Deployed
Check in Supabase Dashboard → Edge Functions:
- [ ] buyData
- [ ] payBill
- [ ] requestLoan

---

## Styling Customization

### Change Primary Color
In `pay_bills_screen.dart`, replace:
```dart
HazPayColors.primary
```
with your preferred color:
```dart
Color.fromARGB(255, 0, 122, 255)  // Your app's primary color
```

### Update Icons
Edit the emoji icons in screens:
```dart
// Current
final List<Map<String, String>> _discos = [
  {'code': 'ikedc', 'name': 'Ikeja Electric (IKEDC)', 'icon': '⚡'},
  ...
];

// Custom
{'icon': Icons.flash_on}  // Use Flutter icons instead
```

---

## Performance Tips

1. **Cache Plans Data**
   ```dart
   static final Map<int, List<DataPlan>> _plansCache = {};
   // Already implemented in service!
   ```

2. **Lazy Load Screens**
   ```dart
   builder: (context) => const PayBillsScreen(),  // Lazy loads on tap
   ```

3. **Use FutureBuilder for Async Data**
   ```dart
   FutureBuilder<HazPayWallet>(
     future: hazPayService.getWallet(),
     builder: (context, snapshot) {
       if (snapshot.hasData) return Text('Balance: ${snapshot.data!.balance}');
       return CircularProgressIndicator();
     },
   )
   ```

---

## API Reference

### HazPayService Methods

#### Data Purchase
```dart
Future<HazPayTransaction> purchaseData({
  required String mobileNumber,
  required String planId,
  required int networkId,
  required double amount,
  required bool isPortedNumber,
})
```

#### Electricity Bill
```dart
Future<BillPayment> payElectricityBill({
  required String discoCode,
  required String meterNumber,
  required double amount,
  String? meterType,
  String? customerName,
})
```

#### Cable Bill
```dart
Future<BillPayment> payCableBill({
  required String cableProvider,
  required String planId,
  required double amount,
  String? smartcardNumber,
})
```

#### Wallet
```dart
Future<HazPayWallet> getWallet()
Future<bool> depositToWallet(double amount)
```

#### Loans
```dart
Future<Map<String, dynamic>> checkLoanEligibility()
Future<Map<String, dynamic>> requestLoan({
  String? mobileNumber,
  int? networkId,
})
Future<HazPayLoan?> getActiveLoan()
```

#### History
```dart
Future<List<HazPayTransaction>> getTransactionHistory({
  int limit = 50,
  int offset = 0,
})
Future<List<BillPayment>> getBillPaymentHistory({
  int limit = 50,
  int offset = 0,
})
```

---

## Success Indicators

When successfully integrated, you should see:

✅ Bill payment screen accessible from fintech menu  
✅ Can select electricity discos (9 options)  
✅ Can select cable providers (4 options)  
✅ Wallet balance displayed accurately  
✅ Successful payments recorded in database  
✅ Payment history shows recent transactions  
✅ Error messages display properly  
✅ Loading states work correctly  

---

## Next Features to Add

- [ ] Payment notifications
- [ ] Automatic bill reminders
- [ ] Bill payment scheduling
- [ ] Recurring bill payments
- [ ] Airtime top-up history detailed view
- [ ] Export transaction PDF
- [ ] Add customer name/account lookup
- [ ] Meter/account validation endpoint

---

## Support

If you encounter issues:

1. Check logs in Supabase Dashboard → Edge Functions
2. Verify all 3 Edge Functions are deployed
3. Confirm PAYSCRIBE_API_KEY is set
4. Test with known valid inputs
5. Check user authentication status

---

**Happy integrating!** 🚀
