import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../services/chat_service.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../chat/chat_screen.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final _chatService = ChatService();
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    
    final requests = await _chatService.getPendingMessageRequests();
    
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    }
  }

  /// Safe helper to get first character of a name
  String _getInitial(String? name) {
    if (name == null || name.isEmpty) {
      return '?';
    }
    return name[0].toUpperCase();
  }

  Future<void> _acceptRequest(String requestId, Map<String, dynamic> senderData) async {
    // Read theme before any async operations
    final theme = context.read<ThemeProvider>().currentTheme;
    
    try {
      final success = await _chatService.acceptMessageRequest(requestId);
      
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept request'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Message request accepted!'),
            backgroundColor: theme.primaryColor,
          ),
        );
      }
      
      // Navigate to chat with the sender
      final senderId = senderData['id'] as String;
      final sender = UserModel(
        id: senderId,
        displayName: senderData['display_name'] as String? ?? 'User',
        about: senderData['about'] as String? ?? 'Hey there! I am using ZinChat.',
        profilePhotoUrl: senderData['profile_photo_url'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final chat = await _chatService.getOrCreateChat(sender.id);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              otherUser: sender,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error accepting request: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    // Read theme before any async operations
    final theme = context.read<ThemeProvider>().currentTheme;
    
    try {
      final success = await _chatService.declineMessageRequest(requestId);
      
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to decline request'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Message request declined'),
            backgroundColor: theme.secondaryColor,
          ),
        );
      }
      
      // Refresh the list
      _loadRequests();
    } catch (e, stackTrace) {
      debugPrint('❌ Error declining request: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildRequestsScreen(context, theme);
      },
    );
  }

  Widget _buildRequestsScreen(BuildContext context, dynamic theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 80,
                        color: theme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No pending requests',
                        style: AppTextStyles.heading3.copyWith(
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'When someone sends you a message request,\nit will appear here',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _requests.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.greyLight,
                  ),
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final sender = request['sender'] as Map<String, dynamic>;
                    final requestId = request['id'] as String;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Profile photo
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: theme.primaryColor,
                                  backgroundImage: sender['profile_photo_url'] != null
                                      ? CachedNetworkImageProvider(
                                          sender['profile_photo_url'] as String,
                                        )
                                      : null,
                                  child: sender['profile_photo_url'] == null
                                      ? Text(
                                          _getInitial(sender['display_name'] as String?),
                                          style: TextStyle(
                                            fontSize: 24,
                                            color: theme.cardBackground,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                // User info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sender['display_name'] as String,
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (sender['about'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          sender['about'] as String,
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: theme.textSecondary,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _acceptRequest(requestId, sender),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primaryColor,
                                      foregroundColor: theme.cardBackground,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                      ),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _declineRequest(requestId),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.textSecondary,
                                      side: BorderSide(
                                        color: theme.greyLight,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                      ),
                                    ),
                                    child: const Text('Decline'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
