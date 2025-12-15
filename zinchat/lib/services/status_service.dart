import 'dart:io';
import '../main.dart';
import '../models/status_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';
import 'chat_service.dart';

class StatusService {
  final _storageService = StorageService();

  // Create text status
  Future<StatusUpdate?> createTextStatus({
    required String content,
    required String backgroundColor,
    String privacy = 'public',
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final data = await supabase.from('status_updates').insert({
        'user_id': currentUserId,
        'content': content,
        'media_type': 'text',
        'background_color': backgroundColor,
        'privacy': privacy,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      }).select().single();

      return StatusUpdate.fromJson(data);
    } catch (e) {
      print('Error creating text status: $e');
      return null;
    }
  }

  // Create media status (image or video)
  Future<StatusUpdate?> createMediaStatus({
    required File file,
    required String mediaType,
    String? caption,
    String privacy = 'public',
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Check file size
      final fileSizeMB = _storageService.getFileSizeInMB(file);
      if (fileSizeMB > 50) {
        throw Exception('File size must be less than 50MB');
      }

      // Upload to storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'status/$currentUserId/$timestamp';

      final mediaUrl = await _storageService.uploadFile(
        file: file,
        bucket: 'status-media',
        path: fileName,
      );

      if (mediaUrl == null) {
        throw Exception('Failed to upload media');
      }

      // Create status record
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final data = await supabase.from('status_updates').insert({
        'user_id': currentUserId,
        'content': caption,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'privacy': privacy,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      }).select().single();

      return StatusUpdate.fromJson(data);
    } catch (e) {
      print('Error creating media status: $e');
      return null;
    }
  }

