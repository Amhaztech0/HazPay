import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/server_model.dart';
import '../models/server_moderation_model.dart';
import '../models/server_channel_model.dart';
import 'storage_service.dart';
import '../utils/debug_logger.dart';

class ServerService {
  // Expose supabase client for accessing current user
  SupabaseClient get supabase => Supabase.instance.client;

  // Get all servers the user is a member of
  Future<List<ServerModel>> getUserServers() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('server_members')
          .select('server_id')
          .eq('user_id', userId);

      final serverIds = (response as List)
          .map((item) => item['server_id'] as String)
          .toList();

      if (serverIds.isEmpty) return [];

      final serversResponse = await supabase
          .from('servers')
          .select()
          .inFilter('id', serverIds)
          .order('created_at', ascending: false);

      return (serversResponse as List)
          .map((json) => ServerModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching user servers: $e');
      return [];
    }
  }

  // Get public servers
  Future<List<ServerModel>> getPublicServers() async {
    try {
      final response = await supabase
          .from('servers')
          .select()
          .eq('is_public', true)
          .order('member_count', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => ServerModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching public servers: $e');
      return [];
    }
  }

  // Get a single server by ID
  Future<ServerModel?> getServerById(String serverId) async {
    try {
      final response = await supabase
          .from('servers')
          .select()
          .eq('id', serverId)
          .single();

      return ServerModel.fromJson(response);
    } catch (e) {
      print('Error fetching server by ID: $e');
      return null;
    }
  }

  // Create a new server
  Future<ServerModel?> createServer({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create server
      final serverResponse = await supabase
          .from('servers')
          .insert({
            'name': name,
            'description': description,
            'owner_id': userId,
            'is_public': isPublic,
            'member_count': 1,
          })
          .select()
          .single();

      final server = ServerModel.fromJson(serverResponse);

      // Add creator as owner
      await supabase.from('server_members').insert({
        'server_id': server.id,
        'user_id': userId,
        'role': 'owner',
      });

      return server;
    } catch (e) {
      print('Error creating server: $e');
      return null;
    }
  }

  // Join a server
  Future<bool> joinServer(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if already a member
      final existing = await supabase
          .from('server_members')
          .select()
          .eq('server_id', serverId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return true; // Already a member
      }

      // Add as member
      await supabase.from('server_members').insert({
        'server_id': serverId,
        'user_id': userId,
        'role': 'member',
      });

      // Increment member count
      await supabase.rpc('increment_server_members', params: {
        'server_id': serverId,
      });

      return true;
    } catch (e) {
      print('Error joining server: $e');
      return false;
    }
  }

  // Leave a server
  Future<bool> leaveServer(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Remove membership
      await supabase
          .from('server_members')
          .delete()
          .eq('server_id', serverId)
          .eq('user_id', userId);

      // Decrement member count
      await supabase.rpc('decrement_server_members', params: {
        'server_id': serverId,
      });

      return true;
    } catch (e) {
      print('Error leaving server: $e');
      return false;
    }
  }

  // Get server members
  Future<List<ServerMemberModel>> getServerMembers(String serverId) async {
    try {
      // First get all server members
      final membersResponse = await supabase
          .from('server_members')
          .select()
          .eq('server_id', serverId)
          .order('joined_at', ascending: true);

      print('Server members response: $membersResponse');

      if ((membersResponse as List).isEmpty) {
        return [];
      }

      // Now fetch profiles for each member
      final List<ServerMemberModel> members = [];
      
      for (final memberJson in membersResponse) {
        print('Member JSON: $memberJson');
        
        try {
          final userId = memberJson['user_id'] as String;
          
          // Fetch the profile for this user
          final profileResponse = await supabase
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

          print('Profile for $userId: $profileResponse');

          // Create member with profile data
          final member = ServerMemberModel(
            id: memberJson['id'] as String,
            serverId: memberJson['server_id'] as String,
            userId: userId,
            role: memberJson['role'] as String? ?? 'member',
            joinedAt: DateTime.parse(memberJson['joined_at'] as String),
            user: profileResponse != null
                ? UserProfile.fromJson(profileResponse)
                : null,
          );

          members.add(member);
        } catch (e) {
          print('Error processing member: $e');
          // Still add the member even if we can't get the profile
          final member = ServerMemberModel(
            id: memberJson['id'] as String,
            serverId: memberJson['server_id'] as String,
            userId: memberJson['user_id'] as String,
            role: memberJson['role'] as String? ?? 'member',
            joinedAt: DateTime.parse(memberJson['joined_at'] as String),
            user: null,
          );
          members.add(member);
        }
      }

      return members;
    } catch (e) {
      print('Error fetching server members: $e');
      print('Stack trace: $e');
      return [];
    }
  }

  // Check if user is member of server
  Future<bool> isUserMember(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('server_members')
          .select()
          .eq('server_id', serverId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking membership: $e');
      return false;
    }
  }

  // Stream of user's servers
  Stream<List<ServerModel>> getUserServersStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return supabase
        .from('server_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((memberData) async {
          final serverIds = memberData
              .map((item) => item['server_id'] as String)
              .toList();

          if (serverIds.isEmpty) return <ServerModel>[];

          final serversResponse = await supabase
              .from('servers')
              .select()
              .inFilter('id', serverIds);

          return (serversResponse as List)
              .map((json) => ServerModel.fromJson(json))
              .toList();
        });
  }

  // Create server invite
  Future<ServerInviteModel?> createInvite({
    required String serverId,
    DateTime? expiresAt,
    int? maxUses,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Generate invite code
      final codeResponse = await supabase.rpc('generate_invite_code');
      final inviteCode = codeResponse as String;

      final response = await supabase
          .from('server_invites')
          .insert({
            'server_id': serverId,
            'invite_code': inviteCode,
            'created_by': userId,
            'expires_at': expiresAt?.toIso8601String(),
            'max_uses': maxUses,
          })
          .select()
          .single();

      return ServerInviteModel.fromJson(response);
    } catch (e) {
      print('Error creating invite: $e');
      return null;
    }
  }

  // Get server invites
  Future<List<ServerInviteModel>> getServerInvites(String serverId) async {
    try {
      final response = await supabase
          .from('server_invites')
          .select()
          .eq('server_id', serverId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ServerInviteModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching invites: $e');
      return [];
    }
  }

  // Join server with invite code
  Future<Map<String, dynamic>> joinWithInviteCode(String inviteCode) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase.rpc('join_server_with_invite', params: {
        'p_invite_code': inviteCode,
        'p_user_id': userId,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error joining with invite: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Deactivate invite
  Future<bool> deactivateInvite(String inviteId) async {
    try {
      await supabase
          .from('server_invites')
          .update({'is_active': false})
          .eq('id', inviteId);

      return true;
    } catch (e) {
      print('Error deactivating invite: $e');
      return false;
    }
  }

  // ============================================
  // SERVER MESSAGING
  // ============================================

  // Get messages stream for real-time updates
  Stream<List<ServerMessageModel>> getServerMessagesStream(String serverId, {String? channelId}) {
    // First, get the base messages stream
    return supabase
        .from('server_messages')
        .stream(primaryKey: ['id'])
        .eq('server_id', serverId)
        .order('created_at', ascending: true)
        .asyncMap((messagesList) async {
          // Parse all messages first
          var messages = messagesList
              .map((json) => ServerMessageModel.fromJson(json))
              .toList();
          
          // Filter by channel if provided
          if (channelId != null) {
            messages = messages.where((m) => m.channelId == channelId).toList();
          }
          
          debugPrint('🔄 Loaded ${messages.length} messages. Checking for replies...');
          
          // For each message with a reply_to_message_id, fetch the replied message
          for (int i = 0; i < messages.length; i++) {
            final message = messages[i];
            if (message.replyToMessageId != null) {
              debugPrint('📎 Message ${message.id.substring(0, 8)}... replies to ${message.replyToMessageId?.substring(0, 8)}...');
              
              try {
                // Fetch the replied message directly
                final replyMsg = await supabase
                    .from('server_messages')
                    .select()
                    .eq('id', message.replyToMessageId!)
                    .single();
                
                debugPrint('📦 Got reply message: $replyMsg');
                
                final replyUserId = replyMsg['user_id'] as String;
                
                // Fetch the profile of who sent the replied message
                final profile = await supabase
                    .from('profiles')
                    .select('display_name, profile_photo_url')
                    .eq('id', replyUserId)
                    .single();
                
                debugPrint('👤 Profile: $profile');
                
                // Create the ServerMessageReply object
                message.repliedTo = ServerMessageReply(
                  id: replyMsg['id'] as String,
                  content: (replyMsg['content'] ?? '') as String,
                  messageType: (replyMsg['message_type'] ?? 'text') as String,
                  mediaUrl: replyMsg['media_url'] as String?,
                  senderName: (profile['display_name'] ?? 'Unknown User') as String,
                  senderAvatar: profile['profile_photo_url'] as String?,
                );
                
                debugPrint('✅ Loaded reply: ${message.repliedTo!.senderName} said "${message.repliedTo!.content}"');
              } catch (e) {
                debugPrint('❌ Error loading reply: $e');
              }
            }
          }
          
          return messages;
        });
  }

  // Get paginated server messages
  Future<List<ServerMessageModel>> getServerMessagePage(
    String serverId, {
    String? channelId,
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      var query = supabase
          .from('server_messages')
          .select()
          .eq('server_id', serverId);

      if (channelId != null) {
        query = query.eq('channel_id', channelId);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final messages = data.map((json) => ServerMessageModel.fromJson(json)).toList().reversed.toList();
      
      return messages;
    } catch (e) {
      DebugLogger.error('Error fetching server message page: $e', tag: 'SERVER');
      return [];
    }
  }

  // Get total server message count
  Future<int> getServerMessageCount(
    String serverId, {
    String? channelId,
  }) async {
    try {
      var query = supabase
          .from('server_messages')
          .select()
          .eq('server_id', serverId);

      if (channelId != null) {
        query = query.eq('channel_id', channelId);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      DebugLogger.error('Error fetching server message count: $e', tag: 'SERVER');
      return 0;
    }
  }

  // Send message to server
  Future<bool> sendMessage({
    required String serverId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? replyToMessageId,
    String? channelId,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Insert the message
      final messageResponse = await supabase.from('server_messages').insert({
        'server_id': serverId,
        'user_id': userId,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
        'reply_to_message_id': replyToMessageId,
        'channel_id': channelId,
      }).select();

      if (messageResponse.isNotEmpty) {
        final messageId = messageResponse[0]['id'];
        
        // Send notifications to all server members (fire-and-forget)
        _sendServerNotifications(
          messageId: messageId,
          serverId: serverId,
          senderId: userId,
          content: content,
          channelId: channelId,
        );
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Send push notifications to server members via Edge Function (fire-and-forget)
  Future<void> _sendServerNotifications({
    required String messageId,
    required String serverId,
    required String senderId,
    required String content,
    String? channelId,
  }) async {
    try {
      DebugLogger.info('🔔 Preparing to send server notifications for message: $messageId');

      // Get sender's profile name
      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', senderId)
          .single();

      final senderName = profile['display_name'] ?? 'Someone';

      // Get all server members except the sender
      final members = await supabase
          .from('server_members')
          .select('user_id')
          .eq('server_id', serverId)
          .neq('user_id', senderId);

      // Filter members list
      final memberIds = (members as List)
          .map((item) => item['user_id'] as String)
          .toList();

      DebugLogger.info('🔔 Found ${memberIds.length} members to notify (excluding sender)');

      // Send notification to each member (fire-and-forget for each)
      for (final memberId in memberIds) {
        try {
          // Check if member has notifications enabled for this server
          final settings = await supabase
              .from('server_notification_settings')
              .select('notifications_enabled')
              .eq('user_id', memberId)
              .eq('server_id', serverId)
              .maybeSingle();

          // Default to true if no settings exist
          final notificationsEnabled = settings?['notifications_enabled'] ?? true;

          if (!notificationsEnabled) {
            DebugLogger.info('🔕 Notifications disabled for user $memberId on server $serverId');
            continue;
          }

          // Call Edge Function to send notification
          await supabase.functions.invoke(
            'send-notification',
            body: {
              'type': 'server_message',
              'userId': memberId,
              'messageId': messageId,
              'senderId': senderId,
              'senderName': senderName,
              'content': content,
              'serverId': serverId,
              if (channelId != null) 'channelId': channelId,
            },
          );

          DebugLogger.info('🔔 Notification sent to member: $memberId');
        } catch (e) {
          // Silently fail for individual member - continue with others
          DebugLogger.error('❌ Error sending notification to member $memberId: $e', tag: 'SERVER');
        }
      }

      DebugLogger.info('✅ Server notification batch complete');
    } catch (e) {
      // Silently fail - notification is not critical
      DebugLogger.error('❌ Error in _sendServerNotifications: $e', tag: 'SERVER');
    }
  }

  // Delete message
  Future<bool> deleteMessage(String messageId) async {
    try {
      await supabase
          .from('server_messages')
          .delete()
          .eq('id', messageId);

      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Upload a file to Supabase Storage and return a public URL
  Future<String?> uploadServerFile(String serverId, XFile xfile) async {
    try {
      final bytes = await xfile.readAsBytes();
      final filename = xfile.name;
      final path = 'servers/$serverId/${DateTime.now().millisecondsSinceEpoch}_$filename';
      final bucket = 'server-media';

      print('Uploading file to bucket: $bucket, path: $path');

      // Upload binary
      await supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: xfile.mimeType ?? _getContentType(filename),
            ),
          );

      print('Upload successful, path: $path');

      // Get public URL using getPublicUrl method
      final url = supabase.storage.from(bucket).getPublicUrl(path);
      print('Public URL generated: $url');
      
      return url;
    } catch (e) {
      print('Error uploading file: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('Bucket not found')) {
        print('IMPORTANT: You need to create a storage bucket named "server-media" in your Supabase project.');
        print('Go to: Supabase Dashboard > Storage > Create a new bucket named "server-media"');
        print('Make sure to set it as public or configure appropriate policies.');
      }
      return null;
    }
  }

  // Helper to determine content type from filename
  String _getContentType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // Admin: remove a member from a server (admin RLS enforces permission)
  Future<bool> removeMember(String serverId, String userId) async {
    try {
      await supabase
          .from('server_members')
          .delete()
          .eq('server_id', serverId)
          .eq('user_id', userId);

      // Decrement member count
      await supabase.rpc('decrement_server_members', params: {
        'server_id': serverId,
      });

      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  // Check if current user is admin/owner of a server
  Future<bool> isUserAdmin(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase
          .from('server_members')
          .select('role')
          .eq('server_id', serverId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return false;
      final role = (response as Map)['role'] as String?;
      return role == 'owner' || role == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // ============================================
  // SERVER LIMIT & EDITING
  // ============================================

  // Check if user can create more servers (max 2)
  Future<bool> canCreateServer() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase.rpc('can_create_server', params: {
        'p_user_id': userId,
      });

      return response as bool;
    } catch (e) {
      print('Error checking server limit: $e');
      return false;
    }
  }

  // Get count of servers owned by current user
  Future<int> getUserOwnedServersCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await supabase
          .from('servers')
          .select('id')
          .eq('owner_id', userId);

      return (response as List).length;
    } catch (e) {
      print('Error getting server count: $e');
      return 0;
    }
  }

  // Update server name
  Future<bool> updateServerName(String serverId, String newName) async {
    try {
      await supabase
          .from('servers')
          .update({'name': newName, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', serverId);

      return true;
    } catch (e) {
      print('Error updating server name: $e');
      return false;
    }
  }

  // Update server description
  Future<bool> updateServerDescription(String serverId, String? description) async {
    try {
      await supabase
          .from('servers')
          .update({
            'description': description,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', serverId);

      return true;
    } catch (e) {
      print('Error updating server description: $e');
      return false;
    }
  }

  // Update server icon
  Future<bool> updateServerIcon(String serverId, File iconFile) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final storageService = StorageService();
      
      // Upload to storage
      final fileUrl = await storageService.uploadFile(
        file: iconFile,
        bucket: 'server-icons',
        path: 'servers/$serverId',
      );

      if (fileUrl == null) return false;

      // Update server record
      await supabase
          .from('servers')
          .update({
            'icon_url': fileUrl,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', serverId);

      return true;
    } catch (e) {
      print('Error updating server icon: $e');
      return false;
    }
  }

  // ============================================
  // MEMBER MODERATION
  // ============================================

  // Ban user from server
  Future<Map<String, dynamic>> banUser({
    required String serverId,
    required String userId,
    String? reason,
    bool permanent = true,
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('ban_user_from_server', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
        'p_reason': reason,
        'p_permanent': permanent,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error banning user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Unban user from server
  Future<Map<String, dynamic>> unbanUser({
    required String serverId,
    required String userId,
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('unban_user_from_server', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error unbanning user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Mute user in server
  Future<Map<String, dynamic>> muteUser({
    required String serverId,
    required String userId,
    String? reason,
    int? durationMinutes, // null = permanent
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('mute_user_in_server', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
        'p_reason': reason,
        'p_duration_minutes': durationMinutes,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error muting user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Unmute user in server
  Future<Map<String, dynamic>> unmuteUser({
    required String serverId,
    required String userId,
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('unmute_user_in_server', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error unmuting user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Timeout user in server
  Future<Map<String, dynamic>> timeoutUser({
    required String serverId,
    required String userId,
    String? reason,
    int durationMinutes = 5,
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('timeout_user_in_server', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
        'p_reason': reason,
        'p_duration_minutes': durationMinutes,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error timing out user: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Remove timeout from user
  Future<Map<String, dynamic>> removeTimeout({
    required String serverId,
    required String userId,
  }) async {
    try {
      final moderatorId = supabase.auth.currentUser?.id;
      if (moderatorId == null) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      final response = await supabase.rpc('remove_timeout_from_user', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
        'p_moderator_id': moderatorId,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error removing timeout: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get moderation records for a server
  Future<List<ServerModerationModel>> getServerModeration(String serverId) async {
    try {
      final response = await supabase
          .from('server_member_moderation')
          .select()
          .eq('server_id', serverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ServerModerationModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching moderation records: $e');
      return [];
    }
  }

  // Check if user is banned from server
  Future<bool> isUserBanned(String serverId, String userId) async {
    try {
      final response = await supabase.rpc('is_user_banned', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
      });

      return response as bool;
    } catch (e) {
      print('Error checking ban status: $e');
      return false;
    }
  }

  // Check if user is muted in server
  Future<bool> isUserMuted(String serverId, String userId) async {
    try {
      final response = await supabase.rpc('is_user_muted', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
      });

      return response as bool;
    } catch (e) {
      print('Error checking mute status: $e');
      return false;
    }
  }

  // Check if user is in timeout in server
  Future<bool> isUserInTimeout(String serverId, String userId) async {
    try {
      final response = await supabase.rpc('is_user_in_timeout', params: {
        'p_server_id': serverId,
        'p_user_id': userId,
      });

      return response as bool;
    } catch (e) {
      print('Error checking timeout status: $e');
      return false;
    }
  }

  // Clean up expired moderation records
  Future<void> cleanupExpiredModeration() async {
    try {
      await supabase.rpc('cleanup_expired_moderation');
    } catch (e) {
      print('Error cleaning up moderation: $e');
    }
  }

  // ============================================
  // SERVER DELETION
  // ============================================

  // Schedule server deletion (24-hour countdown)
  Future<Map<String, dynamic>> scheduleServerDeletion(String serverId) async {
    try {
      final response = await supabase.rpc('schedule_server_deletion', params: {
        'p_server_id': serverId,
      });

      return {
        'success': response['success'] as bool,
        'message': response['message'] as String,
        'deletionAt': response['deletion_at'] != null
            ? DateTime.parse(response['deletion_at'] as String)
            : null,
      };
    } catch (e) {
      print('Error scheduling server deletion: $e');
      return {
        'success': false,
        'message': 'Failed to schedule deletion: $e',
      };
    }
  }

  // Cancel scheduled server deletion
  Future<Map<String, dynamic>> cancelServerDeletion(String serverId) async {
    try {
      final response = await supabase.rpc('cancel_server_deletion', params: {
        'p_server_id': serverId,
      });

      return {
        'success': response['success'] as bool,
        'message': response['message'] as String,
      };
    } catch (e) {
      print('Error cancelling server deletion: $e');
      return {
        'success': false,
        'message': 'Failed to cancel deletion: $e',
      };
    }
  }

  // Add a reaction to a message
  Future<bool> addReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });

      return true;
    } catch (e) {
      print('Error adding reaction: $e');
      return false;
    }
  }

  // Remove a reaction from a message
  Future<bool> removeReaction({
    required String messageId,
    required String emoji,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);

      return true;
    } catch (e) {
      print('Error removing reaction: $e');
      return false;
    }
  }

  // Get all reactions for a message
  Future<List<MessageReactionModel>> getMessageReactions(String messageId) async {
    try {
      final response = await supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((item) => MessageReactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching message reactions: $e');
      return [];
    }
  }

  // Get reactions grouped by emoji (for display)
  Future<Map<String, List<String>>> getReactionsSummary(String messageId) async {
    try {
      final reactions = await getMessageReactions(messageId);
      final summary = <String, List<String>>{};

      for (final reaction in reactions) {
        if (!summary.containsKey(reaction.emoji)) {
          summary[reaction.emoji] = [];
        }
        summary[reaction.emoji]!.add(reaction.userId);
      }

      return summary;
    } catch (e) {
      print('Error getting reactions summary: $e');
      return {};
    }
  }

  // ============================================
  // CHANNEL MANAGEMENT
  // ============================================

  // Get all channels for a server
  Future<List<ServerChannelModel>> getServerChannels(String serverId) async {
    try {
      final response = await supabase
          .from('server_channels')
          .select()
          .eq('server_id', serverId)
          .order('position', ascending: true);

      return (response as List)
          .map((json) => ServerChannelModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching server channels: $e');
      return [];
    }
  }

  // Stream of channels for a server
  Stream<List<ServerChannelModel>> getServerChannelsStream(String serverId) {
    return supabase
        .from('server_channels')
        .stream(primaryKey: ['id'])
        .eq('server_id', serverId)
        .order('position', ascending: true)
        .map((channelsList) => (channelsList as List)
            .map((json) => ServerChannelModel.fromJson(json))
            .toList());
  }

  // Create a new channel in a server
  Future<ServerChannelModel?> createChannel({
    required String serverId,
    required String name,
    String? description,
    String channelType = 'text',
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get the highest position
      final existingChannels = await getServerChannels(serverId);
      final position = existingChannels.isEmpty
          ? 0
          : existingChannels.map((c) => c.position).reduce((a, b) => a > b ? a : b) + 1;

      final response = await supabase
          .from('server_channels')
          .insert({
            'server_id': serverId,
            'name': name.toLowerCase().replaceAll(' ', '-'),
            'description': description,
            'channel_type': channelType,
            'created_by': userId,
            'position': position,
          })
          .select()
          .single();

      return ServerChannelModel.fromJson(response);
    } catch (e) {
      print('Error creating channel: $e');
      return null;
    }
  }

  // Update channel details
  Future<bool> updateChannel({
    required String channelId,
    String? name,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) {
        updates['name'] = name.toLowerCase().replaceAll(' ', '-');
      }
      if (description != null) {
        updates['description'] = description;
      }
      updates['updated_at'] = DateTime.now().toIso8601String();

      await supabase
          .from('server_channels')
          .update(updates)
          .eq('id', channelId);

      return true;
    } catch (e) {
      print('Error updating channel: $e');
      return false;
    }
  }

  // Delete a channel
  Future<bool> deleteChannel(String channelId) async {
    try {
      await supabase
          .from('server_channels')
          .delete()
          .eq('id', channelId);

      return true;
    } catch (e) {
      print('Error deleting channel: $e');
      return false;
    }
  }

  // Reorder channels (update positions)
  Future<bool> reorderChannels(List<String> channelIds) async {
    try {
      for (int i = 0; i < channelIds.length; i++) {
        await supabase
            .from('server_channels')
            .update({'position': i})
            .eq('id', channelIds[i]);
      }
      return true;
    } catch (e) {
      print('Error reordering channels: $e');
      return false;
    }
  }

  // =====================================================
  // SERVER NOTIFICATION SETTINGS
  // =====================================================

  /// Check if notifications are enabled for a specific server
  /// Returns true by default if no setting exists
  Future<bool> areNotificationsEnabled(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return true;

      final response = await supabase
          .from('server_notification_settings')
          .select('notifications_enabled')
          .eq('user_id', userId)
          .eq('server_id', serverId)
          .maybeSingle();

      if (response == null) {
        // No setting found, default to enabled
        return true;
      }

      return response['notifications_enabled'] as bool? ?? true;
    } catch (e) {
      print('Error checking notification status: $e');
      return true; // Default to enabled on error
    }
  }

  /// Enable notifications for a specific server
  Future<bool> enableServerNotifications(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('server_notification_settings')
          .upsert({
            'user_id': userId,
            'server_id': serverId,
            'notifications_enabled': true,
          }, onConflict: 'user_id,server_id');

      return true;
    } catch (e) {
      print('Error enabling server notifications: $e');
      return false;
    }
  }

  /// Disable notifications for a specific server
  Future<bool> disableServerNotifications(String serverId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase
          .from('server_notification_settings')
          .upsert({
            'user_id': userId,
            'server_id': serverId,
            'notifications_enabled': false,
          }, onConflict: 'user_id,server_id');

      return true;
    } catch (e) {
      print('Error disabling server notifications: $e');
      return false;
    }
  }

  /// Toggle notification status for a server
  Future<bool> toggleServerNotifications(String serverId) async {
    try {
      final currentStatus = await areNotificationsEnabled(serverId);
      if (currentStatus) {
        return await disableServerNotifications(serverId);
      } else {
        return await enableServerNotifications(serverId);
      }
    } catch (e) {
      print('Error toggling server notifications: $e');
      return false;
    }
  }

  /// Get notification settings for all servers the user is in
  Future<Map<String, bool>> getAllServerNotificationSettings() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await supabase
          .from('server_notification_settings')
          .select('server_id, notifications_enabled')
          .eq('user_id', userId);

      final settings = <String, bool>{};
      for (final item in response) {
        settings[item['server_id'] as String] = item['notifications_enabled'] as bool;
      }

      return settings;
    } catch (e) {
      print('Error getting all notification settings: $e');
      return {};
    }
  }

  /// Stream notification status for a server
  Stream<bool> getNotificationStatusStream(String serverId) {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(true);
    }

    return supabase
        .from('server_notification_settings')
        .stream(primaryKey: ['id'])
        .map((data) {
          // Filter by user_id and server_id client-side
          final filtered = data.where((item) =>
              item['user_id'] == userId && item['server_id'] == serverId);
          
          if (filtered.isEmpty) return true; // Default enabled
          return filtered.first['notifications_enabled'] as bool? ?? true;
        });
  }

  /// Upload a voice note file to Supabase Storage
  Future<String?> uploadVoiceNote({
    required String serverId,
    required File voiceFile,
    required String fileName,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create storage path: servers/{serverId}/voice_notes/{userId}/{timestamp}.m4a
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'servers/$serverId/voice_notes/$userId/$timestamp.m4a';

      // Upload file
      await supabase.storage
          .from('messages')
          .upload(
            storagePath,
            voiceFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Get public URL
      final publicUrl = supabase.storage
          .from('messages')
          .getPublicUrl(storagePath);

      print('✅ Voice note uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading voice note: $e');
      return null;
    }
  }

  /// Send a voice message to the server
  Future<bool> sendVoiceMessage({
    required String serverId,
    required File voiceFile,
    String? channelId,
    String? replyToMessageId,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Upload voice file
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final mediaUrl = await uploadVoiceNote(
        serverId: serverId,
        voiceFile: voiceFile,
        fileName: fileName,
      );

      if (mediaUrl == null) throw Exception('Failed to upload voice note');

      // Send message with audio type
      final success = await sendMessage(
        serverId: serverId,
        content: '🎙️ Voice Message', // Fallback text
        messageType: 'audio',
        mediaUrl: mediaUrl,
        channelId: channelId,
        replyToMessageId: replyToMessageId,
      );

      return success;
    } catch (e) {
      print('❌ Error sending voice message: $e');
      return false;
    }
  }
}
