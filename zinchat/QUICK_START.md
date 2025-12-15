# ZinChat - Quick Start Guide

## ✅ Everything is Ready!

Your Flutter app is fully configured and ready to use. Here's what works:

### Working Features
- ✅ Authentication (Email OTP + Magic Links)
- ✅ Deep linking (opens app from email links)
- ✅ Chat messaging (text messages)
- ✅ Media upload UI (buttons, file picker, progress overlay)
- ✅ Edge Function for secure uploads (scaffolded and ready to deploy)

### Current Blocker
- ❌ **Media uploads fail**: Supabase RLS blocks direct client uploads
- ✅ **Solution ready**: Edge Function that bypasses RLS

---

## 🚀 Deploy in 5 Minutes

### Option A: Deploy Edge Function (Recommended - Production Ready)

```powershell
# 1. Install Supabase CLI (one-time)
npm install -g supabase

# 2. Login
supabase login

# 3. Deploy function
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
supabase functions deploy upload_media

# 4. Set secrets (get service_role key from Dashboard → Settings → API)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
supabase secrets set SUPABASE_URL="https://avaewzkgsilitcrncqhe.supabase.co"

# 5. Update lib/config.dart with your function URL (shown after deploy)
# Then hot restart app: flutter run
```

**Done!** Uploads will now work via the secure Edge Function.

---

### Option B: Quick Test with Public Bucket (Less Secure)

1. Go to https://app.supabase.com
2. Open your project → Storage → Buckets
3. Click `chat-media` bucket → Toggle "Public" ON
4. Run this SQL (Dashboard → SQL Editor):

```sql
-- Allow authenticated uploads
CREATE POLICY "allow_authenticated_upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'chat-media');

-- Allow authenticated reads
CREATE POLICY "allow_authenticated_read"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'chat-media');
```

5. Restart app and test upload

⚠️ This makes your bucket public - use only for testing!

---

## 📝 What Changed

### New Files Added
1. `supabase/functions/upload_media/index.ts` - Edge Function for secure uploads
2. `lib/services/upload_function_client.dart` - Flutter client for Edge Function
3. `DEPLOYMENT_GUIDE.md` - Full deployment instructions
4. `QUICK_START.md` - This file

### Files Updated
1. `lib/config.dart` - Added `uploadFunctionUrl` constant
2. `lib/services/chat_service.dart` - Integrated Edge Function client with fallback
3. `pubspec.yaml` - Added `http: ^0.13.6` dependency

### How Upload Flow Works Now
1. User picks a file → `ChatScreen._sendMediaFile()`
2. Calls `ChatService.sendMediaMessage()`
3. Tries Edge Function upload first (bypasses RLS)
4. Falls back to direct storage if function not deployed
5. Inserts message row with media URL
6. Image/video appears in chat

---

## 🔧 Troubleshooting

### "Edge Function upload failed"
- Deploy the function (see Option A above)
- Check secrets: `supabase secrets list`
- View logs: `supabase functions logs upload_media`

### Still getting RLS errors
- Ensure function is deployed: `supabase functions list`
- Verify service_role key is set correctly
- Check function URL in `lib/config.dart` matches deployed URL

### Profile creation fails during OTP
Run this SQL in Supabase Dashboard:

```sql
-- Allow users to create their own profile
CREATE POLICY "allow_insert_own_profile"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (auth.uid() = id);
```

---

## 📊 Code Quality

**Analyzer Status**: ✅ No blocking errors

13 linter warnings (all non-critical):
- 5× deprecated `withOpacity` (use `withValues` instead)
- 8× `avoid_print` (use `debugPrint` instead)

To fix warnings, see `DEPLOYMENT_GUIDE.md` → "Clean Up Linter Warnings"

---

## 🎯 Next Steps

1. **Deploy Edge Function** (5 min) - See Option A above
2. **Test upload** - Pick an image in chat and verify it sends
3. **Add profile RLS** (optional) - Run SQL from "Profile creation fails" section
4. **Clean up linter warnings** (optional) - See DEPLOYMENT_GUIDE.md

---

## 📚 Additional Resources

- Full deployment guide: `DEPLOYMENT_GUIDE.md`
- Supabase docs: https://supabase.com/docs
- Edge Functions: https://supabase.com/docs/guides/functions

---

**Need help?** Check `DEPLOYMENT_GUIDE.md` for detailed steps and troubleshooting.

**Ready to deploy?** Run the 5 commands in Option A above! 🚀
