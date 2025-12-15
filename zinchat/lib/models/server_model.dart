class ServerModel {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String ownerId;
  final bool isPublic;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletionScheduledAt;
  final String? deletionScheduledBy;

  ServerModel({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.ownerId,
    required this.isPublic,
    required this.memberCount,
    required this.createdAt,
    this.updatedAt,
    this.deletionScheduledAt,
    this.deletionScheduledBy,
  });

  factory ServerModel.fromJson(Map<String, dynamic> json) {
    return ServerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      ownerId: json['owner_id'] as String,
      isPublic: json['is_public'] as bool? ?? false,
      deletionScheduledAt: json['deletion_scheduled_at'] != null
          ? DateTime.parse(json['deletion_scheduled_at'] as String)
          : null,
      deletionScheduledBy: json['deletion_scheduled_by'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'owner_id': ownerId,
      'is_public': isPublic,
      'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ServerMemberModel {
  final String id;
  final String serverId;
  final String userId;
  final String role; // owner, admin, member
  final DateTime joinedAt;
  final UserProfile? user; // User profile information

  ServerMemberModel({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.user,
  });

  factory ServerMemberModel.fromJson(Map<String, dynamic> json) {
    // Handle profiles - it might be a list or a single object
    dynamic profilesData = json['profiles'];
    UserProfile? userProfile;
    
    if (profilesData != null) {
      if (profilesData is List && profilesData.isNotEmpty) {
        userProfile = UserProfile.fromJson(profilesData[0] as Map<String, dynamic>);
      } else if (profilesData is Map) {
        userProfile = UserProfile.fromJson(profilesData as Map<String, dynamic>);
      }
    }
    
    return ServerMemberModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      user: userProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      if (user != null) 'profiles': user!.toJson(),
    };
  }
}

// Simple user profile for server members
class UserProfile {
  final String id;
  final String? fullName;
  final String? profilePhotoUrl;
  final String? about;

  UserProfile({
    required this.id,
    this.fullName,
    this.profilePhotoUrl,
    this.about,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      // Try display_name first, fallback to full_name
      fullName: json['display_name'] as String? ?? json['full_name'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      about: json['about'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'profile_photo_url': profilePhotoUrl,
    };
  }
}

class ServerInviteModel {
  final String id;
  final String serverId;
  final String inviteCode;
  final String createdBy;
  final DateTime? expiresAt;
  final int? maxUses;
  final int currentUses;
  final bool isActive;
  final DateTime createdAt;

  ServerInviteModel({
    required this.id,
    required this.serverId,
    required this.inviteCode,
    required this.createdBy,
    this.expiresAt,
    this.maxUses,
    required this.currentUses,
    required this.isActive,
    required this.createdAt,
  });

  factory ServerInviteModel.fromJson(Map<String, dynamic> json) {
    return ServerInviteModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      inviteCode: json['invite_code'] as String,
      createdBy: json['created_by'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      maxUses: json['max_uses'] as int?,
      currentUses: json['current_uses'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'expires_at': expiresAt?.toIso8601String(),
      'max_uses': maxUses,
      'current_uses': currentUses,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isMaxedOut => maxUses != null && currentUses >= maxUses!;
  bool get isValid => isActive && !isExpired && !isMaxedOut;
}

class ServerMessageModel {
  final String id;
  final String serverId;
  final String userId;
  final String content;
  final String messageType; // text, image, video, audio, file
  final String? mediaUrl;
  final String? replyToMessageId;
  final String? channelId; // Channel this message belongs to
  final DateTime createdAt;
  ServerMessageReply? repliedTo; // The message this is replying to (non-final for lazy loading)

  ServerMessageModel({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.replyToMessageId,
    this.channelId,
    required this.createdAt,
    this.repliedTo,
  });

  factory ServerMessageModel.fromJson(Map<String, dynamic> json) {
    return ServerMessageModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String?,
      channelId: json['channel_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      repliedTo: json['reply_message'] != null
          ? ServerMessageReply.fromJson(json['reply_message'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'user_id': userId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'reply_to_message_id': replyToMessageId,
      'channel_id': channelId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MessageReactionModel {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReactionModel({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) {
    return MessageReactionModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Model for showing replied message info
class ServerMessageReply {
  final String id;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final String senderName;
  final String? senderAvatar;

  ServerMessageReply({
    required this.id,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    required this.senderName,
    this.senderAvatar,
  });

  factory ServerMessageReply.fromJson(Map<String, dynamic> json) {
    return ServerMessageReply(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      senderName: json['sender_display_name'] as String? ?? 'Unknown User',
      senderAvatar: json['sender_profile_photo_url'] as String?,
    );
  }
}
