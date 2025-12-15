import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main.dart';
import '../utils/debug_logger.dart';
import '../models/message_model.dart';
import 'local_message_cache_service.dart';
import 'chat_service.dart';

/// Offline Message Queue Processor
/// Automatically sends queued messages when connectivity is restored
/// Similar to WhatsApp's "clock icon" messages that send when online
class OfflineMessageProcessor {
  static final OfflineMessageProcessor _instance = OfflineMessageProcessor._internal();
  factory OfflineMessageProcessor() => _instance;
  OfflineMessageProcessor._internal();

  final _cacheService = LocalMessageCacheService();
  final _chatService = ChatService();
  
  bool _isProcessing = false;
  Timer? _processingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initialize offline processor
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((result) => 
        result != ConnectivityResult.none
      );
      
      if (isConnected) {
        DebugLogger.info('📶 Connectivity restored - processing offline queue', tag: 'OFFLINE');
        processOfflineQueue();
      }
    });

    // Also check periodically (every 30 seconds)
    _processingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processOfflineQueue();
    });

    // Process any existing queue on startup
    await processOfflineQueue();
  }

  /// Process all pending offline messages
  Future<void> processOfflineQueue() async {
    if (_isProcessing) {
      DebugLogger.info('⏳ Already processing offline queue', tag: 'OFFLINE');
      return;
    }

    try {
      _isProcessing = true;

      // Check connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      final isConnected = connectivityResults.any((result) => 
        result != ConnectivityResult.none
      );

      if (!isConnected) {
        DebugLogger.info('📵 No connectivity - skipping offline queue', tag: 'OFFLINE');
        _isProcessing = false;
        return;
      }

      // Get pending messages
      final pendingMessages = await _cacheService.getPendingOfflineMessages();
      
      if (pendingMessages.isEmpty) {
        _isProcessing = false;
        return;
      }

      DebugLogger.info('📤 Processing ${pendingMessages.length} offline messages', tag: 'OFFLINE');

      // Process each message
      for (final msgData in pendingMessages) {
        try {
          final messageId = msgData['id'] as String;
          final chatId = msgData['chat_id'] as String;
          final content = msgData['content'] as String;
          final messageType = msgData['message_type'] as String? ?? 'text';
          final mediaUrl = msgData['media_url'] as String?;
          final retryCount = msgData['retry_count'] as int? ?? 0;

          // Skip if too many retries
          if (retryCount > 5) {
            DebugLogger.error('❌ Too many retries for message: $messageId', tag: 'OFFLINE');
            await _cacheService.removeFromOfflineQueue(messageId);
            continue;
          }

          // Attempt to send
          DebugLogger.info('📤 Sending offline message: $messageId (retry: $retryCount)', tag: 'OFFLINE');
          
          final sentMessage = await _chatService.sendMessage(
            chatId: chatId,
            content: content,
            messageType: messageType,
            mediaUrl: mediaUrl,
          );

          if (sentMessage != null) {
            // Success - remove from queue
            await _cacheService.removeFromOfflineQueue(messageId);
            DebugLogger.success('✅ Offline message sent successfully: $messageId', tag: 'OFFLINE');
          } else {
            // Failed - increment retry count
            await _cacheService.incrementRetryCount(messageId);
            DebugLogger.error('❌ Failed to send offline message: $messageId', tag: 'OFFLINE');
          }

          // Small delay between sends to avoid overwhelming server
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          DebugLogger.error('❌ Error processing offline message: $e', tag: 'OFFLINE');
          
          // Increment retry count on error
          final messageId = msgData['id'] as String;
          await _cacheService.incrementRetryCount(messageId);
        }
      }

      DebugLogger.success('✅ Offline queue processing complete', tag: 'OFFLINE');
    } catch (e) {
      DebugLogger.error('❌ Error in offline queue processor: $e', tag: 'OFFLINE');
    } finally {
      _isProcessing = false;
    }
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
