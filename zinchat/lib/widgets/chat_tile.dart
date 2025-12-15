import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/chat_model.dart';
import '../screens/media/media_viewer_screen.dart';
import '../utils/constants.dart';
import '../utils/string_sanitizer.dart';
import '../providers/theme_provider.dart';

// Card-style chat tile with expressive design
class ChatTile extends StatefulWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chat,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: AppAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildChatTile(context, theme);
      },
    );
  }

  Widget _buildChatTile(BuildContext context, dynamic theme) {
    final otherUser = widget.chat.otherUser;
    final lastMessage = widget.chat.lastMessage;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              _scaleController.forward();
            },
            onTapUp: (_) {
              _scaleController.reverse();
              widget.onTap();
            },
            onTapCancel: () {
              _scaleController.reverse();
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _scaleController.reverse();
              widget.onLongPress?.call();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.large),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Squircle avatar with magenta border
                  GestureDetector(
                    onTap: () {
                      final photoUrl = otherUser?.profilePhotoUrl;
                      if (photoUrl == null || photoUrl.isEmpty) {
                        return;
                      }
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MediaViewerScreen(
                            mediaUrl: photoUrl,
                            type: MediaViewerType.image,
                            caption: otherUser?.displayName ?? 'Profile Picture',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.squircle),
                        border: Border.all(
                          color: widget.chat.unreadCount > 0
                              ? theme.secondaryColor
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: widget.chat.unreadCount > 0
                            ? [
                                BoxShadow(
                                  color: theme.secondaryColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.squircle),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: theme.primaryColor.withOpacity(0.2),
                          child: otherUser?.profilePhotoUrl != null
                              ? Image.network(
                                  otherUser!.profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    StringSanitizer.getFirstCharacter(otherUser?.displayName ?? ''),
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: AppSpacing.sm),
                  
                  // Chat info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User name
                        Text(
                          otherUser?.displayName ?? 'Unknown User',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: widget.chat.unreadCount > 0 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 2),
                        
                        // Last message
                        if (lastMessage != null)
                        Text(
                          _getMessagePreview(lastMessage.content, lastMessage.messageType),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: widget.chat.unreadCount > 0
                                ? theme.textPrimary
                                : theme.textSecondary,
                            fontWeight: widget.chat.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Time and unread badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Time
                      if (lastMessage != null)
                        Text(
                          timeago.format(lastMessage.createdAt, locale: 'en_short'),
                          style: AppTextStyles.caption.copyWith(
                            color: widget.chat.unreadCount > 0
                                ? theme.primaryColor
                                : theme.textSecondary,
                          ),
                        ),
                      
                      const SizedBox(height: 2),
                      
                      // Unread count badge with theme color
                      if (widget.chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            widget.chat.unreadCount > 99 
                                ? '99+' 
                                : '${widget.chat.unreadCount}',
                            style: TextStyle(
                              color: theme.background,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getMessagePreview(String content, String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Voice message';
      case 'file':
        return '📎 File';
      default:
        return content;
    }
  }
}