# Pricing Update Fix — RLS Policy Configuration

## Problem
When you update pricing in the admin dashboard, the changes don't persist in the database. After a refresh, the old prices return.

## Root Cause
The `pricing` table has Row-Level Security (RLS) enabled, but there's **no UPDATE policy** that allows authenticated users (admins) to modify prices. The update request fails silently on Supabase, so the database never saves the changes.

## Solution
Apply the RLS policies in `db/ENABLE_PRICING_UPDATE.sql` to allow authenticated users to UPDATE, INSERT, and DELETE from the `pricing` table.

### Steps to Fix

#### 1. Open Supabase Console
- Go to https://app.supabase.com
- Log in with your credentials
- Select your HazPay project

#### 2. Navigate to SQL Editor
- Click **SQL Editor** (left sidebar)
- Click **New query** button

#### 3. Copy & Paste the SQL Migration
- Copy all content from `db/ENABLE_PRICING_UPDATE.sql`
- Paste into the SQL Editor text box
- Click **Run** (or press `Ctrl+Enter`)

Expected output: "Successfully executed" (queries should return 0 rows)

#### 4. Verify the Fix Locally (Optional)
1. Stop your local dev server if running: `Ctrl+C`
2. Start it again: `npm run dev`
3. Open http://localhost:3000
4. Navigate to `/dashboard` → **Pricing**
5. Edit a price (e.g., change MTN 1GB cost_price from 250 to 260)
6. Click **Save**
7. Refresh the page (or navigate away and back)
8. Verify the new price persists

#### 5. Test on Production
1. Open https://haz-miyunehb9-amhazs-projects-af2b0e98.vercel.app (or your Vercel URL)
2. Log in with your email (enter OTP from email)
3. Navigate to **Pricing** page
4. Edit a price and save
5. Refresh the page — verify the new price is still there

## Troubleshooting

### "UPDATE failed" or "Permission denied" error in the app
- Ensure you ran the SQL migration successfully in Supabase Console
- Verify the authenticated user is logged in (not anonymous)
- Check Supabase dashboard for RLS policies on the `pricing` table (should show 4 policies)

### Prices still revert after refresh
- Clear browser cache: `Ctrl+Shift+Delete` (or `Cmd+Shift+Delete` on Mac)
- Log out and log back in
- Try in an incognito/private browser window

### Can't access Supabase Console
- Verify your Supabase credentials are correct
- Check that you have access to the HazPay project (should be listed in your organization)

## RLS Policies Created
The SQL migration creates 4 policies on the `pricing` table:
1. **pricing_select_for_all** — Anyone can READ prices (public)
2. **pricing_update_for_admin** — Authenticated users can UPDATE prices
3. **pricing_insert_for_admin** — Authenticated users can INSERT prices
4. **pricing_delete_for_admin** — Authenticated users can DELETE prices

These ensure your app can modify prices while keeping the data secure.

## Notes
- The `SELECT` policy is permissive (open to all) so the mobile app can read current prices.
- The `UPDATE`, `INSERT`, and `DELETE` policies require authentication, so only logged-in admins can modify prices.
- If you want to restrict these to a specific user role, you can add a `WHERE` clause to check `auth.uid()` against a profiles table.
