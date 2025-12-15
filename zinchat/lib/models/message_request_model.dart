import 'user_model.dart';

// Message request model for Discord-like message request system
class MessageRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String? firstMessageId;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Additional fields
  final UserModel? sender;
  final String? firstMessageContent;

  MessageRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.firstMessageId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.firstMessageContent,
  });

  factory MessageRequest.fromJson(Map<String, dynamic> json) {
    return MessageRequest(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      firstMessageId: json['first_message_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sender: json['sender'] != null ? UserModel.fromJson(json['sender']) : null,
      firstMessageContent: json['first_message_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'first_message_id': firstMessageId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  MessageRequest copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? firstMessageId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? sender,
    String? firstMessageContent,
  }) {
    return MessageRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      firstMessageId: firstMessageId ?? this.firstMessageId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sender: sender ?? this.sender,
      firstMessageContent: firstMessageContent ?? this.firstMessageContent,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}
