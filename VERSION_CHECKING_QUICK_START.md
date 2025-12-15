# Version Checking - Quick Start (5 Minutes)

## What You Get

✅ Automatic app update checking  
✅ User-friendly update dialogs  
✅ Forced updates for critical releases  
✅ Custom release notes display  
✅ Direct link to app store  

## 3-Step Setup

### Step 1: Create Database Table (2 minutes)

Go to **Supabase Dashboard** → **SQL Editor** → Paste & Run:

```sql
CREATE TABLE IF NOT EXISTS app_versions (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  version TEXT NOT NULL UNIQUE,
  version_order INT NOT NULL,
  release_notes TEXT,
  download_url TEXT,
  force_update BOOLEAN DEFAULT FALSE,
  min_supported_version TEXT,
  platforms TEXT[] DEFAULT ARRAY['android', 'ios'],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX app_versions_version_order_idx ON app_versions(version_order DESC);
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access" ON app_versions FOR SELECT USING (true);
```

### Step 2: Add Your Version (1 minute)

In Supabase Dashboard → **app_versions** table → Click "Insert row":

```
version:              1.0.0
version_order:        1
release_notes:        Initial release
download_url:         https://play.google.com/store/apps/details?id=com.zinchat.app
force_update:         false
min_supported_version: 0.9.0
```

### Step 3: Done! ✅

- ✅ Code already integrated in `lib/main.dart`
- ✅ Version check runs on app startup
- ✅ Update dialog shows automatically
- ✅ Ready for production

## Testing

1. **Change your app version** in `pubspec.yaml`:
   ```yaml
   version: 0.5.0+1  # Set to lower version
   ```

2. **Build and run**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Watch for update dialog** on app startup

4. **Change back to real version** after testing

## Database Fields Explained

| Field | Example | Purpose |
|-------|---------|---------|
| `version` | `1.0.1` | App version (semantic: major.minor.patch) |
| `version_order` | `2` | Higher number = newer version |
| `release_notes` | `"Bug fixes"` | What users see about this update |
| `download_url` | `https://play.google...` | Where users download the app |
| `force_update` | `true/false` | If `true`, users cannot skip this update |
| `min_supported_version` | `1.0.0` | Users below this version can't use app |

## Common Scenarios

### Scenario 1: Release New Version

```
1. Update pubspec.yaml: version: 1.1.0+2
2. Build APK: flutter build apk --release
3. Upload to Google Play
4. Add to database:
   - version: 1.1.0
   - version_order: 2
   - release_notes: "New chat search feature"
```

### Scenario 2: Critical Security Fix

```
1. Fix security issue
2. Update version to 1.0.1
3. Set force_update: true
4. Add to database

Result: ALL users forced to update
```

### Scenario 3: End Support for Old Version

```
1. Update min_supported_version: 1.1.0
2. Users on version 1.0.0 get blocked

Result: Users must update to continue
```

## How It Works

```
User launches app
    ↓
App checks database for latest version
    ↓
Latest version > Current version?
    ↓
YES → Show update dialog
       ├─ force_update = true? → Can't skip
       └─ force_update = false? → "Later" button shown
    ↓
NO → Continue to home screen
```

## Files Created

- ✅ `lib/services/version_check_service.dart` - Core logic
- ✅ `CREATE_VERSION_CHECK_TABLE.sql` - Database schema
- ✅ `VERSION_CHECK_SETUP_GUIDE.md` - Complete guide
- ✅ Main.dart updated - Already integrated

## Next Actions

- [ ] Run SQL in Supabase
- [ ] Add your first version to database
- [ ] Test with lower version in pubspec.yaml
- [ ] Deploy to production
- [ ] Monitor updates in Firebase Analytics

---

**Status**: ✅ Ready to use  
**Time to production**: < 5 minutes
