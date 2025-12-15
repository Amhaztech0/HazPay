import 'user_model.dart';

class StatusReply {
  final String id;
  final String statusId;
  final String userId;
  final String content;
  final String replyType; // 'text' or 'emoji'
  final DateTime createdAt;
  final String? parentReplyId; // For threaded replies
  
  // Additional fields
  final UserModel? user;
  final String? parentReplyUsername;
  final String? parentReplyContent;

  StatusReply({
    required this.id,
    required this.statusId,
    required this.userId,
    required this.content,
    required this.replyType,
    required this.createdAt,
    this.user,
    this.parentReplyId,
    this.parentReplyUsername,
    this.parentReplyContent,
  });

  factory StatusReply.fromJson(Map<String, dynamic> json) {
    return StatusReply(
      id: json['id'] as String,
      statusId: json['status_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      replyType: json['reply_type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      parentReplyId: json['parent_reply_id'] as String?,
      parentReplyUsername: json['parent_reply_username'] as String?,
      parentReplyContent: json['parent_reply_content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status_id': statusId,
      'user_id': userId,
      'content': content,
      'reply_type': replyType,
      if (parentReplyId != null) 'parent_reply_id': parentReplyId,
    };
  }

  StatusReply copyWith({
    String? id,
    String? statusId,
    String? userId,
    String? content,
    String? replyType,
    DateTime? createdAt,
    UserModel? user,
    String? parentReplyId,
    String? parentReplyUsername,
    String? parentReplyContent,
  }) {
    return StatusReply(
      id: id ?? this.id,
      statusId: statusId ?? this.statusId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      replyType: replyType ?? this.replyType,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      parentReplyUsername: parentReplyUsername ?? this.parentReplyUsername,
      parentReplyContent: parentReplyContent ?? this.parentReplyContent,
    );
  }
}
