import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/status_model.dart';
import '../../models/status_reply_model.dart';
import '../../services/status_reply_service.dart';
import '../../services/chat_service.dart';
import '../../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../main.dart';
import '../chat/chat_screen.dart';

class StatusRepliesScreen extends StatefulWidget {
  final StatusUpdate status;

  const StatusRepliesScreen({
    super.key,
    required this.status,
  });

  @override
  State<StatusRepliesScreen> createState() => _StatusRepliesScreenState();
}

class _StatusRepliesScreenState extends State<StatusRepliesScreen> {
  final _replyService = StatusReplyService();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _replyFocusNode;
  
  // For tracking which reply user is replying to
  StatusReply? _replyingTo;
  
  @override
  void initState() {
    super.initState();
    _replyFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    HapticFeedback.lightImpact();
    _replyController.clear();
    
    final parentReplyId = _replyingTo?.id;
    _replyingTo = null; // Clear reply context

    try {
      await _replyService.sendReply(
        statusId: widget.status.id,
        content: content,
        parentReplyId: parentReplyId,
      );
      
      // Scroll to bottom to show new reply
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
      setState(() {}); // Update UI to clear reply context
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reply: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sendEmojiReply(String emoji) async {
    HapticFeedback.lightImpact();

    try {
      await _replyService.sendReply(
        statusId: widget.status.id,
        content: emoji,
        replyType: 'emoji',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reaction: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnStatus = widget.status.userId == supabase.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isOwnStatus ? 'Status Replies' : 'Reply to Status'),
        centerTitle: true,
        backgroundColor: theme.cardColor,
      ),
      body: Column(
        children: [
          // Status preview
          _buildStatusPreview(),

          // Quick emoji reactions
          if (!isOwnStatus) _buildQuickReactions(),

          Divider(height: 1, color: theme.dividerColor),

          // Replies list
          Expanded(
            child: StreamBuilder<List<StatusReply>>(
              stream: _replyService.getRepliesStream(widget.status.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading replies',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                    ),
                  );
                }

                final replies = snapshot.data ?? [];

                if (replies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isOwnStatus 
                              ? 'No replies yet' 
                              : 'Be the first to reply!',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    return _buildReplyTile(reply, isOwnStatus);
                  },
                );
              },
            ),
          ),

          // Reply input (only for viewing others' statuses)
          if (!isOwnStatus) _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildStatusPreview() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: theme.cardColor,
      child: Row(
        children: [
          // Status thumbnail
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              color: widget.status.mediaType == 'text'
                  ? _parseColor(widget.status.backgroundColor)
                  : theme.primaryColor,
            ),
            child: widget.status.mediaType == 'image' && widget.status.mediaUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: CachedNetworkImage(
                      imageUrl: widget.status.mediaUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Icon(
                      widget.status.mediaType == 'video'
                          ? Icons.videocam
                          : Icons.text_fields,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Status info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.status.user?.displayName ?? 'Unknown',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Show status content if it's a text status
                if (widget.status.mediaType == 'text' && 
                    widget.status.content != null && 
                    widget.status.content!.isNotEmpty) ...[
                  Text(
                    widget.status.content!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  timeago.format(widget.status.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReactions() {
    final theme = Theme.of(context);
    final emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: theme.cardColor,
      child: Row(
        children: emojis.map((emoji) {
          return Expanded(
            child: GestureDetector(
              onTap: () => _sendEmojiReply(emoji),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyTile(StatusReply reply, bool isOwnStatus) {
    final theme = Theme.of(context);
    final isCurrentUser = reply.userId == supabase.auth.currentUser!.id;
    final isThreaded = reply.parentReplyId != null;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppSpacing.md,
        left: isThreaded ? 40 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.primaryColor,
            backgroundImage: reply.user?.profilePhotoUrl != null
                ? NetworkImage(reply.user!.profilePhotoUrl!)
                : null,
            child: reply.user?.profilePhotoUrl == null
                ? Text(
                    reply.user?.displayName.isNotEmpty == true
                        ? reply.user!.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          
          // Reply content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isCurrentUser 
                    ? theme.primaryColor.withOpacity(0.1)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: isCurrentUser 
                    ? Border.all(color: theme.primaryColor.withOpacity(0.3))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show "Replying to <username>" if threaded
                  if (isThreaded && reply.parentReplyUsername != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        'Replying to ${reply.parentReplyUsername}',
                        style: AppTextStyles.caption.copyWith(
                          color: theme.primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Show parent content preview
                    if (reply.parentReplyContent != null && reply.parentReplyContent!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          border: Border(
                            left: BorderSide(
                              color: theme.primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          reply.parentReplyContent!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reply.user?.displayName ?? 'Unknown',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCurrentUser 
                                ? theme.primaryColor
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(reply.createdAt),
                        style: AppTextStyles.caption.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply.content,
                    style: reply.replyType == 'emoji'
                        ? const TextStyle(fontSize: 32)
                        : AppTextStyles.bodyMedium,
                  ),
                  
                  // Action buttons for status owner
                  if (isOwnStatus) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showReplyToReplyDialog(reply),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        GestureDetector(
                          onTap: () => _openDirectMessage(reply),
                          child: Row(
                            children: [
                              Icon(
                                Icons.message_rounded,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Message',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Reply button for non-status-owner
                  if (!isOwnStatus && !isCurrentUser) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingTo = reply;
                        });
                        _replyFocusNode.requestFocus();
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Direct message button (for others viewing their own reply)
          if (!isOwnStatus && isCurrentUser && reply.user != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              color: theme.primaryColor,
              onPressed: () async {
                try {
                  // Get or create chat first
                  final chatService = ChatService();
                  final chat = await chatService.getOrCreateChat(widget.status.userId);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chat.id,
                          otherUser: widget.status.user!,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to open chat: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show reply context if replying to someone
          if (_replyingTo != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.user?.displayName ?? 'Unknown'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingTo = null;
                      });
                    },
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  focusNode: _replyFocusNode,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: _replyingTo != null 
                        ? 'Reply to ${_replyingTo!.user?.displayName}...'
                        : 'Reply to status...',
                    hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              
              // Send button
              GestureDetector(
                onTap: _sendReply,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: theme.scaffoldBackgroundColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return AppColors.primaryGreen;
    }

    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _showReplyToReplyDialog(StatusReply originalReply) {
    final theme = Theme.of(context);
    final replyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Reply to comment', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalReply.user?.displayName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    originalReply.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: replyController,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                hintText: 'Write your response...',
                hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = replyController.text.trim();
              if (content.isEmpty) return;

              try {
                // Send the reply with reference to the original reply
                await _replyService.sendReply(
                  statusId: widget.status.id,
                  content: content,
                  parentReplyId: originalReply.id, // New field for threading
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Reply sent!'),
                      backgroundColor: theme.colorScheme.secondary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send reply: $e'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirectMessage(StatusReply reply) async {
    try {
      if (reply.user == null) return;
      
      final chatService = ChatService();
      final chat = await chatService.getOrCreateChat(reply.user!.id);
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              otherUser: reply.user!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}