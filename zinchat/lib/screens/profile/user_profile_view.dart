import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';
import '../../main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';

class UserProfileView extends StatefulWidget {
  final String userId;
  
  const UserProfileView({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  late Future<UserModel?> _userFuture;
  
  @override
  void initState() {
    super.initState();
    _userFuture = _fetchUser();
  }
  
  Future<UserModel?> _fetchUser() async {
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();
      
      if (response != null) {
        return UserModel.fromJson(response);
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;
        final isCurrentUser = widget.userId == supabase.auth.currentUser?.id;
        
        return FutureBuilder<UserModel?>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: theme.chatBackground,
                appBar: AppBar(
                  backgroundColor: theme.cardBackground,
                  leading: IconButton(
                    icon: Icon(Icons.close, color: theme.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: Center(
                  child: CircularProgressIndicator(color: theme.primaryColor),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data == null) {
              return Scaffold(
                backgroundColor: theme.chatBackground,
                appBar: AppBar(
                  backgroundColor: theme.cardBackground,
                  leading: IconButton(
                    icon: Icon(Icons.close, color: theme.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off_rounded,
                        size: 64,
                        color: theme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'User not found',
                        style: AppTextStyles.heading3.copyWith(
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            final user = snapshot.data!;
            
            return Scaffold(
              backgroundColor: theme.chatBackground,
              appBar: AppBar(
                backgroundColor: theme.cardBackground,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close, color: theme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Profile',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // Hero section with gradient background
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: theme.primaryGradient,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          // Avatar
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: user.profilePhotoUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: user.profilePhotoUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Icon(Icons.person, size: 50, color: Colors.white),
                                      errorWidget: (context, url, error) =>
                                          Icon(Icons.person, size: 50, color: Colors.white),
                                    )
                                  : Container(
                                      color: theme.cardBackground,
                                      child: Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Name
                          Text(
                            user.displayName,
                            style: AppTextStyles.heading2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Bio/About
                          if (user.about.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Text(
                                user.about,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    
                    // Content section
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.cardBackground,
                              borderRadius: BorderRadius.circular(AppRadius.large),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: user.isOnline ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      user.isOnline ? 'Online' : 'Offline',
                                      style: AppTextStyles.caption.copyWith(
                                        color: user.isOnline ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  user.lastSeenText,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          // User info cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  theme,
                                  Icons.phone,
                                  'Phone',
                                  user.phoneNumber ?? 'Not set',
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _buildInfoCard(
                                  theme,
                                  Icons.calendar_today,
                                  'Joined',
                                  _formatDate(user.createdAt),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          // Action buttons
                          if (!isCurrentUser) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    theme,
                                    Icons.message_rounded,
                                    'Message',
                                    () => _openDirectMessage(user),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _buildActionButton(
                                    theme,
                                    Icons.block,
                                    'Block',
                                    () => _blockUser(user),
                                    isDestructive: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: _buildActionButton(
                                theme,
                                Icons.flag,
                                'Report User',
                                () => _reportUser(user),
                                isDestructive: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildInfoCard(dynamic theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.primaryColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(
    dynamic theme,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isDestructive ? Colors.red : theme.primaryColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive ? Colors.red : theme.primaryColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDestructive ? Colors.red : theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  void _openDirectMessage(UserModel user) {
    _openChat(user);
  }
  
  void _openChat(UserModel user) async {
    try {
      final chatService = ChatService();
      final chat = await chatService.getOrCreateChat(user.id);
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chat.id,
            otherUser: user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Error opening chat: $e');
    }
  }
  
  void _blockUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block user?'),
        content: Text('You will no longer receive messages or see content from ${user.displayName}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user.displayName} has been blocked'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _reportUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report user'),
        content: const Text('Why are you reporting this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report submitted. Thank you for helping keep our community safe.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}

