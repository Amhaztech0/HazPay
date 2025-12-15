# Quick Setup Instructions for ZinChat Server Features

## Step 1: Run SQL Migration

1. Open your **Supabase Dashboard**: https://supabase.com/dashboard
2. Navigate to your project
3. Click **SQL Editor** in the left sidebar
4. Copy and paste the entire content of `SUPABASE_SERVERS_SETUP.sql`
5. Click **Run** or press `Ctrl+Enter`

You should see: "Success. No rows returned"

## Step 2: Create Storage Bucket

### Option A: Via Supabase Dashboard (Recommended)

1. In your Supabase Dashboard, click **Storage** in the left sidebar
2. Click **New bucket** button
3. Enter bucket name: `server-media`
4. ✅ Check **"Public bucket"** (allows public URLs without authentication)
5. Click **Create bucket**

### Option B: Via SQL (if you prefer)

Run this SQL in the SQL Editor:

```sql
-- Create storage bucket for server media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'server-media',
  'server-media',
  true,  -- Public bucket
  10485760,  -- 10MB limit per file
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4']
)
ON CONFLICT (id) DO NOTHING;
```

### Step 3: Configure Storage Policies

If you want finer control over who can upload/view/delete, run these policies:

```sql
-- Allow authenticated users to upload to server-media
CREATE POLICY "Authenticated users can upload server media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'server-media' AND
  auth.role() = 'authenticated'
);

-- Allow public viewing of server media (since bucket is public)
CREATE POLICY "Public can view server media"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'server-media');

-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their uploads"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'server-media' AND
  auth.uid()::text = (storage.foldername(name))[1]
);
```

## Step 4: Enable Realtime for Messages

To see messages update in real-time without refreshing:

1. Go to **Database** → **Replication** in Supabase Dashboard
2. Find the `server_messages` table
3. Toggle **Enable** next to it
4. Do the same for `server_members` and `servers` tables

## Step 5: Test Your App

Run your Flutter app:

```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
flutter run -d 2A201FDH3005XZ
```

### Test Checklist:

1. **Create a Server**
   - Open Servers tab
   - Tap "+" button
   - Create a private or public server

2. **Invite Users** (for private servers)
   - Open server details
   - Tap "Manage Invites"
   - Generate invite code
   - Share with friends

3. **Send Messages**
   - Open server chat
   - Send a text message
   - Tap the image icon
   - Select an image from gallery
   - Image should upload and appear in chat

4. **View Members**
   - Open server details
   - Tap "View Members"
   - See all server members with role badges

5. **Admin Actions**
   - As owner/admin, long-press a message to delete it
   - In Members screen, tap remove button to kick a member

6. **Change Theme**
   - Go to Profile tab
   - Scroll to "Theme Selection"
   - Try the new "Light Blue" theme
   - App should switch to white background with blue accents

## Troubleshooting

### "Failed to upload image"

**Problem**: Storage bucket doesn't exist or isn't configured properly

**Solution**:
1. Check if `server-media` bucket exists in Storage dashboard
2. Make sure it's set as **Public**
3. Check the console logs in your IDE/terminal for detailed error messages

### "Server not found" or "Failed to load servers"

**Problem**: SQL migration not run or RLS policies blocking access

**Solution**:
1. Re-run the SQL migration (it's safe to run multiple times)
2. Check that you're logged in (authenticated)
3. Check browser console or app logs for specific PostgreSQL errors

### Images not displaying

**Problem**: Incorrect URL or bucket not public

**Solution**:
1. Check if bucket is marked as **Public** in Supabase Storage
2. Try accessing the image URL directly in a browser
3. If 404, the file wasn't uploaded correctly

### Can't remove members

**Problem**: Not admin/owner or SQL function missing

**Solution**:
1. Make sure you're the server owner or admin
2. Re-run the SQL migration to ensure `is_server_admin()` function exists
3. Check console for specific error messages

### Messages not appearing in real-time

**Problem**: Realtime not enabled for the table

**Solution**:
1. Go to Database → Replication in Supabase
2. Enable Realtime for `server_messages`, `servers`, and `server_members`

## Next Steps

Once everything is working:

1. **Secure Your Storage**: Consider using signed URLs instead of public bucket for production
2. **Add Rate Limiting**: Prevent spam by limiting message frequency
3. **Implement Channels**: Organize servers into topic-specific channels
4. **Add Push Notifications**: Notify users of new messages even when app is closed
5. **Message Reactions**: Let users react to messages with emojis
6. **Search**: Add search functionality within server messages

## Need Help?

- Check the main `SERVER_SETUP_GUIDE.md` for detailed documentation
- Review Supabase docs: https://supabase.com/docs
- Check Flutter logs: `flutter logs` while app is running
- Check Supabase logs: Dashboard → Logs section

---

**Important Security Note**: Before going to production, review and tighten the RLS policies. Some policies use `SELECT true` for simplicity during development.
