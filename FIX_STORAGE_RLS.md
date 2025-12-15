# 🔐 Fix Storage RLS Policies

## Problem
```
StorageException(message: new row violates row-level security policy, statusCode: 403)
```

The bucket exists but doesn't have the right permissions set.

---

## Solution: Add RLS Policies

Go to your Supabase SQL Editor and run this:

```sql
-- First, drop existing policies (if any)
DROP POLICY IF EXISTS "Users can upload to messages bucket" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read messages bucket" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own messages" ON storage.objects;

-- Allow authenticated users to upload
CREATE POLICY "Users can upload to messages bucket"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'messages' AND
    auth.role() = 'authenticated'
  );

-- Allow anyone to read (public access for voice messages)
CREATE POLICY "Anyone can read messages bucket"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'messages');

-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their own messages"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'messages' AND
    auth.uid() = owner
  );

-- Update policy (optional, for future edits)
CREATE POLICY "Users can update their own messages"
  ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'messages' AND
    auth.uid() = owner
  );
```

---

## Steps

1. Go to https://supabase.com/dashboard
2. Select your **zinchat** project
3. Click **SQL Editor** (left sidebar)
4. Click **+ New Query**
5. **Paste the SQL above**
6. Click **Run**
7. Wait for success message

---

## Then Test

1. **Hot reload** your app (`R` in terminal)
2. Try recording a voice message again
3. Should upload successfully now! ✅

---

## What These Policies Do

| Policy | What It Allows |
|--------|---|
| **Upload** | Authenticated users can upload files to `messages` bucket |
| **Read** | Anyone can read/download from `messages` bucket (public URLs) |
| **Delete** | Users can only delete files they uploaded themselves |
| **Update** | Users can only update files they uploaded themselves |

---

Done! Run the SQL and voice notes will work! 🚀
