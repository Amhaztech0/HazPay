# 🎵 Audio Playback Implementation - Copy & Paste Ready

## Quick Implementation (Copy This Code)

### Step 1: Add Audio Player Import

Add this import to the top of `lib/screens/servers/server_chat_screen.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
```

---

### Step 2: Add Audio Player State Variables

Add these variables to the `_ServerChatScreenState` class (after the recording variables):

```dart
  // Voice playback variables
  AudioPlayer? _audioPlayer;
  String? _currentPlayingMessageId;
  Duration _currentPlayingPosition = Duration.zero;
```

---

### Step 3: Initialize in initState()

Add this line to your `initState()` method (after `_audioRecorder = AudioRecorder();`):

```dart
    _audioPlayer = AudioPlayer();
```

---

### Step 4: Clean Up in dispose()

Update your `dispose()` method to add:

```dart
  @override
  void dispose() {
    NotificationService.setActiveServerChatId(null);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _messagesStreamSubscription?.cancel();
    _recordingTimer.cancel();
    _audioPlayer?.dispose();  // Add this line
    super.dispose();
  }
```

---

### Step 5: Add Playback Method

Add this complete method to `_ServerChatScreenState` class (before the closing brace):

```dart
  /// Play voice message
  Future<void> _playVoiceMessage(String audioUrl, String messageId) async {
    try {
      // Stop any currently playing audio
      if (_currentPlayingMessageId != null && _currentPlayingMessageId != messageId) {
        await _audioPlayer?.stop();
      }

      setState(() => _currentPlayingMessageId = messageId);
      
      // Play the audio file
      await _audioPlayer?.play(UrlSource(audioUrl));
      
      // Listen for playback completion
      _audioPlayer?.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _currentPlayingMessageId = null);
        }
      });

      // Listen for errors
      _audioPlayer?.onPlayerStateChanged.listen((PlayerState state) {
        if (state == PlayerState.stopped && mounted) {
          setState(() => _currentPlayingMessageId = null);
        }
      });
    } catch (e) {
      debugPrint('❌ Error playing voice message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Reset playing state on error
      if (mounted) {
        setState(() => _currentPlayingMessageId = null);
      }
    }
  }
```

---

### Step 6: Update the Voice Widget Play Button

Find this line in `_buildVoiceMessageWidget()`:

```dart
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('🎙️ Playing voice message...'),
                  backgroundColor: theme.primaryColor,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Audio playback will be implemented with audioplayers package
            },
```

Replace it with:

```dart
            onTap: () {
              HapticFeedback.mediumImpact();
              _playVoiceMessage(message.mediaUrl!, message.id);
            },
```

---

### Step 7: Update Voice Widget to Show Playing State

Find this section in `_buildVoiceMessageWidget()`:

```dart
          // Play/Pause button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _playVoiceMessage(message.mediaUrl!, message.id);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
```

Replace the entire play button icon section with:

```dart
          // Play/Pause button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (_currentPlayingMessageId == message.id) {
                // Pause the current playback
                _audioPlayer?.pause();
                setState(() => _currentPlayingMessageId = null);
              } else {
                // Play this message
                _playVoiceMessage(message.mediaUrl!, message.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _currentPlayingMessageId == message.id
                    ? Colors.orange  // Orange when playing
                    : theme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentPlayingMessageId == message.id
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
```

---

## Testing the Playback

After making these changes:

1. Run `flutter pub get` (if you haven't already)
2. Run `flutter run` on device
3. Send a voice message
4. Click the play button
5. You should hear the audio play
6. Button turns orange and shows pause icon while playing
7. Click pause to stop
8. Click play again to resume

---

## Advanced: Add Progress Bar

If you want to show playback progress, replace the progress bar section:

```dart
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
```

With:

```dart
                FutureBuilder<Duration?>(
                  future: _audioPlayer?.getDuration(),
                  builder: (context, snapshotDuration) {
                    final duration = snapshotDuration.data ?? Duration.zero;
                    
                    return StreamBuilder<Duration>(
                      stream: _audioPlayer?.onPositionChanged,
                      builder: (context, snapshotPosition) {
                        final position = snapshotPosition.data ?? Duration.zero;
                        final progress = duration.inMilliseconds > 0
                            ? (position.inMilliseconds / duration.inMilliseconds) * 100
                            : 0.0;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎙️ ${_formatDuration(position)} / ${_formatDuration(duration)}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.textSecondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Container(
                                width: (progress / 100) * 220,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
```

---

## Final Checklist

- [ ] Import `package:audioplayers/audioplayers.dart`
- [ ] Add `_audioPlayer` and `_currentPlayingMessageId` variables
- [ ] Initialize in `initState()`
- [ ] Dispose in `dispose()`
- [ ] Add `_playVoiceMessage()` method
- [ ] Update play button `onTap`
- [ ] Update play button icon to show playing state
- [ ] Test recording a voice message
- [ ] Test playing the voice message
- [ ] Test playing multiple messages
- [ ] Test pause/play toggle
- [ ] Test on both Android and iOS devices

---

## Common Issues

**"AudioPlayer not found"**
- Make sure you added `import 'package:audioplayers/audioplayers.dart';`
- Run `flutter pub get`

**"Audio doesn't play"**
- Check URL is accessible (test in browser)
- Check network is working
- Check device volume isn't muted
- Check app has microphone permission (for some devices)

**"Play button doesn't update"**
- Make sure `setState()` is being called
- Check `_currentPlayingMessageId` is being updated
- Verify the comparison `_currentPlayingMessageId == message.id` works

**"Multiple audios playing at once"**
- The code stops other playbacks before starting new one
- If not working, explicitly call `await _audioPlayer?.stopAll();` first

---

Done! This is production-ready audio playback. 🎉
