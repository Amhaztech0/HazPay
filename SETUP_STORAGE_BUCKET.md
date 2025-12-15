# 🪣 Supabase Storage Setup - Voice Notes Bucket

## Problem
The voice notes upload is failing because the `messages` bucket doesn't exist in your Supabase Storage.

## Solution: Create the Bucket

### Option 1: Using Supabase Dashboard (Recommended)

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to **Storage** (left sidebar)
4. Click **+ New Bucket**
5. **Bucket name:** `messages`
6. **Public bucket:** Toggle **ON** (so voice messages are publicly accessible)
7. Click **Create Bucket**

### Option 2: Using SQL

Run this in your Supabase SQL Editor:

```sql
-- Create the messages bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('messages', 'messages', true);

-- Allow authenticated users to upload
CREATE POLICY "Users can upload to messages bucket"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'messages' AND
    auth.role() = 'authenticated'
  );

-- Allow anyone to read (public access)
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
```

---

## Steps to Fix

### Step 1: Create the Bucket
Choose Option 1 (Dashboard) or Option 2 (SQL) above and create the bucket.

### Step 2: Test the App
1. Run `flutter run` again
2. Try recording a voice message
3. Should upload successfully now ✅

### Step 3: Verify
Check that:
- Voice file uploads to `messages/servers/{serverId}/voice_notes/{userId}/{timestamp}.m4a`
- Message appears in chat with voice player
- Can click play and hear audio

---

## Bucket Structure

After setup, your voice notes will be stored as:
```
messages/
├── servers/
│   ├── {serverId}/
│   │   └── voice_notes/
│   │       └── {userId}/
│   │           ├── 1700000000000.m4a
│   │           ├── 1700000010000.m4a
│   │           └── ...
```

---

## RLS Policies Explained

### Upload Policy
Users can only upload to the `messages` bucket and must be authenticated.

### Read Policy
Anyone can read from the bucket (so voice messages are accessible via public URL).

### Delete Policy
Users can only delete files they uploaded (optional, but good for security).

---

## Testing

After creating the bucket:

```bash
flutter run
```

1. Open server chat
2. Click microphone icon
3. Record a voice message
4. Click send
5. Wait for upload
6. Voice message should appear in chat
7. Click play button to hear audio

---

## Troubleshooting

**Still getting "Bucket not found"?**
- Refresh the app (hot reload might cache the error)
- Verify bucket name is exactly `messages` (case-sensitive)
- Check bucket is set to public

**"Permission denied" error?**
- Check RLS policies are set correctly
- User must be authenticated
- Verify `auth.role() = 'authenticated'` in policy

**File uploads but can't play?**
- Check URL is public (bucket must be public)
- Try opening URL in browser directly
- Check file actually exists in bucket

---

Done! Once you create the bucket, voice notes will work perfectly! 🎉
