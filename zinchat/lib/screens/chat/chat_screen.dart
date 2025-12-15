import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin;
import '../../utils/constants.dart';
import '../../utils/debug_logger.dart';
import '../../services/chat_service.dart';
import '../../services/privacy_service.dart';
import '../../services/notification_service.dart';
import '../../services/hybrid_messaging_service.dart';
import '../../services/local_message_cache_service.dart';
import '../../services/media_download_service.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../main.dart';
import '../../services/storage_service.dart';
import '../../services/audio_service.dart';
import '../../services/call_manager.dart';
import '../../providers/theme_provider.dart';
import '../../utils/string_sanitizer.dart';
import '../profile/user_profile_view_screen.dart';
import '../media/media_viewer_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;
  final String searchMethod; // 'email' or 'name' - determines message sending behavior

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
    this.searchMethod = 'name', // Default to name search (message request)
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  static const int _waveformSampleCount = 28;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();
  final _privacyService = PrivacyService();
  final _currentUserId = supabase.auth.currentUser!.id;

  final _storageService = StorageService();
  bool _isUploadingMedia = false;
  
  // Pagination variables
  List<MessageModel> _messages = [];
  bool _hasLoadedInitialMessages = false;
  
  // Real-time streaming
  StreamSubscription<List<MessageModel>>? _messagesStreamSubscription;

  final _audioService = AudioService();
  bool _isRecordingVoice = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  StreamSubscription<double>? _recordingAmplitudeSub;
  StreamSubscription<Duration>? _playbackPositionSub;
  StreamSubscription<Duration>? _playbackDurationSub;
  StreamSubscription<void>? _playbackCompleteSub;
  List<double> _liveWaveform = List<double>.filled(_waveformSampleCount, 0.2);
  double _audioPlaybackProgress = 0.0;
  Duration _currentAudioDuration = Duration.zero;
  double _recordingPulseIntensity = 0.0;

  // For playing audio messages
  String? _playingAudioMessageId;
  
  bool _isUserBlocked = false;

  late final AnimationController _mediaLoaderController;

  @override
  void initState() {
    super.initState();
    NotificationService.setActiveChatId(widget.chatId);
    _markMessagesAsRead();
    _checkBlockStatus();
    _setupAudioSubscriptions();
    
    // OFFLINE-FIRST: Load cached messages instantly before stream
    _loadCachedMessagesFirst();
    
    _setupMessageStream();
    
    // Initialize hybrid realtime messaging
    _setupHybridRealtimeMessaging();
    
    _messageController.addListener(() {
      setState(() {}); // Rebuild to show/hide send button
    });
    
    // Initialize animation controller after widget is mounted
    _mediaLoaderController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }
  
  /// Load cached messages instantly (offline-first like WhatsApp)
  Future<void> _loadCachedMessagesFirst() async {
    try {
      debugPrint('💾 Loading cached messages for instant display');
      final cachedMessages = await LocalMessageCacheService().getCachedMessages(widget.chatId);
      
      if (cachedMessages.isNotEmpty && mounted) {
        setState(() {
          _messages = cachedMessages;
          _hasLoadedInitialMessages = true;
        });
        debugPrint('✅ Loaded ${cachedMessages.length} cached messages instantly');
        
        // Scroll to bottom after loading cached messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading cached messages: $e');
    }
  }
  
  /// Setup hybrid realtime messaging with Supabase
  /// This enables instant message delivery like WhatsApp
  void _setupHybridRealtimeMessaging() {
    debugPrint('🔗 Setting up hybrid realtime messaging for chat: ${widget.chatId}');
    
    HybridMessagingService().subscribeToRealtimeMessages(widget.chatId);
  }
  
  /// Setup real-time message streaming
  void _setupMessageStream() {
    debugPrint('🔄 Setting up message stream for chat: ${widget.chatId}');
    
    _messagesStreamSubscription = _chatService.getMessagesStream(widget.chatId).listen(
      (streamMessages) {
        if (!mounted) return;
        
        debugPrint('📨 Stream update: ${streamMessages.length} messages');
        
        final wasEmpty = _messages.isEmpty;
        
        setState(() {
          _messages = streamMessages;
          _hasLoadedInitialMessages = true;
        });
        
        // OFFLINE-FIRST: Cache messages for offline access
        LocalMessageCacheService().cacheMessages(widget.chatId, streamMessages);
        
        // Auto-download media if enabled
        for (final message in streamMessages) {
          if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
            MediaDownloadService().autoDownloadIfNeeded(
              mediaUrl: message.mediaUrl!,
              mediaType: message.messageType,
              messageId: message.id,
            );
          }
        }
        
        // Auto-scroll to bottom when messages are loaded or new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || streamMessages.isEmpty) return;
          
          // Add delay to ensure ListView has finished building with new items
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted || !_scrollController.hasClients) return;
            
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.position.pixels;
            
            // Use jumpTo for initial load, animateTo for updates
            if (wasEmpty) {
              debugPrint('✅ Initial load - jumping to bottom (max: $maxScroll)');
              _scrollController.jumpTo(maxScroll);
            } else {
              // Only auto-scroll if user is near the bottom (within 200px)
              final isNearBottom = (maxScroll - currentScroll) < 200;
              if (isNearBottom || streamMessages.length > _messages.length) {
                debugPrint('📨 New messages - animating to bottom (current: $currentScroll, max: $maxScroll)');
                _scrollController.animateTo(
                  maxScroll,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                debugPrint('👀 User scrolled up, not auto-scrolling');
              }
            }
          });
        });
        
        // Mark as read when we get updates
        _markMessagesAsRead();
      },
      onError: (error) {
        debugPrint('❌ Error in message stream: $error');
        DebugLogger.error('Message stream error: $error', tag: 'CHAT');
      },
    );
  }

  void _setupAudioSubscriptions() {
    _playbackDurationSub = _audioService.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _currentAudioDuration = duration;
        if (duration.inMilliseconds == 0) {
          _audioPlaybackProgress = 0.0;
        }
      });
    });

    _playbackPositionSub = _audioService.positionStream.listen((position) {
      if (!mounted) return;
      final totalMs = _currentAudioDuration.inMilliseconds;
      final progress = totalMs > 0
          ? position.inMilliseconds / totalMs
          : 0.0;
      setState(() {
        _audioPlaybackProgress = progress.clamp(0.0, 1.0);
      });
    });

    _playbackCompleteSub = _audioService.onComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingAudioMessageId = null;
        _audioPlaybackProgress = 0.0;
      });
    });
  }

  AnimationController _createAnimationController() {
    return _mediaLoaderController;
  }

  Future<void> _checkBlockStatus() async {
    final isBlocked = await _privacyService.isUserBlocked(widget.otherUser.id);
    if (mounted) {
      setState(() {
        _isUserBlocked = isBlocked;
      });
    }
  }

  void _openUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileViewScreen(
          user: widget.otherUser,
          showChatButton: false, // Already in chat, no need for message button
        ),
      ),
    );
  }

  @override
  void dispose() {
    NotificationService.setActiveChatId(null);
    
    // Unsubscribe from realtime messaging
    HybridMessagingService().unsubscribeFromRealtimeMessages(widget.chatId);
    
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _recordingAmplitudeSub?.cancel();
    _playbackDurationSub?.cancel();
    _playbackPositionSub?.cancel();
    _playbackCompleteSub?.cancel();
    _messagesStreamSubscription?.cancel(); // Cancel real-time stream
    _audioService.dispose();
    // Stop the animation before disposing
    if (_mediaLoaderController.isAnimating) {
      _mediaLoaderController.stop();
    }
    _mediaLoaderController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.chatId);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    try {
      // Dynamically determine if users are contacts now
      // This handles the case where a message request was accepted
      final areContacts = await _chatService.checkIfContacts(
        userId1: supabase.auth.currentUser!.id,
        userId2: widget.otherUser.id,
      );
      
      // Use 'email' if contacts (direct message), 'name' if not (message request)
      final searchMethod = areContacts ? 'email' : 'name';

      // Try to send message - if fails due to connectivity, queue for later
      final sentMessage = await _chatService.sendMessage(
        chatId: widget.chatId,
        content: content,
        searchMethod: searchMethod,
      );
      
      // If send failed and no connection, add to offline queue
      if (sentMessage == null) {
        final tempMessage = MessageModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          chatId: widget.chatId,
          senderId: supabase.auth.currentUser!.id,
          content: content,
          messageType: 'text',
          isRead: false,
          createdAt: DateTime.now(),
        );
        await LocalMessageCacheService().addToOfflineQueue(widget.chatId, tempMessage);
        
        if (mounted) {
          final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⏳ Message queued - will send when online'),
              backgroundColor: theme.secondaryColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Show feedback based on search method
      if (mounted) {
        final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
        final feedback = searchMethod == 'email'
            ? '✅ Message sent'
            : '📨 Message request sent - waiting for approval';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedback),
            backgroundColor: theme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // On error, also queue the message
      try {
        final tempMessage = MessageModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          chatId: widget.chatId,
          senderId: supabase.auth.currentUser!.id,
          content: content,
          messageType: 'text',
          isRead: false,
          createdAt: DateTime.now(),
        );
        await LocalMessageCacheService().addToOfflineQueue(widget.chatId, tempMessage);
      } catch (_) {}
      
      if (mounted) {
        final errorMessage = e.toString();
        
        // Check if this is a message request sent notification
        if (errorMessage.contains('REQUEST_SENT:')) {
          final message = errorMessage.split('REQUEST_SENT:')[1];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).currentTheme.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // 🔹 Show media options bottom sheet
  void _showMediaOptions() {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Share', style: AppTextStyles.heading2.copyWith(color: theme.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMediaOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: theme.primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(fromCamera: false);
                  },
                ),
                _buildMediaOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: theme.secondaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(fromCamera: true);
                  },
                ),
                _buildMediaOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: theme.error,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendVideo();
                  },
                ),
                _buildMediaOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: theme.primaryLight,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendFile();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: theme.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage({required bool fromCamera}) async {
    final file = await _storageService.pickImage(fromCamera: fromCamera);
    if (file != null) await _sendMediaFile(file, 'image');
  }

  Future<void> _pickAndSendVideo() async {
    final file = await _storageService.pickVideo();
    if (file != null) await _sendMediaFile(file, 'video');
  }

  Future<void> _pickAndSendFile() async {
    final file = await _storageService.pickFile();
    if (file != null) await _sendMediaFile(file, 'file');
  }

  Future<void> _sendMediaFile(File file, String type, {int? durationSeconds}) async {
    setState(() => _isUploadingMedia = true);
    try {
      // For audio messages, store duration in content field
      String? content;
      if (type == 'audio' && durationSeconds != null) {
        final waveform = _audioService.getWaveformSamples(
          sampleCount: _waveformSampleCount,
        );
        content = jsonEncode({
          'duration': durationSeconds,
          'waveform': waveform,
        });
      }

      final message = await _chatService.sendMediaMessage(
        chatId: widget.chatId,
        file: file,
        messageType: type,
        content: content, // Pass duration + waveform for audio
      );
      if (message == null) throw Exception('Failed to send media');
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('42501') || 
                           e.toString().toLowerCase().contains('contacts')
            ? 'Cannot send ${type == 'audio' ? 'voice note' : type}. Add ${widget.otherUser.displayName} as a contact first.'
            : 'Failed to send: ${type == 'audio' ? 'voice note' : type}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: e.toString().contains('42501') 
                ? AppColors.saturatedMagenta 
                : Colors.red,
            duration: const Duration(seconds: 4),
            action: e.toString().contains('42501')
                ? SnackBarAction(
                    label: 'Add Contact',
                    textColor: Colors.white,
                    onPressed: () {
                      // TODO: Navigate to add contact flow
                    },
                  )
                : null,
          ),
        );
      }
    } finally{
      if (type == 'audio') {
        _audioService.resetWaveformSamples();
      }
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  // Start voice recording
  Future<void> _startVoiceRecording() async {
    final started = await _audioService.startRecording();

    if (started) {
      setState(() {
        _isRecordingVoice = true;
        _recordingDuration = 0;
        _liveWaveform = List<double>.filled(_waveformSampleCount, 0.2);
      });

      _recordingAmplitudeSub?.cancel();
      _recordingAmplitudeSub = _audioService.amplitudeStream.listen((value) {
        if (!mounted) return;
        setState(() {
          _liveWaveform = [..._liveWaveform.skip(1), value];
          _recordingPulseIntensity = value;
        });
      });

      // Start timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });

        // Auto-stop at 2 minutes
        if (_recordingDuration >= 120) {
          _stopAndSendVoiceNote();
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
    }
  }

  // Block user handler
  Future<void> _handleBlockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Block ${widget.otherUser.displayName}? You won\'t be able to send or receive messages from them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.saturatedMagenta,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _privacyService.blockUser(widget.otherUser.id);
      if (success && mounted) {
        setState(() {
          _isUserBlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Blocked ${widget.otherUser.displayName}'),
            backgroundColor: AppColors.saturatedMagenta,
          ),
        );
      }
    }
  }

  // Unblock user handler
  Future<void> _handleUnblockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text(
          'Unblock ${widget.otherUser.displayName}? You\'ll be able to send and receive messages from them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).currentTheme.success,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _privacyService.unblockUser(widget.otherUser.id);
      if (success && mounted) {
        setState(() {
          _isUserBlocked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unblocked ${widget.otherUser.displayName}'),
            backgroundColor: Provider.of<ThemeProvider>(context, listen: false).currentTheme.success,
          ),
        );
      }
    }
  }

  // Stop and send voice note
  Future<void> _stopAndSendVoiceNote() async {
    _recordingTimer?.cancel();
    await _recordingAmplitudeSub?.cancel();
    _recordingAmplitudeSub = null;

    final file = await _audioService.stopRecording();
    final duration = _recordingDuration; // Store duration before reset

    setState(() {
      _isRecordingVoice = false;
      _recordingDuration = 0;
      _liveWaveform = List<double>.filled(_waveformSampleCount, 0.2);
    });

    if (file != null) {
      // Pass duration as content for audio messages
      await _sendMediaFile(file, 'audio', durationSeconds: duration);
    }
  }

  // Cancel voice recording
  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _recordingAmplitudeSub?.cancel();
    _recordingAmplitudeSub = null;
    await _audioService.cancelRecording();
    _audioService.resetWaveformSamples();

    setState(() {
      _isRecordingVoice = false;
      _recordingDuration = 0;
      _liveWaveform = List<double>.filled(_waveformSampleCount, 0.2);
    });
  }

  // Format duration as MM:SS
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _parseAudioMetadata(String content) {
    if (content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Older audio messages store plain text duration
    }
    return null;
  }

  Map<String, dynamic>? _parseCallStatusMetadata(String content) {
    if (content.isEmpty) return null;
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // In case the call status message was not JSON encoded
    }
    return null;
  }

  List<double> _normalizeWaveform(List<dynamic>? rawSamples) {
    if (rawSamples == null || rawSamples.isEmpty) {
      return List<double>.filled(_waveformSampleCount, 0.25);
    }

    final values = rawSamples
        .map((value) => value is num ? value.toDouble().clamp(0.05, 1.0) : 0.2)
        .toList();

    if (values.length == _waveformSampleCount) {
      return values;
    }

    final resized = <double>[];
    final step = values.length / _waveformSampleCount;
    for (var i = 0; i < _waveformSampleCount; i++) {
      final index = (i * step).floor().clamp(0, values.length - 1);
      resized.add(values[index]);
    }
    return resized;
  }

  LinearGradient _buildWaveBubbleGradient({required double intensity, required bool isMine}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final baseStart = isMine ? theme.myMessageBubble : theme.otherMessageBubble;
    final accent = isMine ? theme.secondaryColor : theme.primaryColor;
    final lerpValue = (0.3 + intensity * 0.7).clamp(0.3, 1.0);
    final secondColor = Color.lerp(baseStart, accent, lerpValue) ?? baseStart;
    return LinearGradient(
      colors: [
        baseStart.withOpacity(isMine ? 0.95 : 0.85),
        secondColor.withOpacity(isMine ? 0.9 : 0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildPulseBackdrop(double intensity, Color color) {
    final normalized = intensity.clamp(0.0, 1.0);
    final pulseSize = 120 + (normalized * 90);
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: pulseSize,
        height: pulseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(0.28 * (normalized + 0.2)),
              color.withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.1, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  double _currentPulseFromSamples(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final progress = _audioPlaybackProgress.clamp(0.0, 1.0);
    final index = (progress * (samples.length - 1)).round().clamp(0, samples.length - 1);
    return samples[index];
  }

  Widget _buildWaveformBars({
    required List<double> samples,
    required Color activeColor,
    required double progress,
    double height = 32,
    double barWidth = 3,
    double spacing = 2,
  }) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final progressIndex = (samples.length * clampedProgress).floor();
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(samples.length, (index) {
          final normalized = samples[index].clamp(0.05, 1.0);
          final barHeight = (normalized * height).clamp(height * 0.25, height);
          final isFilled = index <= progressIndex;
          return Container(
            width: barWidth,
            height: barHeight,
            margin: EdgeInsets.symmetric(horizontal: spacing / 2),
            decoration: BoxDecoration(
              color: isFilled ? activeColor : activeColor.withOpacity(0.35),
              borderRadius: BorderRadius.circular(barWidth / 1.5),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProgressBar({
    required double value,
    required Color color,
    double height = 4,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: color.withOpacity(0.2),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: height,
      ),
    );
  }

  // 🔹 UI Build Section
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openUserProfile,
          child: Row(
            children: [
              Hero(
                tag: 'profile_${widget.otherUser.id}',
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: widget.otherUser.profilePhotoUrl != null
                      ? NetworkImage(widget.otherUser.profilePhotoUrl!)
                      : null,
                  child: widget.otherUser.profilePhotoUrl == null
                      ? Text(StringSanitizer.getFirstCharacter(widget.otherUser.displayName),
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.otherUser.displayName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(
                      widget.otherUser.isOnline ? 'online' : widget.otherUser.lastSeenText,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.otherUser.isOnline 
                            ? AppColors.online 
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => CallManager().startDirectCall(
              context: context,
              receiverId: widget.otherUser.id,
              receiverName: widget.otherUser.displayName,
              isVideo: true,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => CallManager().startDirectCall(
              context: context,
              receiverId: widget.otherUser.id,
              receiverName: widget.otherUser.displayName,
              isVideo: false,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') {
                _handleBlockUser();
              } else if (value == 'unblock') {
                _handleUnblockUser();
              }
            },
            itemBuilder: (context) => [
              if (!_isUserBlocked)
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: AppColors.saturatedMagenta),
                      const SizedBox(width: 12),
                      const Text('Block User'),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'unblock',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Provider.of<ThemeProvider>(context, listen: false).currentTheme.success),
                      const SizedBox(width: 12),
                      const Text('Unblock User'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final theme = themeProvider.currentTheme;
          return Container(
            decoration: BoxDecoration(
              color: theme.chatBackground,
            ),
            child: _buildChatContent(),
          );
        },
      ),
    );
  }

  Widget _buildChatContent() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;
        return Column(
          children: [
            Expanded(
              child: !_hasLoadedInitialMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Say hi to ${widget.otherUser.displayName}!',
                            style: AppTextStyles.bodyLarge
                                .copyWith(color: theme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.md,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.senderId == _currentUserId;
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              color: Colors.transparent,
              child: SafeArea(
                child: _isRecordingVoice
                    ? _buildRecordingUI()
                    : _buildTextInput(),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🔹 Message bubbles with media support
  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    if (message.messageType == 'call_status') {
      return _buildCallStatusMessage(message);
    }
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final isMedia = message.messageType != 'text';
    final bubbleColor = isMe ? theme.myMessageBubble : theme.otherMessageBubble;
    final textColor = isMe ? theme.textPrimary : theme.textPrimary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMe ? () => _showMessageOptions(message) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: AppSpacing.sm),
          padding: EdgeInsets.all(isMedia ? 4 : 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: isMe ? AppRadius.messageBubble : AppRadius.messageBubbleOther,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.messageType == 'image')
                _buildImageMessage(message)
              else if (message.messageType == 'video')
                _buildVideoMessage(message)
              else if (message.messageType == 'audio')
                _buildAudioMessage(message, isMe)
              else if (message.messageType == 'file')
                _buildFileMessage(message)
              else
                Text(message.content, style: AppTextStyles.bodyMedium.copyWith(color: textColor)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeago.format(message.createdAt, locale: 'en_short'),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: theme.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    // Check if message is queued (temp id) or sent
                    if (message.id.startsWith('temp_'))
                      // Queued message indicator (clock icon)
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.orange,
                      )
                    else
                      // Sent message indicator (check marks)
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? theme.success : theme.textSecondary.withOpacity(0.8),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMediaViewer(MessageModel message) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;
    final isVideo = message.messageType == 'video';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          mediaUrl: url,
          type: isVideo ? MediaViewerType.video : MediaViewerType.image,
          heroTag: 'media_${message.id}',
          caption: message.content.isNotEmpty ? message.content : null,
        ),
      ),
    );
  }

  Widget _buildCallStatusMessage(MessageModel message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final metadata = _parseCallStatusMetadata(message.content);
    final event = metadata?['event'] as String? ?? 'ended';
    final isVideo = metadata?['isVideo'] as bool? ?? false;
    final durationSeconds = metadata?['duration_seconds'] as int? ?? 0;
    final otherUserId = metadata?['otherUserId'] as String? ?? widget.otherUser.id;
    final otherUserName = metadata?['otherUserName'] as String? ?? widget.otherUser.displayName;

    final title = event == 'missed'
        ? 'Missed ${isVideo ? 'video' : 'audio'} call'
        : 'Call ended';
    final subtitle = event == 'missed'
        ? 'Tap to call back'
        : 'Duration ${_formatDuration(durationSeconds)}';
    final actionLabel = event == 'missed' ? 'Call back' : 'Call again';
    final icon = event == 'missed' ? Icons.call_missed : Icons.call_end;
    final iconColor = event == 'missed' ? Colors.redAccent : theme.success;

    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: AppShadows.cardShadow,
          border: Border.all(color: theme.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            TextButton(
              onPressed: () => CallManager().startDirectCall(
                context: context,
                receiverId: otherUserId,
                receiverName: otherUserName,
                isVideo: isVideo,
              ),
              style: TextButton.styleFrom(
                backgroundColor: theme.success,
                foregroundColor: theme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Show message options (edit/delete)
  void _showMessageOptions(MessageModel message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit, color: theme.primaryColor),
              title: Text('Edit', style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text('Delete', style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show edit dialog
  void _showEditDialog(MessageModel message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final editController = TextEditingController(text: message.content);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Message', style: TextStyle(color: theme.textPrimary)),
        backgroundColor: theme.cardBackground,
        content: TextField(
          controller: editController,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: TextStyle(color: theme.textLight),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: theme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.primaryColor),
            ),
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: theme.primaryColor)),
          ),
          TextButton(
            onPressed: () {
              _editMessage(message.id, editController.text);
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: theme.primaryColor)),
          ),
        ],
      ),
    );
  }

  // Delete message
  Future<void> _deleteMessage(String messageId) async {
    try {
      final success = await _chatService.deleteMessage(messageId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  // Edit message
  Future<void> _editMessage(String messageId, String newContent) async {
    try {
      final success = await _chatService.editMessage(
        messageId: messageId,
        newContent: newContent,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit: $e')),
        );
      }
    }
  }

  Widget _buildImageMessage(MessageModel message) {
    if (message.mediaUrl == null) {
      return const Icon(Icons.broken_image, color: Colors.red);
    }
    return GestureDetector(
      onTap: () => _openMediaViewer(message),
      child: Hero(
        tag: 'media_${message.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            width: 250,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 250,
              height: 250,
              color: Colors.grey[900],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(MessageModel message) {
    return GestureDetector(
      onTap: () => _openMediaViewer(message),
      child: Hero(
        tag: 'media_${message.id}',
        child: Container(
          width: 260,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            gradient: const LinearGradient(
              colors: [Colors.black87, Colors.black54],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMessage(MessageModel message, bool isMe) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final isPlaying = _playingAudioMessageId == message.id;
    final textColor = isMe
      ? theme.textPrimary.withOpacity(0.9)
      : theme.textPrimary.withOpacity(0.85);
    final metadata = _parseAudioMetadata(message.content);
    final durationValue = metadata?['duration'];
    final durationSeconds = durationValue is num ? durationValue.toInt() : null;
    final rawWaveform = metadata?['waveform'];
    final waveformSamples = _normalizeWaveform(
      rawWaveform is List ? rawWaveform : null,
    );
    final durationText = durationSeconds != null
        ? _formatDuration(durationSeconds)
        : (metadata == null && message.content.isNotEmpty
            ? message.content
            : '00:00');
    final pulseIntensity = isPlaying
        ? _currentPulseFromSamples(waveformSamples)
        : 0.2;
    final bubbleGradient = _buildWaveBubbleGradient(
      intensity: pulseIntensity,
      isMine: isMe,
    );
    
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: isMe ? 32 : 0,
          right: isMe ? 0 : null,
          child: _buildPulseBackdrop(
            pulseIntensity,
            isMe ? theme.primaryColor : theme.secondaryColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: bubbleGradient,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: [
              BoxShadow(
                color: (isMe ? theme.myMessageBubble : theme.otherMessageBubble)
                    .withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          width: 240,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play button
              GestureDetector(
                onTap: () {
                  if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;
                  if (isPlaying) {
                    _audioService.stopAudio();
                    setState(() {
                      _playingAudioMessageId = null;
                      _audioPlaybackProgress = 0.0;
                      _currentAudioDuration = Duration.zero;
                    });
                  } else {
                    setState(() {
                      _playingAudioMessageId = message.id;
                      _audioPlaybackProgress = 0.0;
                      _currentAudioDuration = durationSeconds != null
                          ? Duration(seconds: durationSeconds)
                          : Duration.zero;
                    });
                    _audioService.playAudio(message.mediaUrl!);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.textPrimary.withOpacity(isPlaying ? 0.3 : 0.2),
                    border: Border.all(
                      color: theme.textPrimary.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: theme.textPrimary,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Waveform visualization
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWaveformBars(
                      samples: waveformSamples,
                      activeColor: theme.textPrimary,
                      progress: isPlaying ? _audioPlaybackProgress : 1.0,
                      height: 38,
                      barWidth: 3,
                      spacing: 2,
                    ),
                    const SizedBox(height: 6),
                    _buildProgressBar(
                      value: isPlaying ? _audioPlaybackProgress : 0.0,
                      color: theme.textPrimary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFileMessage(MessageModel message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file,
              color: theme.primaryColor, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message.content,
              style: AppTextStyles.bodyMedium.copyWith(color: theme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingUI() {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final gradient = _buildWaveBubbleGradient(
      intensity: _recordingPulseIntensity,
      isMine: true,
    );
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: 24,
          child: _buildPulseBackdrop(
            _recordingPulseIntensity,
            theme.primaryColor,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: [
              BoxShadow(
                color:
                    theme.primaryColor.withOpacity(0.35 * (_recordingPulseIntensity + 0.2)),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Delete button
              IconButton(
                icon: Icon(Icons.delete_outline, color: theme.textPrimary),
                onPressed: _cancelVoiceRecording,
              ),

              // Recording indicator + duration
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 8),

              Text(
                _formatDuration(_recordingDuration),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),

              const SizedBox(width: 8),

              // Waveform + progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWaveformBars(
                      samples: _liveWaveform,
                      activeColor: theme.textPrimary,
                      progress: 1.0,
                      height: 34,
                      barWidth: 3,
                      spacing: 2,
                    ),
                    const SizedBox(height: 6),
                    _buildProgressBar(
                      value: (_recordingDuration / 120).clamp(0.0, 1.0),
                      color: theme.textPrimary,
                    ),
                  ],
                ),
              ),

              // Send button
              CircleAvatar(
                backgroundColor: theme.textPrimary,
                radius: 24,
                child: IconButton(
                  icon: Icon(
                    Icons.send,
                    color: theme.myMessageBubble,
                    size: 20,
                  ),
                  onPressed: _stopAndSendVoiceNote,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: _isUploadingMedia
          ? // Show professional loading state instead of input
          _buildProfessionalMediaLoader()
          : // Normal input state
          Row(
            children: [
              // Emoji button
              IconButton(
                icon: Icon(
                  Icons.emoji_emotions_outlined,
                  color: theme.textSecondary,
                  size: 24,
                ),
                onPressed: () {
                  // Emoji picker - coming soon
                },
              ),

              // Text input
              Expanded(
                child: Builder(
                  builder: (context) {
                    final theme = Provider.of<ThemeProvider>(context).currentTheme;
                    return TextField(
                      controller: _messageController,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: theme.textSecondary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    );
                  },
                ),
              ),

              // Attachment button
              IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: theme.textSecondary,
                  size: 24,
                ),
                onPressed: _showMediaOptions,
              ),

              // Camera button
              IconButton(
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: theme.textSecondary,
                  size: 24,
                ),
                onPressed: () => _pickAndSendImage(fromCamera: true),
              ),

              const SizedBox(width: AppSpacing.xs),

              // Send button or mic button
              Container(
                margin: const EdgeInsets.all(AppSpacing.xs),
                child: CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  radius: 22,
                  child: _messageController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: theme.textPrimary,
                            size: 20,
                          ),
                          onPressed: _sendMessage,
                          padding: EdgeInsets.zero,
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.mic,
                            color: theme.textPrimary,
                            size: 22,
                          ),
                          onPressed: _startVoiceRecording,
                          padding: EdgeInsets.zero,
                        ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildProfessionalMediaLoader() {
    final theme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated upload icon
          AnimatedBuilder(
            animation: _createAnimationController(),
            builder: (context, child) {
              final animation = _createAnimationController();
              return Transform.scale(
                scale: 0.8 + (0.2 * animation.value),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryColor.withOpacity(0.2),
                        theme.primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_upload_rounded,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Text with animated dots
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sending media',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _createAnimationController(),
                      builder: (context, child) {
                        final animation = _createAnimationController();
                        final dots = '...'.substring(
                          0,
                          ((animation.value * 3) % 4).floor(),
                        );
                        return Text(
                          dots,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Animated progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: AnimatedBuilder(
                    animation: _createAnimationController(),
                    builder: (context, child) {
                      final animation = _createAnimationController();
                      return Container(
                        height: 3,
                        width: 120,
                        decoration: BoxDecoration(
                          color: theme.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Stack(
                          children: [
                            // Shimmer effect
                            Positioned(
                              left: (120 * animation.value) - 40,
                              child: Container(
                                width: 40,
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      theme.primaryColor,
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Checkmark pulse icon
          AnimatedBuilder(
            animation: _createAnimationController(),
            builder: (context, child) {
              final animation = _createAnimationController();
              return Transform.scale(
                scale: 0.9 + (0.15 * (sin(animation.value * 3.14159 * 2))),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}