# ⚡ Quick Start: Message Requests by Search Method

## What You're Getting
Two ways to message:
- **Search by Email** → Instant chat (no approval)
- **Search by Name** → Message request (needs approval)

---

## 4-Step Setup (30 minutes)

### Step 1: Run Database Migration (5 min)
```sql
1. Go to Supabase Dashboard → SQL Editor
2. Open: MESSAGE_REQUESTS_BY_SEARCH_METHOD.sql
3. Copy all content
4. Paste into Supabase
5. Click RUN
```

### Step 2: Nothing! Code is Ready ✅
All Flutter code changes are done:
- ✅ `chat_service.dart` - Updated
- ✅ `chat_screen.dart` - Updated  
- ✅ `advanced_user_search_screen.dart` - Created
- ✅ No compilation errors

### Step 3: Add Search Button (5 min)
In `lib/screens/home/home_screen.dart`, add to FAB or AppBar:

```dart
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
)
```

### Step 4: Test (5 min)
1. **Email Search Test**
   - Search: `user@example.com`
   - Send message → Sends immediately ✅
   
2. **Name Search Test**
   - Search: `User Name`
   - Send message → Shows "Message request sent" ✅

---

## How It Works

### Email Search → Direct Message
```
User A searches: john@example.com
    ↓
Finds John
    ↓
Sends message
    ↓
Message sends immediately (is_request = FALSE)
    ↓
John gets instant notification
```

### Name Search → Message Request
```
User A searches: John Smith
    ↓
Finds John
    ↓
Sends message
    ↓
Message goes to pending (is_request = TRUE)
    ↓
John gets message request notification
    ↓
John accepts/rejects
```

---

## Database Changes

Added 2 columns to `messages` table:
```sql
search_method TEXT ('email' or 'name')
is_request BOOLEAN (TRUE = pending, FALSE = direct)
```

---

## Import Statement
```dart
import '../../screens/chat/advanced_user_search_screen.dart';
```

---

## FAQs

**Q: Do both search methods create chats?**  
A: Yes, both create chats. Email search sends directly, name search creates pending messages.

**Q: Can I still use old search?**  
A: The new search replaces it. Update any old search buttons to use `AdvancedUserSearchScreen`.

**Q: What if email doesn't exist?**  
A: Email search returns 0 results. User must have email column populated.

**Q: Can I customize notifications?**  
A: Yes, edit `_sendMessageRequestNotification()` in `chat_service.dart`.

---

## That's It!

Your app now has two messaging modes:
- 📧 Email search = instant (trustworthy)
- 👤 Name search = request (safe)

Test it and let me know any issues!
