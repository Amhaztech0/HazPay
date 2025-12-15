// Server member moderation model
class ServerModerationModel {
  final String id;
  final String serverId;
  final String userId;
  final String moderationType; // 'ban', 'mute', 'timeout'
  final String? reason;
  final String moderatorId;
  final DateTime? expiresAt;
  final DateTime createdAt;

  ServerModerationModel({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.moderationType,
    this.reason,
    required this.moderatorId,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false; // Permanent
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isPermanent => expiresAt == null;

  String get formattedDuration {
    if (isPermanent) return 'Permanent';
    if (isExpired) return 'Expired';
    
    final duration = expiresAt!.difference(DateTime.now());
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  factory ServerModerationModel.fromJson(Map<String, dynamic> json) {
    return ServerModerationModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      userId: json['user_id'] as String,
      moderationType: json['moderation_type'] as String,
      reason: json['reason'] as String?,
      moderatorId: json['moderator_id'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'moderation_type': moderationType,
      'reason': reason,
      'moderator_id': moderatorId,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
