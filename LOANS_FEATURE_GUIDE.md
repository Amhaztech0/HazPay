# Loans Management Feature

## Overview

A new **Loans Management** section has been added to the HazPay admin dashboard, allowing you to track user loans with status, amounts, and repayment dates.

## Features

✅ **Comprehensive Loan Tracking**
- View all user loans in a modern table
- Display user email and name with loan details
- Track loan amount in Nigerian Naira (₦)
- Monitor loan status (pending, approved, active, repaid, defaulted)
- View issued date and repaid date

✅ **Dashboard Statistics**
- Total number of loans
- Number of active loans
- Total loan amount issued
- Total amount repaid

✅ **Search & Filter**
- Search by user email, name, or user ID
- Filter by loan status
- Quick view of matching results

✅ **Data Export**
- Export all loans to CSV for external analysis
- Includes all visible columns and metadata
- Ready for Excel or reporting tools

## Setup Instructions

### 1. Create the Loans Table in Supabase

1. Go to https://app.supabase.com
2. Select your HazPay project
3. Click **SQL Editor** (left sidebar)
4. Click **New Query**
5. Copy and paste the entire content from `db/CREATE_LOANS_TABLE.sql`
6. Click **Run** (or press `Ctrl+Enter`)

Expected output: "Successfully executed" (queries should return 0 rows)

### 2. Access the Loans Page

1. Log in to the admin dashboard at https://haz-gg03p0j6m-amhazs-projects-af2b0e98.vercel.app (or your Vercel URL)
2. Click **Loans** in the sidebar navigation
3. View all loans and manage them

## Loan Status Reference

| Status | Description | Use Case |
|--------|-------------|----------|
| **pending** | Loan request submitted, awaiting approval | New loan applications |
| **approved** | Loan approved but not yet disbursed | After admin review |
| **active** | Loan disbursed, waiting for repayment | Currently owed by user |
| **repaid** | Loan fully repaid by user | Completed transactions |
| **defaulted** | User failed to repay on schedule | Past due/problematic loans |

## Database Schema

```sql
CREATE TABLE loans (
  id uuid PRIMARY KEY,           -- Unique loan ID
  user_id uuid,                  -- References auth.users
  amount numeric,                -- Loan amount in ₦
  status varchar(50),            -- See status reference above
  issued_date timestamp,         -- When loan was issued
  repaid_date timestamp,         -- When loan was repaid (nullable)
  created_at timestamp,          -- Record creation time
  updated_at timestamp           -- Last update time
);
```

## UI Components Used

The Loans page uses modern design system components:

- **StatCard**: Displays summary statistics with color coding
- **Badge**: Status indicators with color-coded backgrounds
- **Card**: Main container for the table section
- **Search & Filter**: Quick lookup and status filtering
- **Export**: CSV download functionality

## How to Add Sample Data

You can manually add loans via Supabase SQL Editor:

```sql
INSERT INTO public.loans (user_id, amount, status, issued_date, repaid_date)
VALUES 
  ('user-id-1', 50000, 'active', NOW(), NULL),
  ('user-id-2', 100000, 'repaid', NOW() - INTERVAL '30 days', NOW() - INTERVAL '5 days'),
  ('user-id-3', 25000, 'pending', NOW(), NULL);
```

Then refresh the admin dashboard to see the loans appear.

## Features Included

### Statistics Cards
- **Total Loans**: Count of all loans in the system
- **Active Loans**: Loans currently being repaid (status = 'active')
- **Total Loan Amount**: Sum of all loan amounts issued
- **Total Repaid**: Sum of all loans with status = 'repaid'

### Table Columns
| Column | Description |
|--------|-------------|
| User | User name and email |
| Loan Amount (₦) | Amount issued in Nigerian Naira |
| Status | Current loan status with color badge |
| Issued Date | When the loan was created |
| Repaid Date | When the loan was repaid (if applicable) |
| Loan ID | Unique loan identifier |

### Filtering & Search
- **Search Box**: Search by user email, name, or ID
- **Status Filter**: Quick filter by loan status
- **Results Count**: Shows how many loans match your criteria

### Export
- **CSV Export**: Download filtered loans to Excel-compatible CSV
- **Timestamp**: Includes date in filename for tracking
- **All Fields**: Complete data with formatted currency

## Troubleshooting

### "No loans found" but loans exist in database
- **Solution**: Verify the `loans` table was created successfully by running:
  ```sql
  SELECT COUNT(*) FROM public.loans;
  ```
- If no table exists, run the SQL migration from `db/CREATE_LOANS_TABLE.sql`

### Loans don't appear after adding data
- **Solution**: Clear browser cache (`Ctrl+Shift+Delete`) and refresh
- Verify user_id references valid auth users in your Supabase project

### Search/Filter not working
- **Solution**: Check that the table has data and RLS policies are correctly applied
- Verify you're logged in as an authenticated user

## Future Enhancements

Potential additions to the Loans system:

- 📅 **Loan Schedule**: Track monthly repayment schedules
- 💰 **Interest Calculation**: Auto-calculate interest rates and due dates
- ⚠️ **Alerts**: Notify admins of overdue loans
- 📊 **Analytics**: Visualize loan performance and default rates
- ✏️ **Loan Editing**: Update loan status and amounts from dashboard
- 🔔 **Notifications**: Send repayment reminders to users

## Support

For issues or questions:
1. Check the Supabase SQL Editor for table verification
2. Review the RLS policies under **Authentication > Policies**
3. Verify environment variables are set correctly
4. Check browser console for errors (`F12` → Console tab)

## Files Modified

- `src/app/loans/page.tsx` - New Loans page component
- `src/components/Sidebar.tsx` - Added Loans navigation link
- `src/types/index.ts` - Added Loan interface
- `db/CREATE_LOANS_TABLE.sql` - Database schema and RLS policies

## Deployment

✅ **Status**: Loans page successfully deployed to production
📍 **URL**: https://haz-gg03p0j6m-amhazs-projects-af2b0e98.vercel.app

The page is live and ready to use once the database table is created!
