import 'package:flutter/material.dart';
import '../../models/status_model.dart';
import '../../services/ad_story_integration_service.dart';
import '../../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'status_viewer_screen.dart';

/// Vertical list of status groups (shown when tapping > button)
/// Similar to Instagram stories list view
class StatusListScreen extends StatefulWidget {
  final List<UserStatusGroup>? allGroups;
  final int? initialIndex;
  final String? initialStatusId; // For navigation from notifications

  const StatusListScreen({
    super.key,
    this.allGroups,
    this.initialIndex,
    this.initialStatusId,
  });

  @override
  State<StatusListScreen> createState() => _StatusListScreenState();
}

class _StatusListScreenState extends State<StatusListScreen> {
  late ScrollController _scrollController;
  final _adIntegrationService = AdStoryIntegrationService();
  List<UserStatusGroup> _displayGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // If called with initialStatusId (from notification), don't load groups
    if (widget.initialStatusId != null) {
      // Just mark as loaded, the status is fetched elsewhere
      _isLoading = false;
    } else {
      // Normal case - load ad and prepare groups
      _loadAdAndPrepareGroups();
      
      // Scroll to initial group if provided
      if (widget.initialIndex != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              widget.initialIndex! * 100.0, // Approximate item height
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  Future<void> _loadAdAndPrepareGroups() async {
    // Always inject ad story (loads in background)
    final adStory = await _adIntegrationService.loadAdStory();
    if (mounted) {
      setState(() {
        _displayGroups = _adIntegrationService.injectAdIntoStatusGroups(
          widget.allGroups ?? [],
          adStory,
        );
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialStatusId != null) {
      // This shouldn't happen - navigation should go directly to StatusRepliesScreen
      // But handle gracefully just in case
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Status'),
          elevation: 0,
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: Text('Loading status...'),
        ),
      );
    }

    final groups = _displayGroups.isEmpty ? (widget.allGroups ?? []) : _displayGroups;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stories'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final hasUnviewedStories = !group.hasViewed;
          final isAdGroup = group.user.id == 'sponsored';

          return GestureDetector(
            onTap: () async {
              // If it's an ad group, show the ad
              if (isAdGroup) {
                await _adIntegrationService.showAdStory();
                return;
              }
              
              // Open story viewer at this group
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatusViewerScreen(
                    initialGroup: group,
                    allGroups: groups,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Avatar with ring indicator
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasUnviewedStories
                                ? AppColors.electricTeal
                                : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: isAdGroup
                              ? Container(
                                  color: AppColors.electricTeal.withOpacity(0.2),
                                  child: const Icon(
                                    Icons.campaign,
                                    color: AppColors.electricTeal,
                                    size: 28,
                                  ),
                                )
                              : group.user.profilePhotoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: group.user.profilePhotoUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const Icon(Icons.person),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.person),
                                )
                              : Container(
                                  color: AppColors.cardBackground,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      // Unviewed indicator dot
                      if (hasUnviewedStories)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.electricTeal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // User info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.user.displayName,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(group.statuses.last.createdAt),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Story count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.electricTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${group.statuses.length}',
                      style: const TextStyle(
                        color: AppColors.electricTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
