# 🚀 Search Method-Based Direct Messages Implementation

## Overview
This feature allows users to search for other users in two ways:
1. **By Email** → Direct messages (no approval needed)
2. **By Full Name** → Message requests (approval required, like Discord/Instagram)

---

## What You Get

✅ **Email Search** = Instant Direct Messaging
- User searches by email: `john@example.com`
- Message sends immediately, no approval needed
- Recipient gets notification instantly
- Open communication model (like Telegram)

✅ **Name Search** = Message Requests  
- User searches by name: `John Smith`
- Message goes to "Pending" status
- Recipient must accept before conversation continues
- Privacy-first model (like Instagram DMs)

---

## Implementation Steps

### Step 1: Run Database Migration (5 minutes)

1. **Go to Supabase Dashboard** → SQL Editor
2. **Open this file**: `MESSAGE_REQUESTS_BY_SEARCH_METHOD.sql`
3. **Copy ALL content** (Ctrl+A, Ctrl+C)
4. **Paste into Supabase** SQL Editor
5. **Click RUN**

**What it creates:**
- `search_method` column in messages table ('email' or 'name')
- `is_request` column (true for name searches, false for email searches)
- Helper function `can_see_messages()` for permission checks
- Optimized indices for filtering

---

### Step 2: Updated Flutter Code (Already Done! ✅)

The following files have been created/modified:

#### **1. `lib/services/chat_service.dart`** (Modified)
**Changes:**
- Updated `sendMessage()` to accept `searchMethod` parameter
- Added `_sendMessageRequestNotification()` for pending message notifications
- Added helper methods:
  - `searchByEmail()` - Search users by email
  - `searchByName()` - Search users by name
  - `isMessageRequest()` - Check if message is pending
  - `getMessageSearchMethod()` - Get search method for message

**Key Code:**
```dart
// Email search: direct message (no approval)
await _chatService.sendMessage(
  chatId: chatId,
  content: 'Hello!',
  searchMethod: 'email',  // ← Direct message
);

// Name search: message request (pending approval)
await _chatService.sendMessage(
  chatId: chatId,
  content: 'Hi there!',
  searchMethod: 'name',  // ← Message request
);
```

#### **2. `lib/screens/chat/chat_screen.dart`** (Modified)
**Changes:**
- Added `searchMethod` parameter to ChatScreen constructor
- Updated `_sendMessage()` to pass search method to service
- Added user feedback based on search method

**Usage:**
```dart
ChatScreen(
  chatId: chat.id,
  otherUser: user,
  searchMethod: 'email',  // or 'name'
)
```

#### **3. `lib/screens/chat/advanced_user_search_screen.dart`** (New)
**Features:**
- Toggle between "Search by Email" and "Search by Name"
- Visual indicators for current search mode
- Shows why each method behaves differently
- Navigates to ChatScreen with correct search method

---

### Step 3: Add Search Button to Home Screen (5 minutes)

Add this button to your home/inbox screen to open the advanced search:

**Option A: Add to FAB (Floating Action Button)**
```dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdvancedUserSearchScreen(),
      ),
    );
  },
  child: const Icon(Icons.search),
)
```

**Option B: Add to AppBar**
```dart
AppBar(
  actions: [
    IconButton(
      icon: const Icon(Icons.search),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvancedUserSearchScreen(),
          ),
        );
      },
    ),
  ],
)
```

---

### Step 4: Test the Feature (10 minutes)

**Test Case 1: Email Search (Direct Message)**
1. User A: Search for User B by email (`user.b@example.com`)
2. Click on search result
3. Send message: "Hi from email search"
4. ✅ Message sends immediately
5. ✅ User B receives notification instantly
6. ✅ Conversation opens normally

**Test Case 2: Name Search (Message Request)**
1. User A: Search for User B by name (`User B`)
2. Click on search result
3. Send message: "Hi from name search"
4. ✅ Message marked as "request" in database
5. ✅ User B receives request notification (different from direct message)
6. ✅ User B can see request is pending
7. ✅ User B accepts/rejects request
8. If accepted → conversation continues normally
9. If rejected → User A cannot send more messages

---

## Database Schema

### messages table (Updated)
```sql
Column: search_method
Type: TEXT
Values: 'email' | 'name'
Default: 'name'
Purpose: Tracks how recipient was found

Column: is_request
Type: BOOLEAN
Default: FALSE
Purpose: TRUE if message is pending approval (name search), FALSE if direct (email search)
```

---

## User Flow Diagrams

### Email Search Flow
```
User A searches by email
    ↓
System finds exact email match
    ↓
User A taps on result
    ↓
Chat opens with searchMethod='email'
    ↓
User A sends message
    ↓
is_request = FALSE
    ↓
Message sends immediately
    ↓
User B gets notification
    ↓
Chat conversation continues normally
```

