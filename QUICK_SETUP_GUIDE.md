# Quick Setup Guide - Admin Dashboard Payscribe Update

## 🚀 Quick Start (5 Minutes)

### Step 1: Update Database
Run this SQL in Supabase SQL Editor:

```bash
# Open Supabase Dashboard → SQL Editor → New Query
# Copy and paste contents of CREATE_BILL_PAYMENTS_TABLE.sql
# Click "Run"
```

Or from command line:
```bash
cd c:\Users\Amhaz\Desktop\zinchat
psql -h your-supabase-host -U postgres -d postgres -f CREATE_BILL_PAYMENTS_TABLE.sql
```

### Step 2: Verify Pricing Table
Already done! Check with:
```sql
SELECT COUNT(*) as airtel_plans 
FROM pricing 
WHERE network_id = 3;
-- Should return: 6
```

### Step 3: Restart Admin Dashboard

```bash
cd admin

# Install dependencies (if first time)
npm install

# Development mode
npm run dev

# OR Production build
npm run build
npm start
```

### Step 4: Test Features

1. **Open Dashboard:** http://localhost:3000
2. **Login** with your admin email
3. **Navigate to:**
   - Pricing → See Airtel plans
   - Bill Payments → New page created
   - Transactions → Airtel filter available

---

## 🎯 What to Check

### ✅ Pricing Page
- [ ] See "MTN Data Plans" section
- [ ] See "Airtel Data Plans" section (NEW)
- [ ] See "GLO Data Plans" section
- [ ] Text says "Payscribe" not "Amigo"

### ✅ Bill Payments Page (NEW)
- [ ] Page loads without errors
- [ ] Shows 6 stat cards (Total, Electricity, Cable, Internet, Airtime, Total Amount)
- [ ] Has search and filter controls
- [ ] Table displays (even if empty)
- [ ] Export CSV button works

### ✅ Transactions Page
- [ ] Network filter shows: All Networks, MTN, AIRTEL, GLO
- [ ] Can filter by Airtel

### ✅ Sidebar Navigation
- [ ] "Bill Payments" menu item visible
- [ ] Icon is a receipt/document icon
- [ ] Clicking navigates to /bills

---

## 📱 Testing Bill Payments

### From Mobile App:
1. Purchase electricity/cable/airtime from app
2. Check admin dashboard → Bill Payments
3. Should see transaction appear

### Sample SQL Query:
```sql
-- Check if bill_payments table exists
SELECT EXISTS (
   SELECT FROM information_schema.tables 
   WHERE table_name = 'bill_payments'
);

-- View all bill payments
SELECT * FROM bill_payments ORDER BY created_at DESC LIMIT 10;

-- Stats by type
SELECT 
  bill_type,
  COUNT(*) as count,
  SUM(amount) as total_amount
FROM bill_payments
GROUP BY bill_type;
```

---

## 🔧 Troubleshooting

### "Table doesn't exist" error
```bash
# Run the SQL script again
# In Supabase: SQL Editor → paste CREATE_BILL_PAYMENTS_TABLE.sql → Run
```

### Admin dashboard won't start
```bash
cd admin
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### Changes not showing
```bash
# Clear browser cache
# Or open in Incognito/Private mode
# Hard refresh: Ctrl + Shift + R (Windows) or Cmd + Shift + R (Mac)
```

### No Airtel plans visible
```bash
# Run UPDATE_PRICING_2025_12_15.sql again in Supabase
# Check: SELECT * FROM pricing WHERE network_id = 3;
```

---

## 🎨 Customization (Optional)

### Add More Networks
Edit `admin/src/app/transactions/page.tsx`:
```typescript
type FilterNetwork = 'all' | 'MTN' | 'GLO' | 'AIRTEL' | '9MOBILE';
```

### Change Bill Payment Colors
Edit `admin/src/app/bills/page.tsx`:
```typescript
const getBillIcon = (type: string) => {
  // Customize icons and colors here
}
```

### Adjust Auto-Refresh Rate
```typescript
// In bills/page.tsx
const interval = setInterval(fetchBills, 30000); // 30 seconds
// Change to 60000 for 1 minute, etc.
```

---

## 📊 Production Deployment

### Using Vercel (Recommended):
```bash
cd admin
vercel --prod
```

### Using Custom Server:
```bash
cd admin
npm run build
# Deploy .next folder to your hosting
```

### Environment Variables:
Make sure these are set:
```env
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

---

## ✅ All Done!

Your admin dashboard now supports:
- ✅ Airtel data plans
- ✅ Payscribe integration (not Amigo)
- ✅ Bill payments tracking (electricity, cable, internet, airtime)
- ✅ Enhanced filtering and reporting

**Need help?** Check [PAYSCRIBE_MIGRATION_COMPLETE.md](./PAYSCRIBE_MIGRATION_COMPLETE.md) for detailed documentation.
