// Badge system matching Supabase badges table
class Badge {
  final int id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int xpReward;

  Badge({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.xpReward,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'xpReward': xpReward,
    };
  }

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      iconUrl: map['iconUrl'],
      xpReward: map['xpReward'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'xp_reward': xpReward,
    };
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconUrl: json['icon_url'],
      xpReward: json['xp_reward'],
    );
  }
}

// User earned badges matching Supabase user_badges table
class UserBadge {
  final String userId;
  final int badgeId;
  final DateTime awardedAt;
  final bool isSynced;

  UserBadge({
    required this.userId,
    required this.badgeId,
    required this.awardedAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'badgeId': badgeId,
      'awardedAt': awardedAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory UserBadge.fromMap(Map<String, dynamic> map) {
    return UserBadge(
      userId: map['userId'],
      badgeId: map['badgeId'],
      awardedAt: DateTime.parse(map['awardedAt']),
      isSynced: map['isSynced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'awarded_at': awardedAt.toIso8601String(),
    };
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      userId: json['user_id'],
      badgeId: json['badge_id'],
      awardedAt: DateTime.parse(json['awarded_at']),
      isSynced: true,
    );
  }
}