### Name Search Flow
```
User A searches by name
    ↓
System finds exact name match
    ↓
User A taps on result
    ↓
Chat opens with searchMethod='name'
    ↓
User A sends message
    ↓
is_request = TRUE
    ↓
Message stays in pending state
    ↓
User B gets "message request" notification
    ↓
User B can Accept/Reject
    ↓
If Accepted: Conversation unlocks
If Rejected: User A blocked, cannot message again
```

---

## Key Differences

| Feature | Email Search | Name Search |
|---------|--------------|------------|
| **Search by** | Email address | Full name |
| **Message Status** | Direct (immediate) | Pending (request) |
| **Approval Needed** | ❌ No | ✅ Yes |
| **Notification Type** | Direct message | Message request |
| **Can Spam** | ❌ Controlled by rate limiting | ❌ Blocked after rejection |
| **Best For** | Known contacts | Discovering new people |
| **Privacy Level** | Open | Protected |

---

## Configuration Options

### Enable/Disable by User Preference
In user settings, allow users to choose:
- "Everyone can message me" → Accept all (regardless of search method)
- "Only email searches" → Only direct messages allowed
- "Only approved" → All messages require approval (name search only)

---

## Advanced Features (Optional)

### 1. Message Request Management UI
Add a "Message Requests" screen:
```dart
// Show pending requests
GET /message_requests WHERE receiver_id = currentUser AND status = 'pending'

// Accept request
UPDATE message_requests SET status = 'accepted' WHERE id = requestId

// Reject request
UPDATE message_requests SET status = 'rejected' WHERE id = requestId
```

### 2. Search History
Track what users search for:
```dart
// Optional: Log searches for analytics
INSERT INTO search_history (user_id, query, search_method, timestamp)
VALUES (currentUser, 'john@example.com', 'email', NOW())
```

### 3. Rate Limiting
Prevent spam message requests:
```sql
-- Limit to 5 message requests per hour per user
CREATE OR REPLACE FUNCTION check_message_request_limit()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) < 5
        FROM message_requests
        WHERE sender_id = auth.uid()
        AND created_at > NOW() - INTERVAL '1 hour'
    );
END;
$$ LANGUAGE plpgsql;
```

---

## Troubleshooting

### Issue: Search results show 0 users
**Solution:**
1. Ensure `email` column exists in profiles table
2. Run: `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;`
3. Populate emails: `UPDATE profiles p SET email = au.email FROM auth.users au WHERE p.id = au.id;`
4. Restart app

### Issue: Messages not tracking search method
**Solution:**
1. Verify migration was applied: `SELECT column_name FROM information_schema.columns WHERE table_name='messages' AND column_name='search_method';`
2. Should return one row with `search_method`
3. If not, re-run `MESSAGE_REQUESTS_BY_SEARCH_METHOD.sql`

### Issue: Request notifications not appearing
**Solution:**
1. Ensure `send-notification` Edge Function exists
2. Check that `FIREBASE_SERVICE_ACCOUNT` is set in Supabase secrets
3. Check function logs in Supabase Dashboard

---

## Files Created/Modified

### Created:
- ✅ `lib/screens/chat/advanced_user_search_screen.dart` - New search UI with toggle
- ✅ `MESSAGE_REQUESTS_BY_SEARCH_METHOD.sql` - Database migration

### Modified:
- ✅ `lib/services/chat_service.dart` - Updated message sending logic
- ✅ `lib/screens/chat/chat_screen.dart` - Added search method parameter

### To Modify:
- `lib/screens/home/home_screen.dart` - Add search button to FAB or AppBar

---

## Next Steps

1. ✅ Run database migration in Supabase
2. ✅ Test the feature thoroughly
3. ✅ Add search button to your main screen
4. ✅ Customize notification messages for requests
5. (Optional) Add message request management UI
6. (Optional) Add rate limiting for spam prevention
7. (Optional) Add user settings for messaging privacy

---

## Testing Checklist

- [ ] Email search finds users by exact email match
- [ ] Email search messages send immediately
- [ ] Name search finds users by exact name match
- [ ] Name search messages marked as requests
- [ ] Notifications differ between email and name searches
- [ ] User can see pending requests
- [ ] User can accept/reject requests
- [ ] After rejection, sender cannot message
- [ ] Toggle buttons work correctly
- [ ] UI shows correct feedback messages
- [ ] No compilation errors
- [ ] All edge cases handled

---

**Status**: ✅ **READY FOR TESTING**
**Complexity**: Medium (2-3 hours implementation + testing)
**Risk Level**: Low (non-breaking changes, additive feature)
