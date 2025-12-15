// import 'package:flutter/foundation.dart'; // Not used after debug/logger conversion
import '../main.dart';
import '../utils/debug_logger.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../config.dart';
import 'dart:convert';
import 'dart:io';
import 'storage_service.dart';
import 'upload_function_client.dart';
import 'local_message_cache_service.dart';
import 'dart:async';

class ChatService {
  // Use Edge Function for uploads (bypasses RLS)
  static final _uploadClient = UploadFunctionClient(
    Uri.parse(AppConfig.uploadFunctionUrl),
  );
  
  // Local cache for instant message display
  final _localCache = LocalMessageCacheService();

  // Get or create a chat between two users
  Future<ChatModel> getOrCreateChat(String otherUserId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Ensure both users have profiles before creating chat
      await _ensureProfileExists(currentUserId);
      await _ensureProfileExists(otherUserId);

      // Try to find existing chat
      final existingChat = await supabase
          .from('chats')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
          .or('user1_id.eq.$otherUserId,user2_id.eq.$otherUserId')
          .maybeSingle();

      if (existingChat != null) {
        return ChatModel.fromJson(existingChat);
      }

      // Create new chat
      final newChat = await supabase
          .from('chats')
          .insert({'user1_id': currentUserId, 'user2_id': otherUserId})
          .select()
          .single();

      return ChatModel.fromJson(newChat);
    } catch (e) {
      throw Exception('Failed to get or create chat: $e');
    }
  }

  // Helper method to ensure a user profile exists
  Future<void> _ensureProfileExists(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        // Profile doesn't exist, create a basic one
        await supabase.from('profiles').insert({
          'id': userId,
          'display_name': 'ZinChat User',
          'about': 'Hey there! I am using ZinChat.',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // If profile creation fails, log it but don't throw
      // The database might have a trigger that creates profiles
      DebugLogger.error(
        'Note: Could not ensure profile exists for $userId: $e',
        tag: 'CHAT',
      );
    }
  }

  // Get all chats for current user
  Future<List<ChatModel>> getUserChats() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      DebugLogger.call('📱 Loading user chats for: $currentUserId');

      // 1. Get all chats for current user
      final chats = await supabase
          .from('chats')
          .select()
          .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId');

      if (chats.isEmpty) {
        DebugLogger.info('No chats found', tag: 'CHAT');
        return [];
      }

      // 2. Get all other user IDs involved in chats
      final otherUserIds = <String>{};
      for (final chatData in chats) {
        final chat = ChatModel.fromJson(chatData);
        final otherUserId = chat.user1Id == currentUserId
            ? chat.user2Id
            : chat.user1Id;
        otherUserIds.add(otherUserId);
      }

      // 3. Batch fetch all profiles at once (single query instead of N queries)
      final profiles = await supabase
          .from('profiles')
          .select()
          .inFilter('id', otherUserIds.toList());

      final profileMap = Map.fromIterable(
        profiles,
        key: (p) => p['id'] as String,
        value: (p) => UserModel.fromJson(p as Map<String, dynamic>),
      );

      // 4. Get last message for each chat (batch query)
      final lastMessagesData = await supabase
          .from('messages')
          .select('id, chat_id, sender_id, content, message_type, media_url, created_at, is_read')
          .inFilter('chat_id', chats.map((c) => c['id']).toList())
          .order('created_at', ascending: false);

      // Group by chat_id and get first (most recent) for each
      final lastMessageMap = <String, Map<String, dynamic>>{};
      for (final msg in lastMessagesData) {
        final chatId = msg['chat_id'] as String;
        if (!lastMessageMap.containsKey(chatId)) {
          lastMessageMap[chatId] = msg;
        }
      }

      // 5. Get unread counts for all chats (batch count)
      final unreadData = await supabase
          .from('messages')
          .select('chat_id')
          .eq('is_read', false)
          .neq('sender_id', currentUserId)
          .inFilter('chat_id', chats.map((c) => c['id']).toList());

      final unreadCountMap = <String, int>{};
      for (final msg in unreadData) {
        final chatId = msg['chat_id'] as String;
        unreadCountMap[chatId] = (unreadCountMap[chatId] ?? 0) + 1;
      }

      // 6. Build chat list with all data
      List<ChatModel> chatList = [];

      for (final chatData in chats) {
        final chat = ChatModel.fromJson(chatData);
        final otherUserId = chat.user1Id == currentUserId
            ? chat.user2Id
            : chat.user1Id;

        final otherUser = profileMap[otherUserId];
        final lastMsgData = lastMessageMap[chat.id];
        final unreadCount = unreadCountMap[chat.id] ?? 0;

        MessageModel? lastMessage;
        if (lastMsgData != null) {
          lastMessage = MessageModel.fromJson(lastMsgData);
        }

        if (otherUser != null) {
          chatList.add(
            chat.copyWith(
              otherUser: otherUser,
              lastMessage: lastMessage,
              unreadCount: unreadCount,
            ),
          );
        }
      }

      // 7. Sort by last message timestamp
      chatList.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? a.createdAt;
        final bTime = b.lastMessage?.createdAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      DebugLogger.success('✅ Loaded ${chatList.length} chats optimally', tag: 'CHAT');
      return chatList;
    } catch (e) {
      DebugLogger.error('❌ Failed to get chats: $e', tag: 'CHAT');
      throw Exception('Failed to get chats: $e');
    }
  }

  // Stream of chats with real-time updates for unread counts
  Stream<List<ChatModel>> getUserChatsStream() {
    final controller = StreamController<List<ChatModel>>();
    StreamSubscription? realtimeSubscription;
    Timer? fallbackTimer;

    Future<void> loadChats() async {
      try {
        final chats = await getUserChats();
        if (!controller.isClosed) {
          controller.add(chats);
        }
      } catch (e) {
        DebugLogger.error('Error loading chats: $e', tag: 'CHAT');
      }
    }

    // 1. Load initial data immediately
    DebugLogger.info('📱 Loading initial chats...', tag: 'CHAT');
    loadChats();

    // 2. Setup Realtime listener (instant updates for chat/message changes)
    try {
      realtimeSubscription = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .listen(
            (_) async {
              // Messages changed, reload chats (this updates last message and unread count)
              DebugLogger.info('🔄 Real-time message update detected, refreshing chats...', tag: 'CHAT');
              await loadChats();
            },
            onError: (error) {
              DebugLogger.error('Realtime error in chat stream: $error', tag: 'CHAT');
              // Setup fallback polling on error
              if (fallbackTimer == null) {
                fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
                  DebugLogger.info('⏱️ Fallback polling (realtime failed)', tag: 'CHAT');
                  await loadChats();
                });
              }
            },
          );
    } catch (e) {
      DebugLogger.error('Realtime not available: $e', tag: 'CHAT');
      // Fallback to polling every 30 seconds if realtime unavailable
      fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        DebugLogger.info('⏱️ Polling (realtime unavailable)', tag: 'CHAT');
        await loadChats();
      });
    }

    // Cleanup
    controller.onCancel = () {
      realtimeSubscription?.cancel();
      fallbackTimer?.cancel();
    };

    return controller.stream;
  }

  Future<bool> _areUsersContacts(String senderId, String receiverId) async {
    try {
      final contact = await supabase
          .from('contacts')
          .select('id')
          .or(
            'and(user_id_1.eq.$senderId,user_id_2.eq.$receiverId),'
            'and(user_id_1.eq.$receiverId,user_id_2.eq.$senderId)',
          )
          .maybeSingle();
      return contact != null;
    } catch (e) {
      DebugLogger.error('Fallback contact lookup failed: $e', tag: 'CHAT');
      return true; // Let RLS enforce if this query fails
    }
  }

  // Public method to check if two users are contacts
  Future<bool> checkIfContacts({
    required String userId1,
    required String userId2,
  }) async {
    return _areUsersContacts(userId1, userId2);
  }

  Future<bool> _canSendMessageDirectly(String senderId, String receiverId) async {
    try {
      final result = await supabase.rpc(
        'can_send_message',
        params: {'p_sender_id': senderId, 'p_receiver_id': receiverId},
      );
      return result == true;
    } catch (error) {
      DebugLogger.error(
        'can_send_message RPC failed, using contact fallback: $error',
        tag: 'CHAT',
      );
      return _areUsersContacts(senderId, receiverId);
    }
  }

  // Send a text message with search method tracking
  Future<MessageModel> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String searchMethod = 'name', // 'email' or 'name' - determines if direct or request
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Get other user's ID from chat
      final chat = await supabase
          .from('chats')
          .select()
          .eq('id', chatId)
          .single();

      final otherUserId = chat['user1_id'] == currentUserId
          ? chat['user2_id']
          : chat['user1_id'];

      // Ensure UUIDs are strings
      final senderIdStr = currentUserId.toString();
      final receiverIdStr = otherUserId.toString();

      DebugLogger.call(
        '📤 Sending message - Sender: $senderIdStr, Receiver: $receiverIdStr, SearchMethod: $searchMethod',
      );

      // If searched by email: direct message (no approval needed)
      if (searchMethod == 'email') {
        DebugLogger.info('✅ Email search: Direct message (no approval)');
        final messageData = await supabase
            .from('messages')
            .insert({
              'chat_id': chatId,
              'sender_id': currentUserId,
              'content': content,
              'message_type': messageType,
              'media_url': mediaUrl,
              'search_method': 'email',
              'is_request': false,
            })
            .select()
            .single();

        // Send push notification immediately (direct message)
        _sendNotification(
          recipientId: otherUserId.toString(),
          messageId: messageData['id'].toString(),
          content: content,
          chatId: chatId,
        );

        DebugLogger.success('✅ Direct message sent via email search!');
        return MessageModel.fromJson(messageData);
      }
      
      // If searched by name: message request (pending approval)
      DebugLogger.info('📨 Name search: Message request (pending approval)');
      
      // Insert message request record
      try {
        await supabase.from('message_requests').insert({
          'sender_id': currentUserId,
          'receiver_id': otherUserId,
          'status': 'pending',
        });
      } catch (e) {
        // Ignore unique constraint errors (request already exists)
        if (!e.toString().contains('unique')) {
          rethrow;
        }
      }

      final messageData = await supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUserId,
            'content': content,
            'message_type': messageType,
            'media_url': mediaUrl,
            'search_method': 'name',
            'is_request': true,
          })
          .select()
          .single();

      // Send request notification (not a direct message)
      _sendMessageRequestNotification(
        recipientId: otherUserId.toString(),
        senderName: await _getSenderDisplayName(currentUserId),
        senderPhotoUrl: await _getSenderPhotoUrl(currentUserId),
        messageId: messageData['id'].toString(),
        chatId: chatId,
      );

      DebugLogger.success('✅ Message request sent via name search!');
      return MessageModel.fromJson(messageData);
    } catch (e) {
      DebugLogger.error('❌ Error sending message: $e', tag: 'CHAT');
      throw Exception('Failed to send message: $e');
    }
  }

  Future<MessageModel?> sendCallStatusMessage({
    required String chatId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final messageData = await supabase
          .from('messages')
          .insert({
            'chat_id': chatId.toString(),
            'sender_id': currentUserId,
            'content': jsonEncode(metadata),
            'message_type': 'call_status',
          })
          .select()
          .single();

      return MessageModel.fromJson(messageData);
    } catch (e) {
      DebugLogger.error('❌ Error inserting call status message: $e', tag: 'CHAT');
      return null;
    }
  }

  // Accept a message request
  Future<bool> acceptMessageRequest(String requestId) async {
    try {
      DebugLogger.info('📨 Accepting message request: $requestId', tag: 'CHAT');
      
      // Get the request to find the sender
      final request = await supabase
          .from('message_requests')
          .select('sender_id, receiver_id')
          .eq('id', requestId)
          .single();

      final senderId = request['sender_id'] as String;
      final receiverId = request['receiver_id'] as String;

      DebugLogger.info('📨 Request found - sender: $senderId, receiver: $receiverId', tag: 'CHAT');

      // Update request status to accepted
      await supabase
          .from('message_requests')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      DebugLogger.success('📨 Request status updated to accepted', tag: 'CHAT');

      // Create contact entry with proper ordering (user_id_1 < user_id_2)
      try {
        final userId1 = (senderId.compareTo(receiverId) < 0) ? senderId : receiverId;
        final userId2 = (senderId.compareTo(receiverId) < 0) ? receiverId : senderId;
        
        DebugLogger.info('📨 Creating contact: $userId1 <-> $userId2', tag: 'CHAT');
        
        await supabase.from('contacts').insert({
          'user_id_1': userId1,
          'user_id_2': userId2,
        });
        
        DebugLogger.success('📨 Contact created successfully', tag: 'CHAT');
      } catch (e) {
        // Ignore if already exists
        if (!e.toString().contains('unique')) {
          DebugLogger.error('📨 Error creating contact: $e', tag: 'CHAT');
          rethrow;
        }
        DebugLogger.info('📨 Contact already exists, ignoring duplicate', tag: 'CHAT');
      }

      DebugLogger.success('✅ Message request accepted successfully', tag: 'CHAT');
      return true;
    } catch (e) {
      DebugLogger.error('❌ Error accepting message request: $e', tag: 'CHAT');
      return false;
    }
  }

  // Decline a message request
  Future<bool> declineMessageRequest(String requestId) async {
    try {
      DebugLogger.info('📨 Declining message request: $requestId', tag: 'CHAT');
      
      await supabase
          .from('message_requests')
          .update({
            'status': 'declined',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      DebugLogger.success('✅ Message request declined successfully', tag: 'CHAT');
      return true;
    } catch (e) {
      DebugLogger.error('❌ Error declining message request: $e', tag: 'CHAT');
      return false;
    }
  }

  // Get pending message requests
  Future<List<Map<String, dynamic>>> getPendingMessageRequests() async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final requests = await supabase
          .from('message_requests')
          .select('''
            *,
            sender:sender_id (
              id,
              display_name,
              profile_photo_url,
              about
            )
          ''')
          .eq('receiver_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      DebugLogger.error('Error getting pending requests: $e', tag: 'CHAT');
      return [];
    }
  }

  // Get pending requests count
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
      DebugLogger.error(
        'Error getting pending requests count: $e',
        tag: 'CHAT',
      );
      return 0;
    }
  }

  // Send media message (image, video, or file)
  Future<MessageModel?> sendMediaMessage({
    required String chatId,
    required File file,
    required String messageType, // 'image', 'video', 'file', 'audio'
    String? content, // Optional content (e.g., duration for audio)
  }) async {
    try {
      DebugLogger.call(
        '📤 sendMediaMessage called: type=$messageType, chatId=$chatId',
      );
      final currentUserId = supabase.auth.currentUser!.id;
      final storageService = StorageService();

      // Check file size (max 50MB)
      final fileSizeMB = storageService.getFileSizeInMB(file);
      if (fileSizeMB > 50) {
        throw Exception('File size must be less than 50MB');
      }

      // Determine bucket
      String bucket = 'chat-media';

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = file.path.split('.').last;
      final fileName = '$chatId/$currentUserId/$timestamp.$fileExt';

      // Upload file via Edge Function (bypasses RLS)
      // Falls back to direct storage if function fails
      String? mediaUrl;
      try {
        mediaUrl = await _uploadClient.uploadFile(
          file,
          bucket: bucket,
          path: fileName,
        );
      } catch (e) {
        DebugLogger.error(
          'Edge Function upload failed, trying direct storage: $e',
          tag: 'CHAT',
        );
        // Fallback to direct storage (will fail if RLS blocks)
        mediaUrl = await storageService.uploadFile(
          file: file,
          bucket: bucket,
          path: fileName,
        );
      }

      if (mediaUrl == null) {
        throw Exception('Failed to upload media');
      }

      // Get filename for content
      final originalFileName = content ?? file.path.split('/').last;

      // Get other user's ID from chat
      final chat = await supabase
          .from('chats')
          .select()
          .eq('id', chatId)
          .single();

      final otherUserId = chat['user1_id'] == currentUserId
          ? chat['user2_id']
          : chat['user1_id'];

      // Check if can send message (must be contacts)
      final canSend = AppConfig.allowSendToNonContactsForDev
          ? true
          : await _canSendMessageDirectly(currentUserId, otherUserId);
      if (!canSend) {
        throw Exception('Cannot send media: users are not contacts');
      }

      // Send message with media URL
      final messageData = await supabase
          .from('messages')
          .insert({
            'chat_id': chatId,
            'sender_id': currentUserId,
            'content': originalFileName,
            'message_type': messageType,
            'media_url': mediaUrl,
          })
          .select()
          .single();

      // Send push notification via Edge Function
      String notificationContent = messageType == 'audio'
          ? '🎤 Voice message'
          : messageType == 'image'
          ? '📷 Image'
          : messageType == 'video'
          ? '🎥 Video'
          : '📎 File';

      DebugLogger.call(
        '📤 About to send notification: recipient=$otherUserId, content=$notificationContent',
      );

      _sendNotification(
        recipientId: otherUserId,
        messageId: messageData['id'],
        content: notificationContent,
        chatId: chatId,
      );

      DebugLogger.success('📤 Media message sent successfully!');
      return MessageModel.fromJson(messageData);
    } catch (e) {
      DebugLogger.error('❌ Error in sendMediaMessage: $e', tag: 'CHAT');
      DebugLogger.error('Error sending media message: $e', tag: 'CHAT');
      return null;
    }
  }

  // Get messages for a specific chat
  // Get paginated messages (50 at a time, newest first for pagination)
  Future<List<MessageModel>> getMessagePage(String chatId, {int offset = 0, int limit = 50}) async {
    try {
      final data = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return data.map((json) => MessageModel.fromJson(json)).toList().reversed.toList();
    } catch (e) {
      DebugLogger.error('Error fetching message page: $e', tag: 'CHAT');
      return [];
    }
  }

  // Get total message count for a chat
  Future<int> getMessageCount(String chatId) async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId);
      return response.length;
    } catch (e) {
      DebugLogger.error('Error fetching message count: $e', tag: 'CHAT');
      return 0;
    }
  }

  /// Load older messages from cache (for pagination when scrolling up)
  Future<List<MessageModel>> loadMoreMessages(String chatId, {int pageSize = 50, int pageNumber = 1}) async {
    try {
      final offset = (pageNumber - 1) * pageSize;
      final messages = await _localCache.getCachedMessages(chatId, maxMessages: pageSize, offset: offset);
      
      DebugLogger.info('📜 Loaded page $pageNumber: ${messages.length} messages', tag: 'CHAT');
      return messages;
    } catch (e) {
      DebugLogger.error('❌ Error loading more messages: $e', tag: 'CHAT');
      return [];
    }
  }

  /// Get messages stream with local caching and pagination
  /// Returns cached messages immediately, then streams real-time updates
  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    final controller = StreamController<List<MessageModel>>();
    StreamSubscription? realtimeSubscription;
    bool initialLoadDone = false;

    Future<void> initialize() async {
      try {
        // 1. Load from local cache immediately (instant display)
        DebugLogger.info('📱 Loading messages from local cache...', tag: 'CHAT');
        final cachedMessages = await _localCache.getCachedMessages(chatId, maxMessages: 50);
        
        if (!controller.isClosed) {
          controller.add(cachedMessages);
        }
        initialLoadDone = true;

        // 2. Subscribe to real-time updates from server
        DebugLogger.info('🔄 Subscribing to real-time message updates...', tag: 'CHAT');
        realtimeSubscription = supabase
            .from('messages')
            .stream(primaryKey: ['id'])
            .eq('chat_id', chatId)
            .order('created_at', ascending: true)
            .listen(
              (data) async {
                try {
                  final messages = data.map((json) => MessageModel.fromJson(json)).toList();
                  
                  // Cache the messages locally
                  await _localCache.cacheMessages(chatId, messages);
                  
                  // Emit to stream
                  if (!controller.isClosed) {
                    controller.add(messages);
                  }
                  
                  DebugLogger.info('✨ Real-time update: ${messages.length} messages', tag: 'CHAT');
                } catch (e) {
                  DebugLogger.error('❌ Error processing real-time update: $e', tag: 'CHAT');
                }
              },
              onError: (error) {
                DebugLogger.error('❌ Real-time stream error: $error', tag: 'CHAT');
                // Fall back to cached messages on error
                if (!initialLoadDone && !controller.isClosed) {
                  _localCache.getCachedMessages(chatId).then((msgs) {
                    if (!controller.isClosed) controller.add(msgs);
                  });
                }
              },
            );
      } catch (e) {
        DebugLogger.error('❌ Error initializing message stream: $e', tag: 'CHAT');
        // Fallback: return cached messages
        final cached = await _localCache.getCachedMessages(chatId);
        if (!controller.isClosed) {
          controller.add(cached);
        }
      }
    }

    initialize();

    // Cleanup
    controller.onCancel = () {
      realtimeSubscription?.cancel();
    };

    return controller.stream;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Mark unread messages from other users as read
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);
    } catch (e) {
      DebugLogger.error('Failed to mark messages as read: $e', tag: 'CHAT');
    }
  }

  // Delete message (for current user only)
  Future<bool> deleteMessage(String messageId) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Only allow deletion of own messages
      await supabase
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      return true;
    } catch (e) {
      DebugLogger.error('Error deleting message: $e', tag: 'CHAT');
      return false;
    }
  }

  // Edit message (for current user only)
  Future<bool> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      // Only allow editing of own messages
      await supabase
          .from('messages')
          .update({'content': newContent})
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      return true;
    } catch (e) {
      DebugLogger.error('Error editing message: $e', tag: 'CHAT');
      return false;
    }
  }

  // Send push notification via Edge Function (fire-and-forget)
  Future<void> _sendNotification({
    required String recipientId,
    required String messageId,
    required String content,
    required String chatId,
  }) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      DebugLogger.info('🔔 Preparing to send notification to: $recipientId');

      // Get sender's profile name
      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', currentUserId)
          .single();

      final senderName = profile['display_name'] ?? 'Someone';

      DebugLogger.info('🔔 Calling Edge Function with sender: $senderName');

      // Call Edge Function (don't await - fire and forget)
      final response = await supabase.functions.invoke(
        'send-notification',
        body: {
          'type': 'direct_message',
          'userId': recipientId,
          'messageId': messageId,
          'senderId': currentUserId,
          'senderName': senderName,
          'content': content,
          'chatId': chatId,
        },
      );

      DebugLogger.info('🔔 Edge Function response: ${response.data}');
    } catch (e) {
      // Silently fail - notification is not critical
      DebugLogger.error('❌ Error sending notification: $e', tag: 'CHAT');
    }
  }

  // Search for users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;

      final trimmedQuery = query.trim();

      // Empty query returns empty results
      if (trimmedQuery.isEmpty) {
        return [];
      }

      // Try to search for exact email match first (case-insensitive)
      try {
        final emailResults = await supabase
            .from('profiles')
            .select()
            .neq('id', currentUserId)
            .ilike('email', trimmedQuery)
            .limit(5);

        // Filter to ensure truly exact match for email (case-insensitive)
        final emailMatches = emailResults.where((user) {
          final email = user['email']?.toString().toLowerCase() ?? '';
          return email.isNotEmpty && email == trimmedQuery.toLowerCase();
        }).toList();

        if (emailMatches.isNotEmpty) {
          return emailMatches.map((json) => UserModel.fromJson(json)).toList();
        }
      } catch (e) {
        // Email column might not exist yet, continue to display_name search
        DebugLogger.info('Email search skipped: $e', tag: 'SEARCH');
      }

      // Search for exact display_name match (case-insensitive)
      final displayNameResults = await supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .ilike('display_name', trimmedQuery)
          .limit(5);

      // Filter to ensure truly exact match for display_name (case-insensitive)
      final displayNameMatches = displayNameResults.where((user) {
        final displayName = user['display_name']?.toString().toLowerCase() ?? '';
        return displayName == trimmedQuery.toLowerCase();
      }).toList();

      return displayNameMatches.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // ============================================
  // MESSAGE REQUEST & SEARCH METHOD HELPERS
  // ============================================

  /// Get sender's display name for notifications
  Future<String> _getSenderDisplayName(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .single();
      return profile['display_name'] ?? 'User';
    } catch (e) {
      DebugLogger.error('Error fetching sender display name: $e', tag: 'CHAT');
      return 'Someone';
    }
  }

  /// Get sender's profile photo URL for notifications
  Future<String?> _getSenderPhotoUrl(String userId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('profile_photo_url')
          .eq('id', userId)
          .single();
      return profile['profile_photo_url'];
    } catch (e) {
      DebugLogger.error('Error fetching sender photo: $e', tag: 'CHAT');
      return null;
    }
  }

  /// Send message request notification (different from direct message notification)
  Future<void> _sendMessageRequestNotification({
    required String recipientId,
    required String senderName,
    String? senderPhotoUrl,
    required String messageId,
    required String chatId,
  }) async {
    try {
      DebugLogger.info('📬 Sending message request notification...', tag: 'CHAT');
      
      // Get FCM token for recipient
      final fcmResult = await supabase
          .from('user_tokens')
          .select('fcm_token')
          .eq('user_id', recipientId)
          .limit(1);

      if (fcmResult.isEmpty) {
        DebugLogger.info('No FCM token for recipient', tag: 'CHAT');
        return;
      }

      // Unused but checking for the presence is enough
      final fcmToken = fcmResult[0]['fcm_token'];
      if (fcmToken == null) return;

      // Call edge function to send notification
      await supabase.functions.invoke(
        'send-notification',
        body: {
          'type': 'message_request',
          'userId': recipientId,
          'messageId': messageId,
          'senderId': supabase.auth.currentUser!.id,
          'senderName': senderName,
          'senderPhotoUrl': senderPhotoUrl,
          'chatId': chatId,
          'content': '📨 $senderName sent you a message request',
        },
      );

      DebugLogger.success('✅ Message request notification sent', tag: 'CHAT');
    } catch (e) {
      DebugLogger.error('❌ Error sending message request notification: $e', tag: 'CHAT');
      // Don't throw - notifications are non-critical
    }
  }

  /// Search users by email (for direct messaging)
  Future<List<UserModel>> searchByEmail(String query) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final trimmedQuery = query.trim().toLowerCase();

      if (trimmedQuery.isEmpty) {
        return [];
      }

      final emailResults = await supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .ilike('email', trimmedQuery)
          .limit(5);

      final emailMatches = emailResults.where((user) {
        final email = user['email']?.toString().toLowerCase() ?? '';
        return email.isNotEmpty && email == trimmedQuery;
      }).toList();

      DebugLogger.info('📧 Email search found ${emailMatches.length} users', tag: 'SEARCH');
      return emailMatches.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      DebugLogger.error('Error searching by email: $e', tag: 'SEARCH');
      return [];
    }
  }

  /// Search users by name (for message requests)
  Future<List<UserModel>> searchByName(String query) async {
    try {
      final currentUserId = supabase.auth.currentUser!.id;
      final trimmedQuery = query.trim().toLowerCase();

      if (trimmedQuery.isEmpty) {
        return [];
      }

      final nameResults = await supabase
          .from('profiles')
          .select()
          .neq('id', currentUserId)
          .ilike('display_name', trimmedQuery)
          .limit(5);

      final nameMatches = nameResults.where((user) {
        final displayName = user['display_name']?.toString().toLowerCase() ?? '';
        return displayName == trimmedQuery;
      }).toList();

      DebugLogger.info('👤 Name search found ${nameMatches.length} users', tag: 'SEARCH');
      return nameMatches.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      DebugLogger.error('Error searching by name: $e', tag: 'SEARCH');
      return [];
    }
  }

  /// Check if message is a pending request
  Future<bool> isMessageRequest(String messageId) async {
    try {
      final message = await supabase
          .from('messages')
          .select('is_request')
          .eq('id', messageId)
          .single();
      return message['is_request'] ?? false;
    } catch (e) {
      DebugLogger.error('Error checking if message is request: $e', tag: 'CHAT');
      return false;
    }
  }

  /// Get message search method (email or name)
  Future<String> getMessageSearchMethod(String messageId) async {
    try {
      final message = await supabase
          .from('messages')
          .select('search_method')
          .eq('id', messageId)
          .single();
      return message['search_method'] ?? 'name';
    } catch (e) {
      DebugLogger.error('Error getting message search method: $e', tag: 'CHAT');
      return 'name';
    }
  }

  /// Delete a chat and all associated messages
  Future<bool> deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat first
      await supabase
          .from('messages')
          .delete()
          .eq('chat_id', chatId);

      // Delete the chat itself
      await supabase
          .from('chats')
          .delete()
          .eq('id', chatId);

      DebugLogger.info('✅ Chat deleted: $chatId', tag: 'CHAT');
      return true;
    } catch (e) {
      DebugLogger.error('Error deleting chat: $e', tag: 'CHAT');
      return false;
    }
  }
}

