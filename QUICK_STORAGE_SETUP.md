# 🎯 Quick Fix: Create Storage Bucket in 3 Steps

## The Error
```
StorageException(message: Bucket not found, statusCode: 404)
```

## The Fix

### Step 1: Open Supabase Dashboard
Go to: https://supabase.com/dashboard

Select your **zinchat** project

### Step 2: Navigate to Storage
Click **Storage** in the left sidebar

You'll see screen with existing buckets (if any) and a **+ New Bucket** button

### Step 3: Create "messages" Bucket

Click **+ New Bucket**

Fill in the form:
- **Bucket name:** `messages`
- **Public bucket:** Toggle **ON** ✓

Click **Create Bucket**

---

## Done! 🎉

That's it! Now:

1. Hot reload your app (R in terminal)
2. Try recording a voice message again
3. It should upload successfully! ✅

---

## What Happens Now

When you send a voice message:
1. File records locally → `/storage/emulated/0/Documents/voice_*.m4a`
2. Uploads to Supabase → `messages/servers/{serverId}/voice_notes/{userId}/{timestamp}.m4a`
3. Gets public URL → `https://your-bucket-url/...`
4. Saves to database → `server_messages` table
5. Shows in chat → Voice player widget appears
6. Click play → Audio plays! 🎙️

---

## If You Want to Verify

Go back to Storage in Supabase dashboard and you should see:
- `messages` bucket listed
- Inside: `servers/` folder
- Inside that: folders with your server IDs
- Inside those: `voice_notes/` folders
- Inside those: folders with user IDs
- Inside those: `.m4a` files with timestamps

---

**That's all you need to do!** Voice notes will work after creating the bucket. 🚀
