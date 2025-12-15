import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../services/chat_service.dart';
import '../../services/privacy_service.dart';
import '../../main.dart';
import '../chat/chat_screen.dart';

/// Professional, interactive user profile view screen
/// Displays detailed user information with smooth animations and beautiful UI
class UserProfileViewScreen extends StatefulWidget {
  final UserModel user;
  final bool showChatButton;

  const UserProfileViewScreen({
    super.key,
    required this.user,
    this.showChatButton = true,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen>
    with SingleTickerProviderStateMixin {
  final _chatService = ChatService();
  final _privacyService = PrivacyService();
  final _currentUserId = supabase.auth.currentUser!.id;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadUserStatus();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  Future<void> _loadUserStatus() async {
    try {
      final blocked = await _privacyService.isUserBlocked(widget.user.id);
      if (mounted) {
        setState(() {
          _isBlocked = blocked;
        });
      }
    } catch (e) {
      // Error loading status, continue with defaults
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openChat() async {
    try {
      // Get or create chat
      final chat = await _chatService.getOrCreateChat(widget.user.id);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              otherUser: widget.user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBlock() async {
    final bool willBlock = !_isBlocked;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        title: Text(willBlock ? 'Block User?' : 'Unblock User?'),
        content: Text(
          willBlock
              ? 'You won\'t be able to send or receive messages from ${widget.user.displayName}.'
              : 'You will be able to send and receive messages from ${widget.user.displayName} again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: willBlock ? Colors.red : AppColors.primaryGreen,
            ),
            child: Text(willBlock ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = willBlock
          ? await _privacyService.blockUser(widget.user.id)
          : await _privacyService.unblockUser(widget.user.id);

      if (success && mounted) {
        setState(() => _isBlocked = willBlock);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willBlock
                  ? 'Blocked ${widget.user.displayName}'
                  : 'Unblocked ${widget.user.displayName}',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    }
  }

  void _copyPhoneNumber() {
    if (widget.user.phoneNumber != null) {
      Clipboard.setData(ClipboardData(text: widget.user.phoneNumber!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.user.id == _currentUserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Profile Photo
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!isOwnProfile)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  onSelected: (value) {
                    if (value == 'block') {
                      _toggleBlock();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            _isBlocked ? Icons.check_circle : Icons.block,
                            color: _isBlocked
                                ? AppColors.primaryGreen
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isBlocked
                                ? 'Unblock ${widget.user.displayName}'
                                : 'Block ${widget.user.displayName}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile Photo or Gradient Background
                  widget.user.profilePhotoUrl != null
                      ? Hero(
                          tag: 'profile_${widget.user.id}',
                          child: CachedNetworkImage(
                            imageUrl: widget.user.profilePhotoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryGreen.withOpacity(0.8),
                                    AppColors.background,
                                  ],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                _buildGradientBackground(),
                          ),
                        )
                      : _buildGradientBackground(),
                  
                  // Gradient overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  
                  // User Initial if no photo
                  if (widget.user.profilePhotoUrl == null)
                    Center(
                      child: Text(
                        widget.user.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    
                    // Name and Status
                    _buildNameSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    if (!isOwnProfile && widget.showChatButton)
                      _buildActionButtons(),
                    
                    const SizedBox(height: 16),
                    
                    // Info Cards
                    _buildInfoSection(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen.withOpacity(0.8),
            AppColors.background,
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Display Name
          Text(
            widget.user.displayName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Online Status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.user.isOnline
                      ? AppColors.online
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.user.isOnline ? 'Online' : widget.user.lastSeenText,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.user.isOnline
                      ? AppColors.online
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Message Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isBlocked ? null : _openChat,
              icon: const Icon(Icons.message_rounded),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                elevation: 2,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Voice Call Button (Coming Soon)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice call coming soon!')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              child: const Icon(Icons.call),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Video Call Button (Coming Soon)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call coming soon!')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              child: const Icon(Icons.videocam),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // About Section
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'About',
          content: widget.user.about,
          showDivider: true,
        ),
        
        // Phone Number Section
        if (widget.user.phoneNumber != null)
          _buildInfoCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            content: widget.user.phoneNumber!,
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              color: AppColors.primaryGreen,
              onPressed: _copyPhoneNumber,
              tooltip: 'Copy phone number',
            ),
            showDivider: true,
          ),
        
        // Joined Date Section
        _buildInfoCard(
          icon: Icons.calendar_today_outlined,
          title: 'Joined',
          content: _formatJoinedDate(widget.user.createdAt),
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    Widget? trailing,
    bool showDivider = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Trailing widget
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  String _formatJoinedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'Joined today';
    } else if (difference.inDays < 7) {
      return 'Joined ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Joined $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Joined $months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Joined $years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}
