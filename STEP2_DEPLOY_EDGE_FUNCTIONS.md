# Deploy Edge Functions - Step by Step

You completed step 1! ✅ Now let's deploy the Edge Functions using the Supabase Dashboard (easiest way).

## Quick Overview

The two Edge Functions you need to deploy are:
- `send-status-reply-notification` - Notifies when someone replies to a status
- `send-reply-mention-notification` - Notifies when someone replies to a reply

Both are ready to go - just need to copy/paste them into Supabase Dashboard.

---

## How to Deploy (5 minutes)

### 1️⃣ Open Supabase Dashboard

1. Go to https://app.supabase.com
2. Click your **zinchat** project
3. On the left sidebar, find and click **Edge Functions**

---

### 2️⃣ Deploy First Function

**Function Name**: `send-status-reply-notification`

1. Click **Create a new function** (top right)
2. In the modal that appears:
   - **Function name**: `send-status-reply-notification`
   - Click **Create function**

3. You'll see an editor with a template - **DELETE IT ALL**

4. Copy this code from your project:
   - File: `c:\Users\Amhaz\Desktop\zinchat\zinchat\supabase\functions\send-status-reply-notification\index.ts`
   - Open it, copy all content

5. Paste it into the Supabase editor

6. Click **Deploy** button (top right)

7. Wait for it to finish - you should see:
   - ✅ "Function deployed successfully"
   - Status shows as "Active"

---

### 3️⃣ Deploy Second Function

**Function Name**: `send-reply-mention-notification`

Repeat the same process:

1. Click **Create a new function** again
2. **Function name**: `send-reply-mention-notification`
3. Click **Create function**
4. Delete template code
5. Copy from: `c:\Users\Amhaz\Desktop\zinchat\zinchat\supabase\functions\send-reply-mention-notification\index.ts`
6. Paste into editor
7. Click **Deploy**
8. Wait for confirmation ✅

---

## ✅ Verify Both Are Deployed

After deploying both:

1. Go to **Edge Functions** page
2. You should see two functions listed:
   - ✅ `send-status-reply-notification` (Active)
   - ✅ `send-reply-mention-notification` (Active)

If both show "Active" in green - **You're done with step 2!** 🎉

---

## What if something goes wrong?

### Issue: Can't find Edge Functions in sidebar
**Solution**: 
- Make sure you're in the right project (zinchat)
- It might be under a different menu - look for "Functions" or "Serverless"

### Issue: Deployment fails with red error
**Solution**:
- Click the function name
- Look at the error message
- Common fixes:
  - Make sure you copied ALL the code
  - Check for missing imports
  - Try deploying again

### Issue: Function shows but status is "building"
**Solution**:
- Just wait 1-2 minutes
- Refresh the page
- It will change to "Active"

---

## Next: Continue with Step 3

Once both functions show as "Active":

1. ✅ Step 1: Created user_tokens table
2. ✅ Step 2: Deployed Edge Functions (JUST FINISHED)
3. ⏳ Step 3: Verify Firebase Setup
4. ⏳ Step 4: Test Notifications

Your app is almost ready! Just verify Firebase is set up and then test. 🚀
