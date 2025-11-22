# Create Test Admin Account in Supabase

Follow these steps to create a test admin that can login:

## Method 1: Via Supabase Dashboard (Fastest)

1. Go to https://app.supabase.com
2. Select your project: `avaewzkgsilitcrncqhe`
3. Go to **Authentication** → **Users**
4. Click **+ Create new user**
5. Enter:
   - Email: `admin@hazpay.com` (or any email you use)
   - Password: `Admin@123456` (or any strong password)
6. Click **Create user**
7. Done! User is created

## Now Login

1. Go to http://localhost:3000/login
2. Select **Password** tab
3. Email: `admin@hazpay.com`
4. Password: `Admin@123456`
5. Click **Sign In**
6. You'll be in the dashboard!

## For OTP Later

Once you're in the dashboard, we can set up proper OTP authentication by configuring Supabase's email settings.

---

**Do this first, then tell me when you're in the dashboard.**
