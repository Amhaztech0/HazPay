import '../main.dart';
import '../models/status_reply_model.dart';
import '../models/user_model.dart';

class StatusReplyService {
  // Send a reply to a status
  Future<StatusReply> sendReply({
    required String statusId,
    required String content,
    String replyType = 'text',
    String? parentReplyId,
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final currentUser = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUserId)
          .single();
      final currentUserName = currentUser['display_name'] as String?;

      final replyData = await supabase
          .from('status_replies')
          .insert({
            'status_id': statusId,
            'user_id': currentUserId,
            'content': content,
            'reply_type': replyType,
            if (parentReplyId != null) 'parent_reply_id': parentReplyId,
          })
          .select()
          .single();

      // Get status info to notify the owner
      final status = await supabase
          .from('status_updates')
          .select('user_id')
          .eq('id', statusId)
          .single();
      
      final statusOwnerId = status['user_id'] as String;
      
      // Get parent reply info if replying to a reply
      String? parentReplyOwnerId;
      if (parentReplyId != null) {
        final parentReply = await supabase
            .from('status_replies')
            .select('user_id')
            .eq('id', parentReplyId)
            .single();
        parentReplyOwnerId = parentReply['user_id'] as String;
      }

      // Send notifications
      await _sendStatusReplyNotification(
        statusId: statusId,
        statusOwnerId: statusOwnerId,
        replierName: currentUserName ?? 'Someone',
        content: content,
        replyType: replyType,
      );

      // If replying to someone's reply, notify them too
      if (parentReplyOwnerId != null && parentReplyOwnerId != statusOwnerId) {
        await _sendReplyMentionNotification(
          statusId: statusId,
          mentionedUserId: parentReplyOwnerId,
          mentionerName: currentUserName ?? 'Someone',
          content: content,
        );
      }

      return StatusReply.fromJson(replyData);
    } catch (e) {
      print('🔴 Error sending status reply: $e');
      throw Exception('Failed to send reply: $e');
    }
  }

  // Send notification about new status reply
  Future<void> _sendStatusReplyNotification({
    required String statusId,
    required String statusOwnerId,
    required String replierName,
    required String content,
    required String replyType,
  }) async {
    try {
      print('📱 _sendStatusReplyNotification: Checking for FCM token...');
      
      // Get FCM token for status owner
      final tokenData = await supabase
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', statusOwnerId)
          .maybeSingle();
      
      if (tokenData == null) {
        print('⚠️ No user_tokens record found for user: $statusOwnerId');
        print('   This means FCM token was never saved for this user');
        print('   Make sure NotificationService._getFCMToken() is called');
        return;
      }

      final fcmToken = tokenData['fcm_token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ FCM token is empty for user: $statusOwnerId');
        return;
      }

      print('✅ Found FCM token for user: $statusOwnerId');
      print('📤 Sending status reply notification:');
      print('   - statusId: $statusId');
      print('   - statusOwnerId: $statusOwnerId');
      print('   - replierName: $replierName');
      print('   - fcmToken: ${fcmToken.substring(0, 20)}...');

      // Call Edge Function to send FCM notification
      try {
        final response = await supabase.functions.invoke(
          'send-status-reply-notification',
          body: {
            'fcm_token': fcmToken,
            'status_id': statusId,
            'replier_name': replierName,
            'content': content,
            'reply_type': replyType,
          },
        );
        
        print('✅ Status reply notification response: ${response.toString()}');
        print('✅ Status reply notification sent to $statusOwnerId');
      } catch (funcError) {
        print('❌ Edge function error: $funcError');
        print('   Make sure send-status-reply-notification is deployed');
        print('   Make sure Firebase credentials are set in Supabase');
        rethrow;
      }
    } catch (e) {
      print('🔴 Error sending status reply notification: $e');
      // Don't throw - notification failure shouldn't break reply send
    }
  }

  // Send notification when someone replies to your reply
  Future<void> _sendReplyMentionNotification({
    required String statusId,
    required String mentionedUserId,
    required String mentionerName,
    required String content,
  }) async {
    try {
      // Get FCM token for mentioned user
      final tokenData = await supabase
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', mentionedUserId)
          .maybeSingle();
      
      if (tokenData == null) {
        print('⚠️ No user_tokens record found for user: $mentionedUserId');
        return;
      }

      final fcmToken = tokenData['fcm_token'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ No FCM token found for user: $mentionedUserId');
        return;
      }

      print('📤 Sending reply mention notification:');
      print('   - statusId: $statusId');
      print('   - mentionedUserId: $mentionedUserId');
      print('   - mentionerName: $mentionerName');
      print('   - fcmToken: ${fcmToken.substring(0, 20)}...');

      // Call Edge Function to send FCM notification
      final response = await supabase.functions.invoke(
        'send-reply-mention-notification',
        body: {
          'fcm_token': fcmToken,
          'status_id': statusId,
          'mentioner_name': mentionerName,
          'content': content,
        },
      );
      
      print('✅ Reply mention notification response: ${response.toString()}');
      print('✅ Reply mention notification sent to $mentionedUserId');
    } catch (e) {
      print('🔴 Error sending reply mention notification: $e');
      // Don't throw - notification failure shouldn't break reply send
    }
  }

  // Get all replies for a specific status (for status owner)
  Future<List<StatusReply>> getStatusReplies(String statusId) async {
    try {
      final repliesData = await supabase
          .from('status_replies')
          .select('''
            *,
            user:profiles!status_replies_user_id_fkey(*),
            parent_reply:status_replies!status_replies_parent_reply_id_fkey(id, content, user_id)
          ''')
          .eq('status_id', statusId)
          .order('created_at', ascending: true);

      return repliesData.map((json) {
        var reply = StatusReply.fromJson(json);
        
        // Attach user data
        if (json['user'] != null) {
          reply = reply.copyWith(user: UserModel.fromJson(json['user']));
        }
        
        // Attach parent reply user data
        if (json['parent_reply'] != null && json['parent_reply'] is Map) {
          final parentReply = json['parent_reply'] as Map<String, dynamic>;
          reply = reply.copyWith(
            parentReplyContent: parentReply['content'] as String?,
          );
          
          // Fetch parent reply user if available
          if (parentReply['user_id'] != null) {
            // Try to get parent user from the parent_reply data
            // If not available, we'll use just the content
          }
        }
        
        return reply;
      }).toList();
    } catch (e) {
      print('🔴 Error fetching status replies: $e');
      return [];
    }
  }

  // Get reply count for a status
  Future<int> getReplyCount(String statusId) async {
    try {
      final result = await supabase
          .from('status_replies')
          .select()
          .eq('status_id', statusId)
          .count();

      return result.count;
    } catch (e) {
      print('🔴 Error getting reply count: $e');
      return 0;
    }
  }

  // Stream replies for real-time updates (for status owner)
  Stream<List<StatusReply>> getRepliesStream(String statusId) {
    return supabase
        .from('status_replies')
        .stream(primaryKey: ['id'])
        .eq('status_id', statusId)
        .order('created_at', ascending: true)
        .asyncMap((repliesData) async {
          // Fetch user data for each reply
          List<StatusReply> replies = [];
          for (var replyJson in repliesData) {
            var reply = StatusReply.fromJson(replyJson);
            
            // Fetch user profile
            try {
              final userData = await supabase
                  .from('profiles')
                  .select()
                  .eq('id', reply.userId)
                  .single();
              
              reply = reply.copyWith(user: UserModel.fromJson(userData));
            } catch (e) {
              // User not found, continue with reply as-is
            }
            
            // Fetch parent reply user if parentReplyId exists
            if (reply.parentReplyId != null) {
              try {
                final parentReplyData = await supabase
                    .from('status_replies')
                    .select('content, user_id, user:profiles!status_replies_user_id_fkey(display_name)')
                    .eq('id', reply.parentReplyId!)
                    .single();
                
                reply = reply.copyWith(
                  parentReplyContent: parentReplyData['content'] as String?,
                  parentReplyUsername: (parentReplyData['user'] as Map?)?['display_name'] as String?,
                );
              } catch (e) {
                // Parent reply not found
              }
            }
            
            replies.add(reply);
          }
          return replies;
        });
  }

  // Delete a reply (only reply author can delete)
  Future<bool> deleteReply(String replyId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      await supabase
          .from('status_replies')
          .delete()
          .eq('id', replyId)
          .eq('user_id', currentUserId);

      return true;
    } catch (e) {
      print('🔴 Error deleting reply: $e');
      return false;
    }
  }

  // Get reply counts for multiple statuses (efficient batch query)
  Future<Map<String, int>> getReplyCountsForStatuses(List<String> statusIds) async {
    if (statusIds.isEmpty) return {};

    try {
      final repliesData = await supabase
          .from('status_replies')
          .select('status_id')
          .inFilter('status_id', statusIds);

      // Count replies per status
      final counts = <String, int>{};
      for (var reply in repliesData) {
        final statusId = reply['status_id'] as String;
        counts[statusId] = (counts[statusId] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      print('🔴 Error fetching reply counts: $e');
      return {};
    }
  }
}
