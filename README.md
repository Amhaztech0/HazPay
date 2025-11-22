# HazPay Admin Dashboard

A comprehensive web-based admin dashboard for managing the HazPay Fintech system. Monitor transactions, manage pricing, track wallets, and view analytics without needing to redeploy the app.

## 🚀 Features

### 📊 Dashboard
- **Real-time metrics**: Total revenue, profit, transactions, active users
- **Sales trends**: 30-day sales and profit charts
- **Network distribution**: Visual breakdown of MTN vs GLO transactions
- **Today's metrics**: Quick view of daily sales and profit

### 💰 Transactions
- **Complete transaction history** with user, amount, network, and status
- **Advanced search & filtering** by phone, reference, user, network, and date
- **Sortable columns** by date, amount, profit, and status
- **CSV export** for external analysis
- **Real-time status**: Success, failed, or pending

### 💵 Pricing Management
- **Direct price editing** for all data plans (MTN & GLO)
- **Instant updates** - changes reflect in app immediately without rebuilding
- **Profit tracking** - automatic calculation of margin per plan
- **Cost vs Sell price** - manage both Amigo cost and your selling price
- **No app redeployment needed** - changes live instantly

### 👛 Wallet Management
- **User wallet overview** with balance, total deposits, and spending
- **Manual balance adjustments** - add or subtract credits when needed
- **Top users by balance** - identify VIP customers
- **Search by user ID, email, or name**
- **Audit trail** - track all balance changes

### 👥 User Management
- **User directory** with email, phone, name, registration date
- **Account status control** - suspend or reactivate users
- **Last login tracking** - identify active vs dormant users
- **Quick stats** - total, active, and suspended user counts
- **Bulk search** across multiple user fields

### 📈 Reports & Analytics
- **Daily, weekly, monthly reports** with switchable timeframes
- **Sales trends chart** - visualize revenue and profit over time
- **Transaction volume** - bar chart of transaction counts
- **Key metrics**:
  - Total sales and profit by period
  - Profit margin percentage
  - Average transaction value
  - Transaction count
- **CSV export** for Excel and external tools
- **Detailed breakdown table** with all metrics per period

### 🔐 Security
- **Supabase authentication** - secure admin login
- **Role-based access** - foundation for multi-admin setup
- **Protected routes** - automatic redirection for unauthenticated users
- **Session management** - automatic logout on auth changes

## 📋 Quick Start

### Prerequisites
- Node.js 18+ and npm
- Supabase project with HazPay database
- Supabase URL and Anon Key

### Installation

1. **Navigate to admin folder:**
   ```bash
   cd admin
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment:**
   ```bash
   cp .env.local.example .env.local
   ```
   
   Edit `.env.local`:
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run development server:**
   ```bash
   npm run dev
   ```
   
   Open [http://localhost:3000](http://localhost:3000)

## 🎯 Common Tasks

### Change Data Plan Pricing
1. Go to **Pricing** tab
2. Click **Edit** on the plan
3. Change **Sell Price**
4. Click **Save**
5. ✨ App updates immediately!

### View All Transactions
1. Go to **Transactions** tab
2. Search by phone or reference
3. Filter by network (MTN/GLO)
4. Sort by any column
5. Export to CSV

### Manage User Wallets
1. Go to **Wallets** tab
2. Search user by ID
3. Click **Adjust**
4. Add or subtract credits
5. Confirm

### Suspend a User
1. Go to **Users** tab
2. Find user
3. Click **Suspend**
4. User blocked from app

### Generate Reports
1. Go to **Reports** tab
2. Choose timeframe (Daily/Weekly/Monthly)
3. View charts and metrics
4. Export to CSV

## 📱 Mobile Responsive

Works on desktop, tablet, and mobile with responsive Tailwind design.

## 🌐 Deploy to Vercel

1. Push to GitHub
2. Go to [Vercel](https://vercel.com)
3. Import GitHub repo
4. Add environment variables
5. Deploy!

## 🏗️ Project Structure

```
src/
├── app/                 # Pages
│   ├── dashboard/
│   ├── transactions/
│   ├── pricing/
│   ├── wallets/
│   ├── users/
│   ├── reports/
│   └── login/
├── components/          # React components
├── lib/                 # Utilities
├── store/               # State management
└── types/               # TypeScript types
```

## 🔄 Auto-Refresh

- Dashboard: Every 60 seconds
- Transactions: Every 30 seconds
- Pricing/Wallets: On-demand

## 🆘 Troubleshooting

**"Not authenticated" error:**
- Check Supabase credentials in `.env.local`
- Verify you're logged in with Supabase user

**Charts not showing:**
- Ensure database has transaction data
- Check browser console for errors

**Prices not updating:**
- Refresh page after edit
- Verify pricing table exists in Supabase

## 📊 Export Data

All pages support CSV export:
- Include all visible columns
- Proper formatting
- Ready for Excel

## 🚀 Future Features

- Loan/Credit system
- SMS/Email templates
- Withdrawal processing
- Advanced analytics
- Multi-admin roles
- Audit logs
- Dark mode

## 📄 License

Part of HazPay Fintech System. All rights reserved.

---

**Built with:** Next.js 16 • TypeScript • Tailwind CSS • Recharts • Supabase
