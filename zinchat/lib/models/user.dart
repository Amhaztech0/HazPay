// User model representing a user profile
class UserModel {
  final String id;
  final String? phoneNumber;
  final String displayName;
  final String about;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeen;
  final String messagingPrivacy; // 'everyone' or 'approved_only'

  UserModel({
    required this.id,
    this.phoneNumber,
    required this.displayName,
    this.about = 'Hey there! I am using ZinChat.',
    this.profilePhotoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastSeen,
    this.messagingPrivacy = 'everyone',
  });

  // Check if user is currently online (active within last 2 minutes)
  bool get isOnline {
    if (lastSeen == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    return difference.inMinutes < 2;
  }

  // Get formatted last seen text
  String get lastSeenText {
    if (lastSeen == null) return 'last seen recently';
    if (isOnline) return 'online';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inMinutes < 60) {
      return 'last seen ${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return 'last seen ${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'last seen yesterday';
    } else if (difference.inDays < 7) {
      return 'last seen ${difference.inDays} days ago';
    } else {
      return 'last seen recently';
    }
  }

  // Create UserModel from Supabase JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String?;
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String?,
      displayName: (displayName == null || displayName.isEmpty) 
          ? 'ZinChat User' 
          : displayName,
      about: json['about'] as String? ?? 'Hey there! I am using ZinChat.',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      messagingPrivacy: json['messaging_privacy'] as String? ?? 'everyone',
    );
  }

  // Convert UserModel to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'about': about,
      'profile_photo_url': profilePhotoUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? displayName,
    String? about,
    String? profilePhotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeen,
    String? messagingPrivacy,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      messagingPrivacy: messagingPrivacy ?? this.messagingPrivacy,
    );
  }
}