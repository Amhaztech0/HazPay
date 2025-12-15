import 'user_model.dart';
import 'message_model.dart';

// Chat model representing a one-on-one conversation
class ChatModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;
  
  // Additional fields (not from database)
  final UserModel? otherUser; // The other person in the chat
  final MessageModel? lastMessage; // Most recent message
  final int unreadCount; // Number of unread messages

  ChatModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  // Create ChatModel from Supabase JSON
  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Convert ChatModel to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  ChatModel copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
    UserModel? otherUser,
    MessageModel? lastMessage,
    int? unreadCount,
  }) {
    return ChatModel(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}