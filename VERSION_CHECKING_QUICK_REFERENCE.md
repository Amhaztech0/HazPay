# Version Checking - Quick Reference

## What It Does ✅

Users get prompted to update when a new version is available:
- **Optional updates**: "Later" button available (user can skip)
- **Required updates**: No skip option (user must update)
- **Automatic**: Checks on every app launch

---

## Quick Setup (5 minutes)

### Step 1: Run SQL Schema
Copy this entire block and run in Supabase SQL editor:

```sql
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version VARCHAR(20) NOT NULL UNIQUE,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  is_required BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access on app_versions"
  ON app_versions FOR SELECT USING (true);

INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.0',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Initial release',
  false
) ON CONFLICT (version) DO NOTHING;
```

### Step 2: That's It! 🎉

The app automatically checks on launch.

---

## How to Release an Update

### Add New Version (Optional Update)

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.1',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Bug fixes
• Performance improvements',
  false
);
```

### Add New Version (Required Update - Security/Critical)

```sql
INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.2',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Security patches
• Critical bug fix',
  true
);
```

**Important**: User can't skip required updates!

---

## What Users See

### Optional Update:
```
┌──────────────────────────────────────┐
│  Update Available                    │
│  Version 1.0.1 is now available      │
│  (currently using 1.0.0)             │
│                                      │
│  What's New:                         │
│  • Bug fixes                         │
│  • Performance improvements          │
│                                      │
│  [Later]            [Update ↓]      │
└──────────────────────────────────────┘
```

### Required Update:
```
┌──────────────────────────────────────┐
│  Critical Update Required            │
│  Version 1.0.2 is now available      │
│  (currently using 1.0.0)             │
│                                      │
│  What's New:                         │
│  • Security patches                  │
│  ⚠️ This is a critical update       │
│                                      │
│              [Update ↓]             │
└──────────────────────────────────────┘
```

---

## Files Created/Modified

| File | Type | Purpose |
|------|------|---------|
| `lib/services/version_service.dart` | NEW | Version checking logic |
| `lib/widgets/version_update_dialog.dart` | NEW | Update dialog UI |
| `lib/main.dart` | MODIFIED | Integrated version check |
| `pubspec.yaml` | MODIFIED | Added dependencies |
| `db/VERSION_CONTROL_SCHEMA.sql` | NEW | Database schema |

---

## Technical Details

### Version Comparison
- Compares semantic versions (X.Y.Z)
- Example: 1.0.5 < 1.0.6 ✓
- Example: 1.0.5 = 1.0.5 (no update)
- Example: 1.0.5 > 1.0.4 (no update)

### Download URLs

**Android**:
```
https://play.google.com/store/apps/details?id=com.zinchat.app
```

**iOS**:
```
https://apps.apple.com/app/zinchat/id1234567890
```

---

## Common Tasks

### Check Users on Old Version

```sql
SELECT current_version, COUNT(*) as user_count
FROM version_check_logs
GROUP BY current_version
ORDER BY user_count DESC;
```

### See All Versions

```sql
SELECT version, is_required, created_at
FROM app_versions
ORDER BY created_at DESC;
```

### Mark Version as Required

```sql
UPDATE app_versions 
SET is_required = true 
WHERE version = '1.0.2';
```

---

## Troubleshooting

**Q: Update dialog not showing?**
A: Check that your DB version > app version
```sql
SELECT version FROM app_versions ORDER BY created_at DESC LIMIT 1;
```

**Q: User can't dismiss optional update?**
A: Check `is_required = false` in database

**Q: Download link doesn't work?**
A: Verify URL works in browser first

**Q: Version format wrong?**
A: Use X.Y.Z format (e.g., 1.0.0)

---

## Version Control Best Practices

✅ **Do**:
- Use semantic versioning (X.Y.Z)
- Write clear release notes
- Test version comparisons
- Use required updates for security
- Monitor update adoption

❌ **Don't**:
- Force updates too often
- Use confusing version numbers
- Leave download_url blank
- Make ALL updates required

---

## One More Thing...

**To update app version for next release**:

1. Update `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Change from 1.0.0+1
   ```

2. Add to database (as shown above)

3. Build and submit to stores

4. Users will see update prompt on next launch

---

## Dashboard

Get version stats:
```sql
SELECT 
  current_version,
  COUNT(*) as users,
  ROUND(100.0 * COUNT(*) / 
    (SELECT COUNT(*) FROM version_check_logs), 1) as percent
FROM version_check_logs
WHERE checked_at > NOW() - INTERVAL '7 days'
GROUP BY current_version
ORDER BY users DESC;
```

---

## Support Docs

- **Full Setup**: `VERSION_CHECKING_SETUP.md`
- **Complete Guide**: `VERSION_CHECKING_COMPLETE.md`
- **SQL Schema**: `db/VERSION_CONTROL_SCHEMA.sql`

---

**Status**: ✅ Ready to Use

Everything is implemented and working!
