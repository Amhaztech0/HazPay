# Version Checking System Setup Guide

## Overview
Version checking system allows you to prompt users to update the app. You can mark updates as required (force update) or optional (remind later).

## Database Setup

### 1. Create `app_versions` Table

Run this SQL in your Supabase SQL editor:

```sql
-- Create app_versions table
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version VARCHAR(20) NOT NULL UNIQUE,
  download_url TEXT NOT NULL,
  release_notes TEXT,
  is_required BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_app_versions_created_at 
  ON app_versions(created_at DESC);

-- Add RLS policy (enable for app_versions table)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public read access
CREATE POLICY "Allow public read access on app_versions"
  ON app_versions
  FOR SELECT
  USING (true);

-- Policy: Only authenticated users can insert (for admin)
CREATE POLICY "Allow authenticated insert on app_versions"
  ON app_versions
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');
```

### 2. Create `version_check_logs` Table (Optional)

For analytics, track version checks:

```sql
CREATE TABLE IF NOT EXISTS version_check_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  current_version VARCHAR(20),
  latest_version VARCHAR(20),
  update_available BOOLEAN,
  checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_version_check_logs_user_id 
  ON version_check_logs(user_id);

-- Add RLS policy
ALTER TABLE version_check_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own logs
CREATE POLICY "Users can view their own version check logs"
  ON version_check_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Allow insert for logged in users
CREATE POLICY "Users can insert their own version check logs"
  ON version_check_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

### 3. Add Sample Version Data

Insert current and future versions:

```sql
-- Current version (1.0.0)
INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.0',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Initial release
• Core messaging features
• Server/channel support
• Voice and video calls',
  false
)
ON CONFLICT (version) DO NOTHING;

-- Next version (1.0.1) - Optional update
INSERT INTO app_versions (version, download_url, release_notes, is_required)
VALUES (
  '1.0.1',
  'https://play.google.com/store/apps/details?id=com.zinchat.app',
  '• Bug fixes
• Performance improvements
• UI refinements',
  false
)
ON CONFLICT (version) DO NOTHING;

-- Future version (1.1.0) - Critical update (example)
-- INSERT INTO app_versions (version, download_url, release_notes, is_required)
-- VALUES (
--   '1.1.0',
--   'https://play.google.com/store/apps/details?id=com.zinchat.app',
--   '• Security patches
--   • Critical bug fixes',
--   true
-- );
```

---

## How It Works

### 1. Version Checking Flow

```
App Launches
    ↓
User Logs In
    ↓
AuthChecker._checkVersionAndProceed()
    ↓
VersionService.checkForUpdate()
    ↓
Fetch latest from app_versions table
    ↓
Compare versions
    ↓
If update available:
  → Show VersionUpdateDialog
  → If required: Block until updated
  → If optional: Allow "Later" button
    ↓
User taps "Update" → Open app store
    ↓
Proceed to HomeScreen
```

### 2. Version Comparison Logic

```
Compare semantic versions (e.g., 1.0.5 vs 1.0.6)
Split by dots: [1, 0, 5] vs [1, 0, 6]
Compare each number sequentially
Update available if current < latest
```

### 3. Dialog Display

**Required Update (is_required = true)**:
- Shows warning icon
- "Critical Update Required" title
- Can't dismiss - forces update
- Shows warning message

**Optional Update (is_required = false)**:
- Shows info icon
- "Update Available" title
- "Later" button available
- User can proceed to app

---

## Usage

### For Users

1. **Update Available Notification**:
   - When app launches and update exists, dialog appears
   - Shows version number and release notes
   - Option to update or dismiss (if optional)

2. **Updating**:
   - Tap "Update" button
   - Opens app store
   - Download and install new version

### For Admins

1. **Release New Version**:
   ```sql
   INSERT INTO app_versions (version, download_url, release_notes, is_required)
   VALUES ('1.0.2', 'https://...', 'Fix crashes', false);
   ```

2. **Mark As Required**:
   ```sql
   UPDATE app_versions SET is_required = true WHERE version = '1.0.2';
   ```

3. **View Update History**:
   ```sql
   SELECT * FROM app_versions ORDER BY created_at DESC;
   ```

4. **View Version Check Logs** (Analytics):
   ```sql
   SELECT 
     current_version,
     latest_version,
     COUNT(*) as check_count
   FROM version_check_logs
   GROUP BY current_version, latest_version
   ORDER BY check_count DESC;
   ```

---

## Configuration

### Update Check Timing

Currently checks on app launch. To change:

**Edit `lib/main.dart`** in `_checkVersionAndProceed()`:

```dart
// Add timeout
final versionInfo = await versionService.checkForUpdate().timeout(
  const Duration(seconds: 5),
  onTimeout: () => null,
);
```

### Download URLs

**For Android**:
```
https://play.google.com/store/apps/details?id=com.zinchat.app
```

**For iOS**:
```
https://apps.apple.com/app/zinchat/id1234567890
```

**For Web**:
```
https://your-website.com/download
```

---

## Error Handling

If version check fails:
- Dialog doesn't show
- User proceeds to app normally
- Error logged to DebugLogger
- No disruption to user

### Debug Logging

Enable debug logs to see version checks:

```dart
// In version_service.dart
DebugLogger.info('Version check completed...', tag: 'VERSION_SERVICE');
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Update dialog doesn't show | Check `app_versions` table has data with later version |
| Version comparison wrong | Ensure semantic versioning (X.Y.Z format) |
| Can't update (optional) | Make sure download_url is valid |
| Forced update not working | Set `is_required = true` for version |
| Dialog appears but can't dismiss | Check if update is marked as required |

---

## Testing

### Test Optional Update

1. Update version in `pubspec.yaml`: `1.0.0` → `1.0.1`
2. Add to database:
   ```sql
   INSERT INTO app_versions (version, download_url, release_notes)
   VALUES ('1.0.2', 'https://...', 'Test update');
   ```
3. Run app - dialog should appear with "Later" button

### Test Required Update

1. Add to database:
   ```sql
   INSERT INTO app_versions (version, download_url, release_notes, is_required)
   VALUES ('1.0.2', 'https://...', 'Critical fix', true);
   ```
2. Run app - dialog should appear without "Later" button

---

## Best Practices

✅ **Do**:
- Use semantic versioning (X.Y.Z)
- Test version comparisons before release
- Provide clear release notes
- Use required updates only for critical issues
- Monitor update adoption with logs

❌ **Don't**:
- Force updates too frequently
- Have confusing version numbers
- Leave download_url blank
- Make optional updates that seem required

---

## Future Enhancements

- [ ] Server-side version forcing (per user)
- [ ] Scheduled rollouts (gradually)
- [ ] A/B testing different versions
- [ ] Canary releases to beta users
- [ ] Rollback mechanism if bugs found
- [ ] User feedback on update reasons

---

**Setup Complete!** 🎉

Your app now checks for updates on launch and prompts users appropriately.
