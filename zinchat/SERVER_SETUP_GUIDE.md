# Server Setup Guide for ZinChat

This guide will help you set up the server features in your ZinChat app.

## 1. Database Setup

### Run the SQL Migration

1. Open your Supabase project dashboard
2. Go to **SQL Editor** (in the left sidebar)
3. Open the file `SUPABASE_SERVERS_SETUP.sql` from your project
4. Copy all the SQL code and paste it into the SQL Editor
5. Click **Run** to execute the migration

This will create:
- Tables: `servers`, `server_members`, `server_messages`, `server_invites`
- Indexes for better query performance
- Row Level Security (RLS) policies
- Helper functions (invite code generation, admin checks, etc.)
- Triggers for auto-updating timestamps and member counts

## 2. Storage Setup

### Create the Storage Bucket for Server Media

1. In your Supabase dashboard, go to **Storage** (in the left sidebar)
2. Click **New bucket**
3. Enter the bucket name: `server-media`
4. **IMPORTANT:** Check "Public bucket" if you want images accessible without authentication
   - OR leave it private and use signed URLs (requires code modification)
5. Click **Create bucket**

### Configure Storage Policies (if using public bucket)

If you created a public bucket, the images will be accessible via public URLs automatically.

If you want more control, you can add custom policies:

1. Click on the `server-media` bucket
2. Go to **Policies** tab
3. Add a policy for SELECT (viewing files):
   ```sql
   CREATE POLICY "Allow authenticated users to view server media"
   ON storage.objects FOR SELECT
   TO authenticated
   USING (bucket_id = 'server-media');
   ```

4. Add a policy for INSERT (uploading files):
   ```sql
   CREATE POLICY "Allow authenticated users to upload server media"
   ON storage.objects FOR INSERT
   TO authenticated
   WITH CHECK (
     bucket_id = 'server-media' AND
     auth.role() = 'authenticated'
   );
   ```

5. Add a policy for DELETE (removing files - admin only):
   ```sql
   CREATE POLICY "Allow server members to delete their uploads"
   ON storage.objects FOR DELETE
   TO authenticated
   USING (
     bucket_id = 'server-media' AND
     auth.uid()::text = (storage.foldername(name))[1]
   );
   ```

## 3. Test the Features

### Testing Image Upload
1. Run the app on your device/emulator
2. Create a server or join an existing one
3. Open the server chat
4. Click the image icon in the input area
5. Select an image from your gallery
6. The image should upload and appear in the chat

If it fails:
- Check the console logs for error messages
- Verify the `server-media` bucket exists
- Ensure you're authenticated

### Testing Member Management
1. As a server owner/admin, open a server
2. Click **View Members** button
3. You should see a list of all server members with role badges
4. Long-press a member (who is not the owner or yourself) to remove them
5. Confirm the removal

### Testing Message Deletion
1. Send a message in server chat
2. Long-press your own message
3. Confirm deletion
4. As an admin/owner, you can also delete other users' messages

## 4. Troubleshooting

### "Failed to upload" error when sending images
- **Check:** Does the `server-media` bucket exist in Supabase Storage?
- **Check:** Is the bucket public, or do you have the right policies?
- **Check:** Are you authenticated (logged in)?
- **Solution:** Create the bucket as described in step 2 above

### "Cannot remove member" error
- **Check:** Are you an admin or owner of the server?
- **Check:** Are you trying to remove the owner (not allowed)?
- **Check:** Did you run the SQL migration with the `is_server_admin()` function?

### Messages not appearing in real-time
- **Check:** Is Supabase Realtime enabled for the `server_messages` table?
- **Solution:** Go to Database > Replication in Supabase and enable it for `server_messages`

### RLS Policy errors
- **Check:** Did you run the complete SQL migration?
- **Check:** Are there any conflicting policies?
- **Solution:** Re-run the SQL migration (it's idempotent - safe to run multiple times)

## 5. Security Recommendations

Before going to production:

1. **Review RLS Policies:** Some policies use `SELECT true` for simplicity. Tighten these based on your requirements.

2. **Storage Security:** Consider using signed URLs instead of public bucket for better control:
   - Modify `uploadServerFile()` in `server_service.dart`
   - Use `supabase.storage.from('server-media').createSignedUrl(path, 3600)`

3. **Rate Limiting:** Add rate limits for:
   - Message sending (prevent spam)
   - Invite code generation
   - Member removal

4. **Audit Logging:** Track admin actions (member removals, message deletions) in a separate `audit_logs` table

5. **File Upload Limits:**
   - Add file size checks in `uploadServerFile()`
   - Validate file types (images only, etc.)
   - Set storage quotas per server

## 6. Next Steps

Consider implementing:
- **Channels:** Organize servers into multiple channels/topics
- **Roles & Permissions:** More granular role system (moderator, etc.)
- **Message Reactions:** Allow users to react to messages with emojis
- **File/Video Support:** Extend beyond images to other media types
- **Search:** Search messages within a server
- **Notifications:** Push notifications for new messages
- **Server Settings:** Customize server appearance, rules, etc.

---

Need help? Check the Supabase documentation at https://supabase.com/docs
