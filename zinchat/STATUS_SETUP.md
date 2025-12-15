# Status Feature Setup Guide

The status feature requires database tables to be created in your Supabase project. Follow these steps:

## Option 1: Using Supabase Web Console (Easiest)

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy the entire contents of `/supabase/migrations/20250108_create_status_tables.sql`
5. Paste it into the SQL editor
6. Click **Run** (the play button)
7. You should see success messages for all table creations

## Option 2: Using Supabase CLI

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Navigate to your project directory
cd path/to/zinchat

# Login to Supabase
supabase login

# Link your project
supabase link --project-id your-project-id

# Apply migrations
supabase db push
```

## What Gets Created

The migration creates:

### Tables:
- **status_updates**: Stores text, image, and video statuses with expiration
- **status_views**: Tracks who viewed which status (for read receipts)

### Indexes:
- Performance indexes on frequently queried columns

### Storage:
- **status-media** bucket for storing status images and videos

### Row-Level Security (RLS):
- Anyone can view active (non-expired) statuses
- Users can only create/delete their own statuses
- Authenticated users can upload to status-media bucket

## After Setup

Once the migration is complete:
1. Return to your Flutter app
2. Tap the **+** button on the home screen to create a status
3. Choose between text, photo, or video status
4. Post your status - it will disappear after 24 hours
5. View other users' statuses from the status bar at the top

## Troubleshooting

### "Table already exists" error
This is normal if you've run the migration before. The migration uses `IF NOT EXISTS` to avoid conflicts.

### "Relation status_updates does not exist" in the app
Make sure you ran the migration successfully in the Supabase console.

### Statuses not showing up
1. Check that you have other users with active statuses
2. Verify the statuses haven't expired (they last 24 hours)
3. Check browser console/app logs for errors

### Upload fails with "403 Forbidden"
This means RLS is blocking the upload. Run the migration again to ensure the policies are created.
