# Server Chat - Pagination & Search Visual Guide

## 1. Search Icon in AppBar

```
┌─────────────────────────────────────────────────┐
│ ← 🎮 My Server                    📞📹🔍 ⋯       │
│     #general                                     │
│     24 members                                   │
└─────────────────────────────────────────────────┘
           ↑                      ↑↑  ↑
      Server Icon       Call  Video Search Menu
                        Buttons      Icon
```

### Search Icon Behavior
- **Default**: Shows `🔍` (search icon)
- **Active**: Changes to `✕` (close icon)
- **Tap**: Toggles search mode on/off

---

## 2. Search Bar (When Active)

```
┌─────────────────────────────────────────────────┐
│ 🔍 Search messages...                        ✕  │
└─────────────────────────────────────────────────┘
    ↑                                          ↑
  Search Icon                        Clear button
  (permanent)                    (appears with text)
```

### Search Bar Features
- Real-time filtering as you type
- Case-insensitive search
- Matches message content
- Shows "No messages found" when empty result
- Tap `✕` or back button to exit

---

## 3. Discord-Style Loading Indicator

### Appears When Scrolling Up to Load Older Messages

```
┌─────────────────────────────────────────────────┐
│ Message 50                                       │
│ User A: This is message 50                       │
├─────────────────────────────────────────────────┤
│ Message 49                                       │
│ User B: Another message here                     │
├─────────────────────────────────────────────────┤
│    ⟳ Loading older messages...                  │ ← Discord Style
├─────────────────────────────────────────────────┤
│ Message 48                                       │
│ User A: Yet another message                      │
└─────────────────────────────────────────────────┘
```

### Animation
- Circular spinner rotates
- Text updates as messages load
- Disappears when page fully loaded
- Position: Bottom of current message set

---

## 4. Pagination Flow (User Perspective)

### Step 1: Open Channel
```
✓ Channel selected
→ First 50 messages load (newest first, displayed oldest first)
→ Ready to view
```

### Step 2: Scroll Up (Toward Older Messages)
```
User scrolls 500px from bottom ↑
    ↓
[Detection] Pagination triggered
    ↓
Loading indicator appears
    ↓
Next 50 messages load
    ↓
Messages inserted into list
    ↓
Loading indicator disappears
```

### Step 3: Continue Scrolling
```
Keep scrolling up → Pagination repeats
Repeat until no more messages
```

---

## 5. Search in Action

### Before Search
```
┌─────────────────────────────────────────────────┐
│ ← 🎮 My Server                    📞📹🔍 ⋯       │
│     #general                                     │
│     [50+ messages visible]                       │
│     Latest message from 2 hours ago              │
└─────────────────────────────────────────────────┘
```

### During Search
```
┌─────────────────────────────────────────────────┐
│ ← 🎮 My Server                    📞📹✕ ⋯       │
│     #general                                     │
├─────────────────────────────────────────────────┤
│ 🔍 hello                                      ✕  │
├─────────────────────────────────────────────────┤
│ User A: Hello there! How are you?               │
│ User B: Hello everyone!                         │
│ User A: Say hello when you join                 │
│ [3 results found in loaded messages]            │
└─────────────────────────────────────────────────┘
```

### After Clearing Search
```
Back to full message list
```

---

## 6. Channel Switching

### User Changes Channel
```
Dropdown: #general → #announcements
    ↓
[Automatic Reset]
  • Clear all messages
  • Clear search
  • Reset pagination
  • Hide search bar
    ↓
Load new channel's first 50 messages
    ↓
Ready to scroll/search
```

---

## 7. Real-Time Messages + Pagination

### Scenario: Message arrives while scrolling up

```
Timeline:
─────────────────────────────────────────
[User scrolling up to load page 2]
    ↓
[Real-time message arrives from John]
    ↓
[Message merged into _messages list]
    ↓
[No duplicates, properly ordered]
    ↓
[UI updates seamlessly]
─────────────────────────────────────────
```

---

## 8. Performance Impact

### Before (Old System)
```
Large chat (1000+ messages)
    ↓
Load ALL into memory
    ↓
Lag while scrolling
    ↓
Possible OOM crash
```

### After (Pagination)
```
Large chat (1000+ messages)
    ↓
Load 50 at a time
    ↓
Smooth scrolling
    ↓
Load more on demand
    ↓
Stable, never crashes
```

---

## 9. Error States

### No Messages in Channel
```
┌─────────────────────────────────────────────────┐
│                                                  │
│              💬 No messages yet                  │
│         Start the conversation!                  │
│                                                  │
└─────────────────────────────────────────────────┘
```

### Search with No Results
```
┌─────────────────────────────────────────────────┐
│ 🔍 "impossible query that matches nothing"      │
├─────────────────────────────────────────────────┤
│         No messages found                        │
│                                                  │
│   (Try different search terms)                   │
└─────────────────────────────────────────────────┘
```

---

## 10. Keyboard/Control Reference

| Action | Result |
|--------|--------|
| Tap 🔍 icon | Open search |
| Tap ✕ icon | Close search |
| Type in search bar | Real-time filter |
| Tap ✕ in search bar | Clear search text |
| Scroll up (500px from bottom) | Load older messages |
| Change channel dropdown | Reset pagination & search |
| New message arrives | Auto-merged into list |

---

## Technical Summary

| Feature | Status | Type | Performance |
|---------|--------|------|-------------|
| Pagination | ✅ Active | Automatic | 50 msgs/load |
| Search | ✅ Active | On-demand | Real-time |
| Discord Loading | ✅ Active | Visual | Smooth |
| Channel Reset | ✅ Active | Automatic | Instant |
| Real-time Merge | ✅ Active | Automatic | Seamless |
| Deduplication | ✅ Active | Automatic | O(1) check |

---

**Key Design Principle**: Load only what's needed, when it's needed. Provide visual feedback, enable powerful search, never crash.
