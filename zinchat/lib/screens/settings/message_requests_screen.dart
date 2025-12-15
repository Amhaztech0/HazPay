import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../utils/constants.dart';
import '../../services/privacy_service.dart';
import '../../services/chat_service.dart';
import '../../models/message_request_model.dart';
import '../chat/chat_screen.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final _privacyService = PrivacyService();
  final _chatService = ChatService();
  List<MessageRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    
    try {
      final requests = await _privacyService.getPendingMessageRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(MessageRequest request) async {
    final success = await _privacyService.acceptMessageRequest(request.id);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accepted request from ${request.sender?.displayName ?? 'user'}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      // Open chat with the user
      try {
        final chat = await _chatService.getOrCreateChat(request.senderId);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chat.id,
                otherUser: request.sender!,
              ),
            ),
          );
        }
      } catch (e) {
        _loadRequests();
      }
    }
  }

  Future<void> _rejectRequest(MessageRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text(
          'Reject message request from ${request.sender?.displayName ?? 'this user'}?',
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _privacyService.rejectMessageRequest(request.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected request from ${request.sender?.displayName ?? 'user'}'),
            backgroundColor: AppColors.saturatedMagenta,
          ),
        );
        _loadRequests();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Requests'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: AppColors.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _requests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      final user = request.sender;

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(AppRadius.large),
                          border: Border.all(
                            color: AppColors.electricTeal.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.all(AppSpacing.md),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primaryLight,
                                backgroundImage: user?.profilePhotoUrl != null
                                    ? NetworkImage(user!.profilePhotoUrl!)
                                    : null,
                                child: user?.profilePhotoUrl == null
                                    ? Text(
                                        user?.displayName.isNotEmpty == true
                                            ? user!.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user?.displayName ?? 'Unknown User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.about ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(request.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _rejectRequest(request),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.saturatedMagenta,
                                        side: BorderSide(
                                          color: AppColors.saturatedMagenta,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.md,
                                        ),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _acceptRequest(request),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.md,
                                        ),
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message_outlined,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Message Requests',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Message requests from new users will appear here',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
