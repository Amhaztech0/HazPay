import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/status_model.dart';
import '../utils/constants.dart';
import '../utils/string_sanitizer.dart';
import '../screens/status/status_viewer_screen.dart';
import '../screens/status/create_status_screen.dart';
import '../main.dart';
import '../providers/theme_provider.dart';

class StatusList extends StatefulWidget {
  final List<UserStatusGroup> statusGroups;
  final VoidCallback onRefresh;

  const StatusList({
    super.key,
    required this.statusGroups,
    required this.onRefresh,
  });

  @override
  State<StatusList> createState() => _StatusListState();
}

class _StatusListState extends State<StatusList> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildStatusList(context, theme);
      },
    );
  }

  Widget _buildStatusList(BuildContext context, dynamic theme) {
    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: widget.statusGroups.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildMyStatusItem(context, theme);
          }
          final group = widget.statusGroups[index - 1];
          return _buildStatusItem(context, group, theme);
        },
      ),
    );
  }

  Widget _buildMyStatusItem(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateStatusScreen(),
            ),
          ).then((_) => widget.onRefresh());
        },
        child: SizedBox(
          width: 50,
          height: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.squircle),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.4),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.squircle - 1),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: theme.textSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        gradient: theme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: theme.cardBackground,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 50,
                child: Text(
                  'Your\nStory',
                  style: AppTextStyles.caption.copyWith(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 7,
                    height: 0.95,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, UserStatusGroup group, dynamic theme) {
    // Safety check for user data - sanitize for UTF-16 issues
    String displayName = StringSanitizer.sanitize(group.user.displayName);
    if (displayName.isEmpty) displayName = 'User';
    
    final initial = StringSanitizer.getFirstCharacter(displayName);

    // Check if this is current user's status
    final isOwnStatus = group.user.id == supabase.auth.currentUser!.id;
    final totalViews = group.statuses.fold<int>(0, (sum, status) => sum + status.viewCount);
    final hasUnviewed = !group.hasViewed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StatusViewerScreen(
                initialGroup: group,
                allGroups: widget.statusGroups,
              ),
            ),
          ).then((_) => widget.onRefresh());
        },
        child: SizedBox(
          width: 50,
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Animated gradient ring for unviewed statuses
                    hasUnviewed
                        ? AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: theme.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppRadius.squircle),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.primaryColor.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: _buildAvatarContent(group, initial, theme),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.squircle),
                              border: Border.all(
                                color: theme.textSecondary.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                            child: _buildAvatarContent(group, initial, theme),
                          ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 50,
                      child: Text(
                        displayName,
                        style: AppTextStyles.caption.copyWith(
                          color: hasUnviewed ? theme.textPrimary : theme.textSecondary,
                          fontWeight: hasUnviewed ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 7,
                          height: 0.95,
                        ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              // View count badge for own status
              if (isOwnStatus && totalViews > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      totalViews > 99 ? '99+' : totalViews.toString(),
                      style: AppTextStyles.caption.copyWith(
                        color: theme.cardBackground,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(UserStatusGroup group, String initial, dynamic theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.squircle - 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.squircle - 2),
        child: group.user.profilePhotoUrl != null
            ? Image.network(
                group.user.profilePhotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initial,
                    style: AppTextStyles.heading2.copyWith(
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initial,
                  style: AppTextStyles.heading2.copyWith(
                    color: theme.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}