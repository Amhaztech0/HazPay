import 'user_model.dart';

// Status privacy enum
enum StatusPrivacy {
  public,      // All ZinChat users can see
  mutuals,     // Only users you've chatted with
}

// Status update model
class StatusUpdate {
  final String id;
  final String userId;
  final String? content;
  final String? mediaUrl;
  final String mediaType; // 'image', 'video', 'text'
  final String? backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String privacy; // 'public' or 'mutuals'
  
  // Additional fields
  final UserModel? user;
  final int viewCount;
  final bool hasViewed;
  final int replyCount;

  StatusUpdate({
    required this.id,
    required this.userId,
    this.content,
    this.mediaUrl,
    required this.mediaType,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.privacy = 'public',
    this.user,
    this.viewCount = 0,
    this.hasViewed = false,
    this.replyCount = 0,
  });

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String,
      backgroundColor: json['background_color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      privacy: json['privacy'] as String? ?? 'public',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'background_color': backgroundColor,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'privacy': privacy,
    };
  }

  StatusUpdate copyWith({
    String? id,
    String? userId,
    String? content,
    String? mediaUrl,
    String? mediaType,
    String? backgroundColor,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? privacy,
    UserModel? user,
    int? viewCount,
    bool? hasViewed,
    int? replyCount,
  }) {
    return StatusUpdate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      privacy: privacy ?? this.privacy,
      user: user ?? this.user,
      viewCount: viewCount ?? this.viewCount,
      hasViewed: hasViewed ?? this.hasViewed,
      replyCount: replyCount ?? this.replyCount,
    );
  }

  // Check if status is still active
  bool get isActive {
    return DateTime.now().isBefore(expiresAt);
  }

  // Get time remaining
  Duration get timeRemaining {
    return expiresAt.difference(DateTime.now());
  }
}

// Group statuses by user
class UserStatusGroup {
  final UserModel user;
  final List<StatusUpdate> statuses;
  final bool hasViewed;

  UserStatusGroup({
    required this.user,
    required this.statuses,
    required this.hasViewed,
  });

  // Get most recent status
  StatusUpdate get latestStatus => statuses.first;

  // Get total view count
  int get totalViews {
    return statuses.fold(0, (sum, status) => sum + status.viewCount);
  }
}