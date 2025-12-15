import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';
import '../utils/debug_logger.dart';

/// Service for caching messages locally and managing offline queue
class LocalMessageCacheService {
  static final LocalMessageCacheService _instance = LocalMessageCacheService._internal();
  factory LocalMessageCacheService() => _instance;
  LocalMessageCacheService._internal();

  Database? _db;

  /// Initialize the local database
  Future<void> initialize() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'zinchat_messages.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          // Create messages cache table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_messages (
              id TEXT PRIMARY KEY,
              chat_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              content TEXT NOT NULL,
              message_type TEXT DEFAULT 'text',
              media_url TEXT,
              search_method TEXT,
              is_request INTEGER DEFAULT 0,
              is_read INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              synced INTEGER DEFAULT 1
            );
            CREATE INDEX IF NOT EXISTS idx_chat_id ON cached_messages(chat_id);
            CREATE INDEX IF NOT EXISTS idx_created_at ON cached_messages(created_at);
          ''');

          // Create offline queue table (for messages to send)
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_queue (
              id TEXT PRIMARY KEY,
              chat_id TEXT NOT NULL,
              content TEXT NOT NULL,
              message_type TEXT DEFAULT 'text',
              media_url TEXT,
              search_method TEXT,
              created_at TEXT NOT NULL,
              retry_count INTEGER DEFAULT 0
            );
          ''');
        },
      );

      DebugLogger.success('✅ Local message cache initialized', tag: 'CACHE');
    } catch (e) {
      DebugLogger.error('❌ Error initializing local cache: $e', tag: 'CACHE');
    }
  }

  /// Cache messages from server
  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    if (_db == null) return;
    
    try {
      final batch = _db!.batch();
      
      for (final msg in messages) {
        batch.insert(
          'cached_messages',
          {
            'id': msg.id,
            'chat_id': chatId,
            'sender_id': msg.senderId,
            'content': msg.content,
            'message_type': msg.messageType,
            'media_url': msg.mediaUrl,
            'created_at': msg.createdAt.toIso8601String(),
            'is_read': msg.isRead ? 1 : 0,
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit();
      DebugLogger.info('💾 Cached ${messages.length} messages for chat: $chatId', tag: 'CACHE');
    } catch (e) {
      DebugLogger.error('❌ Error caching messages: $e', tag: 'CACHE');
    }
  }

  /// Get cached messages for a chat (latest first, limited to maxMessages)
  Future<List<MessageModel>> getCachedMessages(String chatId, {int maxMessages = 50, int offset = 0}) async {
    if (_db == null) return [];
    
    try {
      final result = await _db!.query(
        'cached_messages',
        where: 'chat_id = ?',
        whereArgs: [chatId],
        orderBy: 'created_at DESC',
        limit: maxMessages,
        offset: offset,
      );

      final messages = result
          .map((row) => MessageModel(
            id: row['id'] as String,
            chatId: row['chat_id'] as String,
            senderId: row['sender_id'] as String,
            content: row['content'] as String,
            messageType: row['message_type'] as String? ?? 'text',
            mediaUrl: row['media_url'] as String?,
            isRead: (row['is_read'] as int?) == 1,
            createdAt: DateTime.parse(row['created_at'] as String),
          ))
          .toList()
          .reversed
          .toList();

      return messages;
    } catch (e) {
      DebugLogger.error('❌ Error retrieving cached messages: $e', tag: 'CACHE');
      return [];
    }
  }

  /// Add message to offline queue
  Future<void> addToOfflineQueue(String chatId, MessageModel message) async {
    if (_db == null) return;
    
    try {
      await _db!.insert(
        'offline_queue',
        {
          'id': message.id,
          'chat_id': chatId,
          'content': message.content,
          'message_type': message.messageType,
          'media_url': message.mediaUrl,
          'created_at': message.createdAt.toIso8601String(),
          'retry_count': 0,
        },
      );
      
      DebugLogger.info('📤 Added message to offline queue: ${message.id}', tag: 'OFFLINE');
    } catch (e) {
      DebugLogger.error('❌ Error adding to offline queue: $e', tag: 'OFFLINE');
    }
  }

  /// Get pending offline messages
  Future<List<Map<String, dynamic>>> getPendingOfflineMessages() async {
    if (_db == null) return [];
    
    try {
      final result = await _db!.query(
        'offline_queue',
        orderBy: 'created_at ASC',
      );
      
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      DebugLogger.error('❌ Error getting offline messages: $e', tag: 'OFFLINE');
      return [];
    }
  }

  /// Remove message from offline queue (after successful send)
  Future<void> removeFromOfflineQueue(String messageId) async {
    if (_db == null) return;
    
    try {
      await _db!.delete(
        'offline_queue',
        where: 'id = ?',
        whereArgs: [messageId],
      );
      
      DebugLogger.info('✅ Removed from offline queue: $messageId', tag: 'OFFLINE');
    } catch (e) {
      DebugLogger.error('❌ Error removing from offline queue: $e', tag: 'OFFLINE');
    }
  }

  /// Increment retry count
  Future<void> incrementRetryCount(String messageId) async {
    if (_db == null) return;
    
    try {
      await _db!.rawUpdate(
        'UPDATE offline_queue SET retry_count = retry_count + 1 WHERE id = ?',
        [messageId],
      );
    } catch (e) {
      DebugLogger.error('❌ Error updating retry count: $e', tag: 'OFFLINE');
    }
  }

  /// Clear old cached messages (older than 30 days)
  Future<void> clearOldMessages({int daysOld = 30}) async {
    if (_db == null) return;
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      await _db!.delete(
        'cached_messages',
        where: 'created_at < ? AND synced = 1',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      DebugLogger.info('🗑️ Cleared old messages older than $daysOld days', tag: 'CACHE');
    } catch (e) {
      DebugLogger.error('❌ Error clearing old messages: $e', tag: 'CACHE');
    }
  }

  /// Close database
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
