import 'user_model.dart';

// Blocked user model
class BlockedUser {
  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;
  
  // Additional fields
  final UserModel? blockedUser;

  BlockedUser({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
    this.blockedUser,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      blockedUser: json['blocked_user'] != null 
          ? UserModel.fromJson(json['blocked_user']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    };
  }

  BlockedUser copyWith({
    String? id,
    String? blockerId,
    String? blockedId,
    DateTime? createdAt,
    UserModel? blockedUser,
  }) {
    return BlockedUser(
      id: id ?? this.id,
      blockerId: blockerId ?? this.blockerId,
      blockedId: blockedId ?? this.blockedId,
      createdAt: createdAt ?? this.createdAt,
      blockedUser: blockedUser ?? this.blockedUser,
    );
  }
}
