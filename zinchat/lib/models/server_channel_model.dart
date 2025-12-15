class ServerChannelModel {
  final String id;
  final String serverId;
  final String name;
  final String? description;
  final String channelType; // 'text', 'voice', 'announcements'
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int position;

  ServerChannelModel({
    required this.id,
    required this.serverId,
    required this.name,
    this.description,
    this.channelType = 'text',
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.position = 0,
  });

  factory ServerChannelModel.fromJson(Map<String, dynamic> json) {
    return ServerChannelModel(
      id: json['id'] as String,
      serverId: json['server_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      channelType: json['channel_type'] as String? ?? 'text',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'description': description,
      'channel_type': channelType,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'position': position,
    };
  }

  ServerChannelModel copyWith({
    String? id,
    String? serverId,
    String? name,
    String? description,
    String? channelType,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? position,
  }) {
    return ServerChannelModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      description: description ?? this.description,
      channelType: channelType ?? this.channelType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      position: position ?? this.position,
    );
  }
}
