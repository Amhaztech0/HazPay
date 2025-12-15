# ✅ QUICK SETUP - 3 Buckets + 1 SQL

## Step 1: Create Storage Buckets (2 minutes)

Go to: **https://supabase.com/dashboard** → Your Project → **Storage**

### Create these 3 buckets (click "New bucket" for each):

1. **Bucket: `profile-photos`**
   - ✅ Check "Public bucket"
   - Click "Create bucket"

2. **Bucket: `status-media`**
   - ✅ Check "Public bucket"
   - Click "Create bucket"

3. **Bucket: `server-media`** (if you haven't already)
   - ✅ Check "Public bucket"
   - Click "Create bucket"

---

## Step 2: Run SQL Scripts (2 minutes)

Go to: **Supabase Dashboard** → **SQL Editor**

### A. Storage Policies (IMPORTANT - fixes 403 errors):
1. Open file: `STORAGE_POLICIES.sql`
2. Copy all the SQL
3. Paste into SQL Editor
4. Click **Run** (or press Ctrl+Enter)
5. Should see: "Success" or "policy already exists" (both OK)

### B. Online Status:
1. Open file: `ADD_ONLINE_STATUS.sql`
2. Copy all the SQL
3. Paste into SQL Editor
4. Click **Run** (or press Ctrl+Enter)
5. Should see: "Success. No rows returned"

---

## Step 3: Run Your App

```powershell
cd C:\Users\Amhaz\Desktop\zinchat\zinchat
flutter run -d 2A201FDH3005XZ
```

---

## ✅ Test Everything

### A. Profile Picture:
- Profile tab → Tap picture → Select image → Should upload! ✓

### B. Status Caption:
- Status tab → + button → Gallery → Pick image → **Caption screen appears** → Add text → Post ✓

### C. Online Status:
- Open chat with someone → See "online" (green) or "last seen X ago" (gray) ✓

---

## 🚨 If Something Fails:

### Profile picture won't upload:
→ Create `profile-photos` bucket in Supabase Storage

### Status upload fails:
→ Create `status-media` bucket in Supabase Storage

### Everyone shows offline:
→ Run `ADD_ONLINE_STATUS.sql` in SQL Editor

### Server images fail:
→ Create `server-media` bucket in Supabase Storage

---

**Total time: ~3 minutes** ⏱️

All buckets must be marked as **Public** ✅
