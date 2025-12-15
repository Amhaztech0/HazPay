import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../models/server_model.dart';
import '../../models/server_channel_model.dart';
import '../../services/server_service.dart';
import '../../services/notification_service.dart';
import '../../services/call_manager.dart';
import 'package:image_picker/image_picker.dart';
import '../../main.dart';
import '../../utils/debug_logger.dart';
import 'edit_server_screen.dart';
import 'channel_management_screen.dart';
import 'server_notification_settings_screen.dart';
import '../profile/user_profile_view.dart';
import '../media/media_viewer_screen.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class ServerChatScreen extends StatefulWidget {
  final ServerModel server;
  final String? defaultChannelId;

  const ServerChatScreen({
    super.key,
    required this.server,
    this.defaultChannelId,
  });

  @override
  State<ServerChatScreen> createState() => _ServerChatScreenState();
}

class _ServerChatScreenState extends State<ServerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _serverService = ServerService();
  final _searchController = TextEditingController();

  // Cache for user display names to avoid repeated queries
  final Map<String, String?> _userNameCache = {};
  final Map<String, String?> _userPhotoCache = {};

  // Channel management - now using Stream instead of manual list
  String? _selectedChannelId;

  // For reply feature
  ServerMessageModel? _replyingTo;

  // Pagination variables (kept for future use if needed)
  List<ServerMessageModel> _messages = [];
  bool _isLoadingMore = false;
  bool _hasLoadedInitialMessages = false;
  
  // Real-time streaming
  StreamSubscription<List<ServerMessageModel>>? _messagesStreamSubscription;

  // Search variables
  bool _isSearching = false;
  List<ServerMessageModel> _searchResults = [];

  // Voice recording variables
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  late Timer _recordingTimer;

  // Voice playback variables
  AudioPlayer? _audioPlayer;
  String? _currentPlayingMessageId;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _recordingTimer = Timer(Duration.zero, () {});
    _selectedChannelId = widget.defaultChannelId;
    NotificationService.setActiveServerChatId(widget.server.id);
    _initializeDefaultChannel();
    _setupMessageStream();
  }
  
  /// Setup real-time message streaming for server chat
  void _setupMessageStream() {
    if (_selectedChannelId == null) return;
    _messagesStreamSubscription?.cancel();
    
    debugPrint('🔄 Setting up server message stream for: ${widget.server.id}, channel: $_selectedChannelId');
    
    _messagesStreamSubscription = _serverService.getServerMessagesStream(
      widget.server.id,
      channelId: _selectedChannelId,
    ).listen(
      (streamMessages) {
        if (!mounted) return;
        
        debugPrint('📨 Server stream update: ${streamMessages.length} messages');
        
        final wasEmpty = _messages.isEmpty;
        
        setState(() {
          _messages = streamMessages;
          _hasLoadedInitialMessages = true;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || streamMessages.isEmpty) return;
          
          // Add delay to ensure ListView has finished building with new items
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted || !_scrollController.hasClients) return;
            
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.position.pixels;
            
            if (wasEmpty) {
              debugPrint('✅ Initial load - jumping to bottom (max: $maxScroll)');
              _scrollController.jumpTo(maxScroll);
            } else {
              // Only auto-scroll if user is near the bottom (within 200px)
              final isNearBottom = (maxScroll - currentScroll) < 200;
              if (isNearBottom) {
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
      },
      onError: (error) {
        debugPrint('❌ Error in server message stream: $error');
        DebugLogger.error('Server message stream error: $error', tag: 'SERVER_CHAT');
      },
    );
  }

  @override
  void dispose() {
    NotificationService.setActiveServerChatId(null);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _messagesStreamSubscription?.cancel();
    _recordingTimer.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (file == null) return;

      // Show uploading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Upload to Supabase storage
      debugPrint('Starting upload for server: ${widget.server.id}');
      final url = await _serverService.uploadServerFile(widget.server.id, file);

      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to upload image. Check console logs and ensure "server-media" bucket exists in Supabase Storage.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      debugPrint('Upload successful, URL: $url');

      // Send message referencing media
      final success = await _serverService.sendMessage(
        serverId: widget.server.id,
        content: '[Image]', // Add content since it's NOT NULL in DB
        messageType: 'image',
        mediaUrl: url,
        replyToMessageId: _replyingTo?.id,
        channelId: _selectedChannelId,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() => _replyingTo = null);
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send image message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Image pick/send error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.chatBackground,
          appBar: AppBar(
            backgroundColor: theme.cardBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
            title: Row(
              children: [
                // Server profile picture
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.squircle),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.squircle),
                    ),
                    child: widget.server.iconUrl != null && widget.server.iconUrl!.isNotEmpty
                        ? Image.network(
                            widget.server.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.dns_rounded,
                              size: 20,
                              color: theme.textPrimary,
                            ),
                          )
                        : Icon(
                            Icons.dns_rounded,
                            size: 20,
                            color: theme.textPrimary,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.server.name,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Channel selector with real-time updates
                      StreamBuilder<List<ServerChannelModel>>(
                        stream: _serverService.getServerChannelsStream(
                          widget.server.id,
                        ),
                        builder: (context, snapshot) {
                          final channels = snapshot.data ?? [];

                          // Update selected channel if it was deleted
                          if (_selectedChannelId != null &&
                              channels.isNotEmpty) {
                            final stillExists = channels.any(
                              (c) => c.id == _selectedChannelId,
                            );
                            if (!stillExists) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _selectedChannelId = channels.first.id;
                                  });
                                }
                              });
                            }
                          } else if (_selectedChannelId == null &&
                              channels.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedChannelId = channels.first.id;
                                });
                              }
                            });
                          }

                          return channels.isEmpty
                              ? Text(
                                  '${widget.server.memberCount} members',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.textSecondary,
                                  ),
                                )
                              : DropdownButton<String>(
                                  value: _selectedChannelId,
                                  underline: const SizedBox.shrink(),
                                  isDense: true,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.textSecondary,
                                  ),
                                  dropdownColor: theme.cardBackground,
                                  items: channels.map((channel) {
                                    return DropdownMenuItem<String>(
                                      value: channel.id,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            channel.channelType == 'voice'
                                                ? Icons.volume_up_rounded
                                                : channel.channelType ==
                                                      'announcements'
                                                ? Icons.notifications
                                                : Icons.tag,
                                            size: 14,
                                            color: theme.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(channel.name),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _changeChannel(value);
                                      _clearSearch();
                                    }
                                  },
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Audio call button
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: _selectedChannelId != null
                    ? () => CallManager().startServerCall(
                        context: context,
                        serverId: widget.server.id,
                        serverName: widget.server.name,
                        channelId: _selectedChannelId!,
                        channelName: 'Audio Chat',
                        userName:
                            supabase
                                .auth
                                .currentUser
                                ?.userMetadata?['full_name'] ??
                            'User',
                        isVideo: false,
                      )
                    : null,
              ),
              // Video call button
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: _selectedChannelId != null
                    ? () => CallManager().startServerCall(
                        context: context,
                        serverId: widget.server.id,
                        serverName: widget.server.name,
                        channelId: _selectedChannelId!,
                        channelName: 'Video Chat',
                        userName:
                            supabase
                                .auth
                                .currentUser
                                ?.userMetadata?['full_name'] ??
                            'User',
                        isVideo: true,
                      )
                    : null,
              ),
              // Search button
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: theme.textPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _clearSearch();
                    }
                  });
                },
              ),
              // Add a PopupMenuButton for server settings
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final localContext = context;
                  if (value == 'edit_server') {
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      localContext,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditServerScreen(server: widget.server),
                      ),
                    );
                  } else if (value == 'manage_channels') {
                    // ignore: use_build_context_synchronously
                    await Navigator.push(
                      localContext,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChannelManagementScreen(server: widget.server),
                      ),
                    );
                    // Reload channels when returning (in case channels were added/deleted)
                    if (mounted) {
                      await _loadChannels();
                    }
                  } else if (value == 'notification_settings') {
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      localContext,
                      MaterialPageRoute(
                        builder: (context) => ServerNotificationSettingsScreen(
                          server: widget.server,
                        ),
                      ),
                    );
                  } else if (value == 'toggle_notifications') {
                    final success = await _serverService
                        .toggleServerNotifications(widget.server.id);
                    if (!mounted) return;
                    final enabled = await _serverService
                        .areNotificationsEnabled(widget.server.id);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(localContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Notifications ${enabled ? 'enabled' : 'muted'}'
                              : 'Failed to update notifications',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'manage_channels',
                    child: Row(
                      children: [
                        Icon(Icons.tag, size: 18),
                        SizedBox(width: 8),
                        Text('Manage Channels'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'toggle_notifications',
                    child: Row(
                      children: [
                        Icon(Icons.notifications_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Mute/Unmute'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'notification_settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Notification Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'edit_server',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Server'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              if (_isSearching)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.cardBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: theme.textSecondary.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(Icons.search, color: theme.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: theme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                _searchMessages('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: BorderSide(
                          color: theme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: BorderSide(
                          color: theme.primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.chatBackground,
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: theme.textPrimary,
                    ),
                    onChanged: _searchMessages,
                  ),
                ),
              // Messages list
              Expanded(
                child: _isSearching && _searchResults.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final message = _searchResults[index];
                          final isCurrentUser =
                              message.userId == supabase.auth.currentUser?.id;

                          return _buildMessageBubble(
                            theme,
                            message,
                            isCurrentUser,
                          );
                        },
                      )
                    : _isSearching && _searchController.text.isNotEmpty
                        ? Center(
                            child: Text(
                              'No messages found',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: theme.textSecondary,
                              ),
                            ),
                          )
                        : _buildChannelMessages(theme),
              ),

              // Input area
              _buildInputArea(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    dynamic theme,
    ServerMessageModel message,
    bool isCurrentUser,
  ) {
    double horizontalDrag = 0;
    var swipeHandled = false;

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          horizontalDrag = 0;
          swipeHandled = false;
        },
        onHorizontalDragUpdate: (details) {
          if (swipeHandled) return;
          horizontalDrag += details.primaryDelta ?? 0;
          if (horizontalDrag > 60) {
            swipeHandled = true;
            _setReplyingToMessage(message);
          }
        },
        onHorizontalDragEnd: (_) {
          horizontalDrag = 0;
          swipeHandled = false;
        },
        onHorizontalDragCancel: () {
          horizontalDrag = 0;
          swipeHandled = false;
        },
        onLongPress: () async {
          final localContext = context;
          final currentUserId = supabase.auth.currentUser?.id;
          final isAdmin = await _serverService.isUserAdmin(widget.server.id);
          if (!mounted) return;
          final canDelete =
              isCurrentUser ||
              (isAdmin &&
                  currentUserId != null &&
                  currentUserId != message.userId);

          // Show popup menu with Reply and Delete options
          final selected = await showDialog<String>(
            // ignore: use_build_context_synchronously
            context: localContext,
                builder: (dialogContext) => AlertDialog(
              title: const Text('Message options'),
              content: const Text('What would you like to do?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'react'),
                  child: const Text('React'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'reply'),
                  child: const Text('Reply'),
                ),
                if (canDelete)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, 'delete'),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );

          if (!mounted) return;

                    if (selected == 'react') {
            _showEmojiPicker(message.id);
          } else if (selected == 'reply') {
            _setReplyingToMessage(message);
          } else if (selected == 'delete') {
            final confirmed = await showDialog<bool>(
              // ignore: use_build_context_synchronously
              context: localContext,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Delete message'),
                content: const Text(
                  'Are you sure you want to delete this message?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

                    if (confirmed == true) {
              final ok = await _serverService.deleteMessage(message.id);
              if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(localContext).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Message deleted' : 'Failed to delete'),
                  backgroundColor: ok ? theme.primaryColor : Colors.red,
                ),
              );
            }
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show sender info and avatar for all users (Discord style - always on left)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<String?>(
                    future: _getUserPhoto(message.userId),
                    builder: (context, photoSnapshot) {
                      final photoUrl = photoSnapshot.data;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.primaryColor.withOpacity(
                          0.3,
                        ),
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Icon(
                                Icons.person,
                                size: 14,
                                color: theme.primaryColor,
                              )
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Username + timestamp on same line
                        Row(
                          children: [
                            FutureBuilder<String?>(
                              future: _getUserName(message.userId),
                              builder: (context, snapshot) {
                                final userName =
                                    snapshot.data ?? 'Unknown User';
                                // Color current user differently
                                final isCurrentUser =
                                    message.userId ==
                                    supabase.auth.currentUser?.id;
                                return GestureDetector(
                                  onTap: !isCurrentUser
                                      ? () => _showUserProfile(message.userId)
                                      : null,
                                  child: Text(
                                    userName,
                                    style: AppTextStyles.caption.copyWith(
                                      color: isCurrentUser
                                          ? theme.primaryColor
                                          : theme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      decoration: !isCurrentUser
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              _formatTimestamp(message.createdAt),
                              style: AppTextStyles.caption.copyWith(
                                color: theme.textSecondary.withOpacity(
                                  0.6,
                                ),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Message content (with reply quote if applicable)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md + 32 + AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replied message header (Discord style - shows who it's replying to)
                  if (message.repliedTo != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply,
                          size: 12,
                          color: theme.primaryColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          message.repliedTo!.senderName,
                          style: AppTextStyles.caption.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Quoted message preview
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.background.withOpacity(0.6),
                        border: Border(
                          left: BorderSide(
                            color: theme.primaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show quoted message with image preview if applicable
                          if (message.repliedTo!.messageType == 'image' &&
                              (message.repliedTo!.mediaUrl?.isNotEmpty ??
                                  false)) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: Image.network(
                                    message.repliedTo!.mediaUrl!,
                                    height: 50,
                                    width: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    message.repliedTo!.content.isEmpty
                                        ? '[Image]'
                                        : message.repliedTo!.content.length > 60
                                        ? '${message.repliedTo!.content.substring(0, 60)}...'
                                        : message.repliedTo!.content,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: theme.textSecondary
                                          .withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              message.repliedTo!.content.length > 80
                                  ? '${message.repliedTo!.content.substring(0, 80)}...'
                                  : message.repliedTo!.content,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: theme.textSecondary.withOpacity(
                                  0.8,
                                ),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Actual message content
                  if (message.messageType == 'image' &&
                      (message.mediaUrl?.isNotEmpty ?? false)) ...[
                    GestureDetector(
                      onTap: () => _openServerMedia(message),
                      child: Hero(
                        tag: 'server_media_${message.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          child: Image.network(
                            message.mediaUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.messageType == 'video' &&
                      (message.mediaUrl?.isNotEmpty ?? false)) ...[
                    GestureDetector(
                      onTap: () => _openServerMedia(message),
                      child: Hero(
                        tag: 'server_media_${message.id}',
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            color: Colors.black,
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor.withOpacity(0.4),
                                  Colors.black.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.play_circle_outline,
                              color: theme.textPrimary,
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Voice message
                  if (message.messageType == 'audio' &&
                      (message.mediaUrl?.isNotEmpty ?? false)) ...[
                    _buildVoiceMessageWidget(message, theme),
                  ],
                  // Text message
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            // Reactions row
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                left: AppSpacing.md + 32 + AppSpacing.sm,
              ),
              child: FutureBuilder<Map<String, List<String>>>(
                future: _serverService.getReactionsSummary(message.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final reactions = snapshot.data!;
                  return Wrap(
                    spacing: 4,
                    children: reactions.entries.map((entry) {
                      final emoji = entry.key;
                      final userIds = entry.value;
                      final hasUserReacted = userIds.contains(
                        supabase.auth.currentUser?.id,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (hasUserReacted) {
                            _serverService.removeReaction(
                              messageId: message.id,
                              emoji: emoji,
                            );
                          } else {
                            _serverService.addReaction(
                              messageId: message.id,
                              emoji: emoji,
                            );
                          }
                          // Trigger rebuild
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: hasUserReacted
                                ? theme.primaryColor.withOpacity(0.2)
                                : theme.cardBackground,
                            border: Border.all(
                              color: hasUserReacted
                                  ? theme.primaryColor
                                  : theme.textSecondary.withOpacity(0.2),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '${userIds.length}',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getUserName(String userId) async {
    // Check cache first
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId];
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('display_name, profile_photo_url')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final displayName = response['display_name'] as String?;
        final photoUrl = response['profile_photo_url'] as String?;

        // Cache the results
        _userNameCache[userId] = displayName;
        _userPhotoCache[userId] = photoUrl;

        return displayName;
      }
    } catch (e) {
      DebugLogger.error('Error fetching user info: $e', tag: 'SERVER_CHAT');
    }

    // Cache null result to avoid repeated failed queries
    _userNameCache[userId] = null;
    _userPhotoCache[userId] = null;
    return null;
  }

  Future<String?> _getUserPhoto(String userId) async {
    // Check cache first (populated by _getUserName)
    if (_userPhotoCache.containsKey(userId)) {
      return _userPhotoCache[userId];
    }

    // If not in cache, fetch it via _getUserName to populate both caches
    await _getUserName(userId);
    return _userPhotoCache[userId];
  }

  void _showEmojiPicker(String messageId) {
    // Common emoji reactions
    final emojis = [
      '👍',
      '❤️',
      '😂',
      '😮',
      '😢',
      '🔥',
      '✨',
      '👏',
      '🎉',
      '💯',
      '🤔',
      '👌',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add reaction'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _serverService.addReaction(messageId: messageId, emoji: emoji);
                Navigator.pop(context);
                setState(() {}); // Trigger rebuild to show reaction
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea(dynamic theme) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardBackground.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: theme.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reply preview
                if (_replyingTo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    margin: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      border: Border(
                        left: BorderSide(color: theme.primaryColor, width: 3),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FutureBuilder<String?>(
                                future: _getUserName(_replyingTo!.userId),
                                builder: (context, snapshot) {
                                  final userName =
                                      snapshot.data ?? 'Unknown User';
                                  return Text(
                                    'Replying to $userName',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _replyingTo!.content.length > 50
                                    ? '${_replyingTo!.content.substring(0, 50)}...'
                                    : _replyingTo!.content,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: theme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.textSecondary,
                          ),
                          onPressed: () => setState(() => _replyingTo = null),
                        ),
                      ],
                    ),
                  ),
                ],
                // Input row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.background,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: theme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message ${widget.server.name}...',
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
                            onSubmitted: (value) {
                              _sendMessage(value);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Voice note button or recording indicator
                      if (!_isRecording)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: theme.background,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.mic_none_rounded,
                              color: theme.primaryColor,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _startRecording();
                            },
                            tooltip: 'Record voice note',
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              Icon(Icons.mic, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_recordingDuration),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      // Image picker button
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.background,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.photo_camera_rounded,
                            color: theme.primaryColor,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _pickAndSendImage();
                          },
                        ),
                      ),
                      // Send button or stop recording button
                      if (!_isRecording)
                        Container(
                          decoration: BoxDecoration(
                            gradient: theme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: theme.textPrimary,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _sendMessage(_messageController.text);
                            },
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red, Colors.red.shade700],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: theme.textPrimary,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              _stopRecordingAndSend();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelMessages(dynamic theme) {
    if (_selectedChannelId == null) {
      return Center(
        child: Text(
          'Select a channel to start chatting',
          style: AppTextStyles.bodyMedium.copyWith(
            color: theme.textSecondary,
          ),
        ),
      );
    }

    if (!_hasLoadedInitialMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: theme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No messages yet',
              style: AppTextStyles.heading3.copyWith(
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start the conversation!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: theme.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoadingMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading older messages...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final message = _messages[index];
        final isCurrentUser =
            message.userId == supabase.auth.currentUser?.id;

        return _buildMessageBubble(
          theme,
          message,
          isCurrentUser,
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfileView(userId: userId)),
    );
  }

  Future<void> _initializeDefaultChannel() async {
    if (_selectedChannelId != null) return;
    await _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await _serverService.getServerChannels(widget.server.id);
      if (!mounted) return;

      if (channels.isEmpty) {
        _messagesStreamSubscription?.cancel();
        setState(() {
          _selectedChannelId = null;
          _messages = [];
          _hasLoadedInitialMessages = false;
        });
        return;
      }

      final stillValid = channels.any((channel) => channel.id == _selectedChannelId);
      if (stillValid) return;

      final preferredChannelId = widget.defaultChannelId;
      final newChannelId = preferredChannelId != null &&
              channels.any((channel) => channel.id == preferredChannelId)
          ? preferredChannelId
          : channels.first.id;

      _messagesStreamSubscription?.cancel();
      setState(() {
        _selectedChannelId = newChannelId;
        _messages = [];
        _hasLoadedInitialMessages = false;
      });
      _setupMessageStream();
    } catch (e) {
      DebugLogger.error('Failed to load channels: $e', tag: 'SERVER_CHAT');
    }
  }

  void _changeChannel(String channelId) {
    if (channelId == _selectedChannelId) return;
    _messagesStreamSubscription?.cancel();
    setState(() {
      _selectedChannelId = channelId;
      _messages = [];
      _hasLoadedInitialMessages = false;
    });
    _setupMessageStream();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _searchMessages(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final results = _messages.where((message) {
      final contentMatch = message.content.toLowerCase().contains(normalizedQuery);
      final replyContent = message.repliedTo?.content;
      final replyMatch = replyContent?.toLowerCase().contains(normalizedQuery) ?? false;
      return contentMatch || replyMatch;
    }).toList();

    setState(() => _searchResults = results);
  }

  void _setReplyingToMessage(ServerMessageModel message) {
    setState(() => _replyingTo = message);
    _scrollToBottom();
  }

  /// Start recording voice note
  Future<void> _startRecording() async {
    try {
      // Check permission first
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final filePath = '${dir.path}/$fileName';

        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000, // 128 kbps
            sampleRate: 44100,
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        // Update timer every 100ms
        _recordingTimer = Timer.periodic(Duration(milliseconds: 100), (_) {
          if (mounted) {
            setState(() {
              _recordingDuration += Duration(milliseconds: 100);
            });
          }
        });

        debugPrint('✅ Recording started');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// Stop recording and send voice message
  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer.cancel();

      if (path == null) throw Exception('No recording file');

      setState(() {
        _isRecording = false;
      });

      if (!mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sending voice message...'),
          content: const CircularProgressIndicator(),
        ),
      );

      // Send voice message
      final file = File(path);
      final success = await _serverService.sendVoiceMessage(
        serverId: widget.server.id,
        voiceFile: file,
        channelId: _selectedChannelId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Voice message sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() => _replyingTo = null);
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
        // Delete temp file
        try {
          await file.delete();
        } catch (_) {}
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to send voice message')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _selectedChannelId == null) return;

    final replyId = _replyingTo?.id;
    _messageController.clear();

    final success = await _serverService.sendMessage(
      serverId: widget.server.id,
      content: content,
      channelId: _selectedChannelId,
      replyToMessageId: replyId,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _replyingTo = null);
      Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  void _openServerMedia(ServerMessageModel message) {
    final mediaUrl = message.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    final viewerType = message.messageType == 'video'
        ? MediaViewerType.video
        : MediaViewerType.image;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          mediaUrl: mediaUrl,
          type: viewerType,
          heroTag: 'server_media_${message.id}',
          caption: message.content.isNotEmpty ? message.content : null,
        ),
      ),
    );
  }

  /// Build voice message player widget
  Widget _buildVoiceMessageWidget(ServerMessageModel message, dynamic theme) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
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
          const SizedBox(width: 12),
          // Waveform or progress indicator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎙️ Voice Message',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Download button
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              size: 18,
              color: theme.primaryColor,
            ),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⬇️ Download feature coming soon!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