  // Get all active statuses grouped by user
  Future<List<UserStatusGroup>> getAllStatuses() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        print('⚠️ No authenticated user, skipping status fetch');
        return [];
      }
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      print('🔍 Getting all statuses for user: $currentUserId');

      // Get statuses from the last 7 days (expanded window for testing)
      // CRITICAL: Filter by expires_at to respect 24-hour limit
      final statusesData = await supabase
          .from('status_updates')
          .select('''
            *,
            profiles:user_id (
              id,
              display_name,
              about,
              profile_photo_url,
              phone_number,
              created_at,
              updated_at
            ),
            status_views_count:status_views(count)
          ''')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .lte('created_at', now.toIso8601String())
          .gt('expires_at', now.toIso8601String()) // Only get non-expired statuses
          .order('created_at', ascending: false)
          .limit(200);

      print('📊 Loaded ${statusesData.length} statuses');

      if (statusesData.isEmpty) {
        print('⚠️ No statuses found in database');
        return [];
      }

      // Get only current user's viewed status IDs in one query
      final userViewsData = await supabase
          .from('status_views')
          .select('status_id')
          .eq('viewer_id', currentUserId)
          .limit(500);

      final viewedStatusIds = userViewsData.map((v) => v['status_id'] as String).toSet();

      // Group statuses by user
      final groupedStatuses = <String, List<StatusUpdate>>{};

      for (var statusData in statusesData) {
        final statusJson = Map<String, dynamic>.from(statusData);
        final profiles = statusJson.remove('profiles') as Map<String, dynamic>?;
        
        // Extract view count from the count result
        final viewCountList = statusJson.remove('status_views_count') as List?;
        final viewCount = (viewCountList?.isNotEmpty ?? false) 
            ? (viewCountList!.first['count'] as int?) ?? 0 
            : 0;

        final status = StatusUpdate.fromJson(statusJson);
        final userId = status.userId;
        final hasViewed = viewedStatusIds.contains(status.id);

        final statusWithData = status.copyWith(
          user: profiles != null ? UserModel.fromJson(profiles) : null,
          viewCount: viewCount,
          hasViewed: hasViewed,
        );

        if (!groupedStatuses.containsKey(userId)) {
          groupedStatuses[userId] = [];
        }
        groupedStatuses[userId]!.add(statusWithData);
      }

      // Create user status groups
      final groups = <UserStatusGroup>[];

      for (var entry in groupedStatuses.entries) {
        final statuses = entry.value;

        // Find user from first status
        final user = statuses.first.user;
        if (user != null) {
          final hasViewedAll = statuses.every((s) => s.hasViewed);

          groups.add(UserStatusGroup(
            user: user,
            statuses: statuses,
            hasViewed: hasViewedAll,
          ));
        }
      }

      print('✅ Created ${groups.length} status groups from ${statusesData.length} statuses');

      // If no real statuses exist, create demo statuses from user chats for testing
      if (groups.isEmpty) {
        print('⚠️ No statuses found! Creating demo statuses from chat contacts...');
        try {
          final chatService = ChatService();
          final chats = await chatService.getUserChats();
          
          final demoGroups = <UserStatusGroup>[];
          for (var chat in chats.take(6)) {  // Limit to 6 demo contacts
            if (chat.otherUser != null) {
              final demoStatus = StatusUpdate(
                id: 'demo_${chat.otherUser!.id}',
                userId: chat.otherUser!.id,
                content: 'Demo Status - ${chat.otherUser!.displayName}',
                mediaType: 'text',
                backgroundColor: '#FF6B9D',
                createdAt: DateTime.now(),
                expiresAt: DateTime.now().add(const Duration(hours: 24)),
                viewCount: 0,
                replyCount: 0,
                user: chat.otherUser,
                hasViewed: false,
                privacy: 'public',
              );
              
              demoGroups.add(UserStatusGroup(
                user: chat.otherUser!,
                statuses: [demoStatus],
                hasViewed: false,
              ));
            }
          }
          
          if (demoGroups.isNotEmpty) {
            print('✅ Created ${demoGroups.length} demo status groups');
            return demoGroups;
          }
        } catch (e) {
          print('⚠️ Error creating demo statuses: $e');
        }
      }

      // Sort: current user first, then unviewed statuses, then viewed statuses
      groups.sort((a, b) {
        // Current user's status always goes first
        if (a.user.id == currentUserId) return -1;
        if (b.user.id == currentUserId) return 1;
        
        // Unviewed statuses appear before viewed ones
        if (a.hasViewed != b.hasViewed) {
          return a.hasViewed ? 1 : -1;  // unviewed (-1) comes before viewed (1)
        }
        
        // Within same view status, sort by newest first
        return b.latestStatus.createdAt.compareTo(a.latestStatus.createdAt);
      });

      return groups;
    } catch (e) {
      print('Error getting statuses: $e');
      return [];
    }
  }

  // Get a single status by ID
  Future<StatusUpdate?> getStatusById(String statusId) async {
    try {
      final statusData = await supabase
          .from('status_updates')
          .select('''
            *,
            user:profiles!status_updates_user_id_fkey(*)
          ''')
          .eq('id', statusId)
          .eq('expires_at', 'gt.NOW()')
          .single();

      if (statusData.isEmpty) return null;

      final user = statusData['user'] != null
          ? UserModel.fromJson(statusData['user'] as Map<String, dynamic>)
          : null;

      final status = StatusUpdate.fromJson(statusData);
      return status.copyWith(user: user);
    } catch (e) {
      print('Error getting status by ID: $e');
      return null;
    }
  }

  // Mark status as viewed
  Future<void> markStatusAsViewed(String statusId) async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Check if already viewed
      final existing = await supabase
          .from('status_views')
          .select()
          .eq('status_id', statusId)
          .eq('viewer_id', currentUserId)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('status_views').insert({
          'status_id': statusId,
          'viewer_id': currentUserId,
        });
      }
    } catch (e) {
      print('Error marking status as viewed: $e');
    }
  }

  // Get viewers for a status
  Future<List<UserModel>> getStatusViewers(String statusId) async {
    try {
      final viewsData = await supabase
          .from('status_views')
          .select('viewer_id')
          .eq('status_id', statusId);

      if (viewsData.isEmpty) return [];

      final viewerIds = viewsData.map((v) => v['viewer_id'] as String).toList();

      final usersData = await supabase
          .from('profiles')
          .select()
          .inFilter('id', viewerIds);

      return usersData.map((data) => UserModel.fromJson(data)).toList();
    } catch (e) {
      print('Error getting status viewers: $e');
      return [];
    }
  }

  // Delete own status
  Future<bool> deleteStatus(String statusId) async {
    try {
      await supabase.from('status_updates').delete().eq('id', statusId);
      return true;
    } catch (e) {
      print('Error deleting status: $e');
      return false;
    }
  }

  // Delete expired statuses (cleanup)
  Future<void> cleanupExpiredStatuses() async {
    try {
      final now = DateTime.now();
      await supabase
          .from('status_updates')
          .delete()
          .lt('expires_at', now.toIso8601String());
    } catch (e) {
      print('Error cleaning up statuses: $e');
    }
  }
}