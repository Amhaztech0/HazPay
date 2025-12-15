# ZinChat Media Upload Deployment Guide

## Current Status ✅

### What's Working
- ✅ Flutter app compiles and runs (dependencies installed)
- ✅ Auth flow (email OTP, magic links, deep linking)
- ✅ Chat UI with media upload buttons and progress overlay
- ✅ Text messaging works
- ✅ `ChatService.sendMediaMessage()` implemented
- ✅ `StorageService.uploadFile()` implemented (currently blocked by RLS)
- ✅ Edge Function scaffolded: `supabase/functions/upload_media/index.ts`
- ✅ Flutter upload client ready: `lib/services/upload_function_client.dart`

### What's Blocked
- ❌ **Direct storage uploads fail with RLS error**: "new row violates row-level security policy" (403)
- ❌ **Profile creation during OTP verify also fails with RLS** (42501)

### Analyzer Results
- 13 linter warnings (non-blocking):
  - 5× deprecated `withOpacity()` → should use `withValues()` (Flutter 3.9+)
  - 8× `avoid_print` warnings → use `debugPrint()` or logger
- No compile errors in Dart/Flutter code
- TypeScript errors in Edge Function are expected (Deno types not available in VS Code)

---

## Solution: Deploy Edge Function for Media Upload

The Edge Function bypasses client RLS by using the `service_role` key server-side.

### Step 1: Install Supabase CLI

```powershell
# Install via npm (requires Node.js)
npm install -g supabase

# Or use Scoop (Windows package manager)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Step 2: Login to Supabase CLI

```powershell
supabase login
```

This opens a browser to authenticate.

### Step 3: Link Your Project

```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
supabase link --project-ref avaewzkgsilitcrncqhe
```

Replace `avaewzkgsilitcrncqhe` with your actual project ref (visible in Supabase dashboard URL).

### Step 4: Deploy the Edge Function

```powershell
supabase functions deploy upload_media
```

This uploads `supabase/functions/upload_media/index.ts` to your Supabase project.

After deployment, you'll get a function URL like:
```
https://avaewzkgsilitcrncqhe.functions.supabase.co/upload_media
```

### Step 5: Set Function Secrets

The function needs two environment variables:

```powershell
# Set service role key (get from Supabase Dashboard → Settings → API → service_role key)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey..."

# Set Supabase URL
supabase secrets set SUPABASE_URL="https://avaewzkgsilitcrncqhe.supabase.co"
```

⚠️ **IMPORTANT**: Keep the `service_role` key secret. Never commit it to Git or expose it in client code.

### Step 6: Update Flutter App to Use Edge Function

Add this to `lib/config.dart`:

```dart
class AppConfig {
  // ... existing config ...
  
  // Edge Function endpoint for media upload
  static const String uploadFunctionUrl = 'https://avaewzkgsilitcrncqhe.functions.supabase.co/upload_media';
}
```

Then update `lib/services/chat_service.dart` to use the function instead of direct storage:

```dart
import '../config.dart';
import 'upload_function_client.dart';

class ChatService {
  // Add this as a class field
  static final _uploadClient = UploadFunctionClient(Uri.parse(AppConfig.uploadFunctionUrl));

  // Inside sendMediaMessage(), replace the StorageService upload with:
  final mediaUrl = await _uploadClient.uploadFile(
    file,
    bucket: bucket,
    path: fileName,
  );
  // Remove the "if (mediaUrl == null)" check since _uploadClient throws on error
```

### Step 7: Test Upload

1. Hot restart the app (or rebuild):
   ```powershell
   flutter run
   ```

2. Navigate to a chat and try uploading an image

3. Check logs for success or error messages

Expected outcome:
- File uploads to `chat-media` bucket via Edge Function
- Message appears in chat with image preview
- No RLS errors

---

## Alternative: Quick Test with Public Bucket (Less Secure)

If you want to test immediately without deploying the function:

1. Go to Supabase Dashboard → Storage → Buckets
2. Click `chat-media` bucket
3. Toggle "Public bucket" ON
4. Save

⚠️ This makes all files publicly readable but **does NOT fix upload RLS errors**. You'll still get 403 on uploads unless you also add an RLS policy (see below).

---

## Alternative: Add RLS Policy (Requires DB Owner Access)

If you have owner/service_role access to run SQL:

```sql
-- Allow authenticated users to insert their own objects into chat-media
CREATE POLICY "allow_authenticated_insert_chat_media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat-media' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to read chat-media objects
CREATE POLICY "allow_authenticated_read_chat_media"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'chat-media');
```

If you get "must be owner of table objects" error, you'll need to run this as the Postgres owner or use the Edge Function approach.

---

## Fix RLS for Profile Creation

The profile insert during OTP verification also fails. Add this policy:

```sql
-- Allow authenticated users to insert their own profile
CREATE POLICY "allow_insert_own_profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Allow users to read all profiles (needed for chat partner display)
CREATE POLICY "allow_read_all_profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Allow users to update their own profile
CREATE POLICY "allow_update_own_profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
```

---

## Clean Up Linter Warnings (Optional)

### Fix deprecated `withOpacity` warnings

Replace all instances of `.withOpacity(0.2)` with:

```dart
// Old (deprecated):
Colors.white.withOpacity(0.2)

// New:
Colors.white.withValues(alpha: 0.2)
```

Files to update:
- `lib/main.dart:130`
- `lib/screens/auth/login_screen.dart:149`
- `lib/screens/chat/chat_screen.dart:166, 387, 426`

### Fix `avoid_print` warnings

Replace `print()` with `debugPrint()` or use a logger package:

```dart
// Old:
print('Error uploading file: $e');

// New:
debugPrint('Error uploading file: $e');
```

Files to update:
- `lib/services/chat_service.dart` (lines 68, 218, 244)
- `lib/services/storage_service.dart` (lines 25, 43, 60, 89, 103)

---

## Summary

**Recommended Path**: Deploy the Edge Function (Steps 1-7 above). This is the most secure and production-ready solution.

**Quick Test Path**: Toggle bucket to public + add RLS policies (if you have owner access).

**After deployment**:
- Media uploads will work via the Edge Function
- Profile creation will work if RLS policies are added
- No client-side RLS errors

---

## Troubleshooting

### Function deployment fails
- Ensure you're logged in: `supabase login`
- Check project ref: `supabase projects list`
- Verify you have the correct permissions for the project

### Upload still fails with 403
- Check function logs: `supabase functions logs upload_media`
- Verify secrets are set: `supabase secrets list`
- Ensure service_role key is correct (copy from Dashboard → Settings → API)

### TypeScript errors in VS Code
- These are expected for Deno functions
- The function will work correctly when deployed
- VS Code doesn't have Deno type definitions by default

---

## Next Steps

1. Deploy Edge Function (recommended)
2. Test media upload in app
3. Add profile RLS policies in Supabase SQL editor
4. (Optional) Clean up linter warnings
5. (Optional) Add file validation in Edge Function (size limits, mime types)

---

Generated: 2025-11-08
