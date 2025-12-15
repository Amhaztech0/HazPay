// Message model representing a chat message
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String messageType; // text, image, video, audio, file
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    required this.createdAt,
    this.isRead = false,
  });

  // Create MessageModel from Supabase JSON
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  // Convert MessageModel to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  // Create a copy with updated fields
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? content,
    String? messageType,
    String? mediaUrl,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}