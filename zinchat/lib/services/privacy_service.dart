import '../main.dart';
import '../models/blocked_user_model.dart';
import '../models/message_request_model.dart';

class PrivacyService {
  // ============================================
  // Blocking Functions
  // ============================================

  /// Block a user
  Future<bool> blockUser(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      await supabase.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      await supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId);

      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  /// Check if user is blocked by current user
  Future<bool> isUserBlocked(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('blocked_users')
          .select()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Check if current user is blocked by another user
  Future<bool> isBlockedBy(String userId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('blocked_users')
          .select()
          .eq('blocker_id', userId)
          .eq('blocked_id', currentUserId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      print('Error checking if blocked by user: $e');
      return false;
    }
  }

  /// Get list of blocked users
  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('blocked_users')
          .select('''
            *,
            blocked_user:blocked_id (
              id,
              display_name,
              about,
              profile_photo_url,
              phone_number,
              created_at,
              updated_at,
              last_seen,
              messaging_privacy
            )
          ''')
          .eq('blocker_id', currentUserId)
          .order('created_at', ascending: false);

      return (result as List).map((json) {
        final blockedUserData = json['blocked_user'];
        return BlockedUser.fromJson({
          ...json,
          'blocked_user': blockedUserData,
        });
      }).toList();
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  // ============================================
  // Privacy Settings Functions
  // ============================================

  /// Update messaging privacy setting
  Future<bool> updateMessagingPrivacy(String privacy) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      await supabase
          .from('profiles')
          .update({'messaging_privacy': privacy})
          .eq('id', currentUserId);

      return true;
    } catch (e) {
      print('Error updating messaging privacy: $e');
      return false;
    }
  }

  /// Get current user's messaging privacy setting
  Future<String> getMessagingPrivacy() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('profiles')
          .select('messaging_privacy')
          .eq('id', currentUserId)
          .single();

      return result['messaging_privacy'] as String? ?? 'everyone';
    } catch (e) {
      print('Error getting messaging privacy: $e');
      return 'everyone';
    }
  }

  // ============================================
  // Message Request Functions
  // ============================================

  /// Create a message request
  Future<MessageRequest?> createMessageRequest({
    required String receiverId,
    String? firstMessageId,
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('message_requests')
          .insert({
            'sender_id': currentUserId,
            'receiver_id': receiverId,
            'first_message_id': firstMessageId,
            'status': 'pending',
          })
          .select()
          .single();

      return MessageRequest.fromJson(result);
    } catch (e) {
      print('Error creating message request: $e');
      return null;
    }
  }

  /// Accept a message request
  Future<bool> acceptMessageRequest(String requestId) async {
    try {
      await supabase
          .from('message_requests')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('Error accepting message request: $e');
      return false;
    }
  }

  /// Reject a message request
  Future<bool> rejectMessageRequest(String requestId) async {
    try {
      await supabase
          .from('message_requests')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('Error rejecting message request: $e');
      return false;
    }
  }

  /// Delete a message request
  Future<bool> deleteMessageRequest(String requestId) async {
    try {
      await supabase
          .from('message_requests')
          .delete()
          .eq('id', requestId);

      return true;
    } catch (e) {
      print('Error deleting message request: $e');
      return false;
    }
  }

  /// Get pending message requests (received)
  Future<List<MessageRequest>> getPendingMessageRequests() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('message_requests')
          .select('''
            *,
            sender:sender_id (
              id,
              display_name,
              about,
              profile_photo_url,
              phone_number,
              created_at,
              updated_at,
              last_seen,
              messaging_privacy
            )
          ''')
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (result as List).map((json) {
        final senderData = json['sender'];
        return MessageRequest.fromJson({
          ...json,
          'sender': senderData,
        });
      }).toList();
    } catch (e) {
      print('Error getting pending message requests: $e');
      return [];
    }
  }

  /// Get all message requests (for debugging)
  Future<List<MessageRequest>> getAllMessageRequests() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('message_requests')
          .select('''
            *,
            sender:sender_id (
              id,
              display_name,
              about,
              profile_photo_url,
              phone_number,
              created_at,
              updated_at,
              last_seen,
              messaging_privacy
            )
          ''')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('created_at', ascending: false);

      return (result as List).map((json) {
        final senderData = json['sender'];
        return MessageRequest.fromJson({
          ...json,
          'sender': senderData,
        });
      }).toList();
    } catch (e) {
      print('Error getting all message requests: $e');
      return [];
    }
  }

  /// Check if message request exists between users
  Future<MessageRequest?> getMessageRequest({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final result = await supabase
          .from('message_requests')
          .select()
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .maybeSingle();

      if (result == null) return null;
      return MessageRequest.fromJson(result);
    } catch (e) {
      print('Error getting message request: $e');
      return null;
    }
  }

  /// Get pending requests count
  Future<int> getPendingRequestsCount() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final result = await supabase
          .from('message_requests')
          .select()
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .count();

      return result.count;
    } catch (e) {
      print('Error getting pending requests count: $e');
      return 0;
    }
  }

  /// Check if user can send messages to another user
  Future<bool> canMessageUser(String receiverId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Check if blocked
      final isBlocked = await isUserBlocked(receiverId);
      final blockedBy = await isBlockedBy(receiverId);
      
      if (isBlocked || blockedBy) {
        return false;
      }

      // Get receiver's privacy setting
      final receiverProfile = await supabase
          .from('profiles')
          .select('messaging_privacy')
          .eq('id', receiverId)
          .single();

      final receiverPrivacy = receiverProfile['messaging_privacy'] as String? ?? 'everyone';

      // If everyone can message, return true
      if (receiverPrivacy == 'everyone') {
        return true;
      }

      // Check for accepted request
      final request = await getMessageRequest(
        senderId: currentUserId,
        receiverId: receiverId,
      );

      return request != null && request.isAccepted;
    } catch (e) {
      print('Error checking if can message user: $e');
      return false;
    }
  }

  // ============================================
  // Stream Functions
  // ============================================

  /// Stream of pending message requests count
  Stream<int> getPendingRequestsCountStream() {
    final currentUserId = supabase.auth.currentUser!.id;

    return supabase
        .from('message_requests')
        .stream(primaryKey: ['id'])
        .map((data) => data.where((item) => 
            item['receiver_id'] == currentUserId && 
            item['status'] == 'pending'
        ).length);
  }
}
