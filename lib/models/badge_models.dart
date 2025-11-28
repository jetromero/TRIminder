import 'dart:convert';
// Badge system matching Supabase badges table

enum BadgeCategory {
  daily,
  weekly,
  monthly,
  streak,
  milestone,
  social,
  special;

  String toJson() => name;
  static BadgeCategory fromJson(String json) => BadgeCategory.values.firstWhere(
        (e) => e.name == json,
        orElse: () => BadgeCategory.daily,
      );
}

enum BadgeRarity {
  common,
  rare,
  epic,
  legendary;

  String toJson() => name;
  static BadgeRarity fromJson(String json) => BadgeRarity.values.firstWhere(
        (e) => e.name == json,
        orElse: () => BadgeRarity.common,
      );
}

class Badge {
  final int id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int xpReward;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final int? requiredValue;
  final Map<String, dynamic>? unlockConditions;

  Badge({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.xpReward,
    required this.category,
    required this.rarity,
    this.requiredValue,
    this.unlockConditions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'xpReward': xpReward,
      'category': category.toJson(),
      'rarity': rarity.toJson(),
      'requiredValue': requiredValue,
      'unlockConditions': unlockConditions != null
          ? unlockConditions.toString()
          : null,
    };
  }

  factory Badge.fromMap(Map<String, dynamic> map) {
    // Parse unlockConditions if stored as string
    Map<String, dynamic>? unlockConditions;
    if (map['unlockConditions'] != null) {
      if (map['unlockConditions'] is Map) {
        unlockConditions = Map<String, dynamic>.from(
            map['unlockConditions'] as Map<dynamic, dynamic>);
      } else if (map['unlockConditions'] is String) {
        try {
          final decoded = jsonDecode(map['unlockConditions'] as String);
          if (decoded is Map<String, dynamic>) {
            unlockConditions = decoded;
          }
        } catch (_) {
          unlockConditions = null;
        }
      }
    }

    return Badge(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      name: map['name']?.toString() ?? 'Unknown Badge',
      description: map['description']?.toString(),
      iconUrl: map['iconUrl']?.toString() ?? map['iconPath']?.toString(),
      xpReward: map['xpReward'] is int 
          ? map['xpReward'] 
          : (map['xp_reward'] is int ? map['xp_reward'] : 0),
      category: map['category'] != null
          ? BadgeCategory.fromJson(map['category'].toString())
          : BadgeCategory.daily,
      rarity: map['rarity'] != null
          ? BadgeRarity.fromJson(map['rarity'].toString())
          : BadgeRarity.common,
      requiredValue: map['requiredValue'] is int 
          ? map['requiredValue'] 
          : (map['required_value'] is int ? map['required_value'] : null),
      unlockConditions: unlockConditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'xp_reward': xpReward,
      'category': category.toJson(),
      'rarity': rarity.toJson(),
      'required_value': requiredValue,
      'unlock_conditions': unlockConditions,
    };
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Unknown Badge',
      description: json['description']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      xpReward: json['xp_reward'] ?? 0,
      category: json['category'] != null
          ? BadgeCategory.fromJson(json['category'].toString())
          : BadgeCategory.daily,
      rarity: json['rarity'] != null
          ? BadgeRarity.fromJson(json['rarity'].toString())
          : BadgeRarity.common,
      requiredValue: json['required_value'],
      unlockConditions: json['unlock_conditions'] != null
          ? (json['unlock_conditions'] is Map
              ? json['unlock_conditions'] as Map<String, dynamic>
              : null)
          : null,
    );
  }

  Badge copyWith({
    int? id,
    String? name,
    String? description,
    String? iconUrl,
    int? xpReward,
    BadgeCategory? category,
    BadgeRarity? rarity,
    int? requiredValue,
    Map<String, dynamic>? unlockConditions,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      xpReward: xpReward ?? this.xpReward,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      requiredValue: requiredValue ?? this.requiredValue,
      unlockConditions: unlockConditions ?? this.unlockConditions,
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
      userId: map['userId']?.toString() ?? '',
      badgeId: map['badgeId'] is int
          ? map['badgeId']
          : int.tryParse(map['badgeId']?.toString() ?? '0') ?? 0,
      awardedAt: DateTime.parse(
          map['awardedAt'] ?? map['earnedAt'] ?? DateTime.now().toIso8601String()),
      isSynced: (map['isSynced'] as int? ?? 0) == 1,
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
      userId: json['user_id']?.toString() ?? '',
      badgeId: json['badge_id'] is int
          ? json['badge_id']
          : int.tryParse(json['badge_id']?.toString() ?? '0') ?? 0,
      awardedAt: DateTime.parse(json['awarded_at'] ?? json['earned_at']),
      isSynced: true,
    );
  }

  UserBadge copyWith({
    String? userId,
    int? badgeId,
    DateTime? awardedAt,
    bool? isSynced,
  }) {
    return UserBadge(
      userId: userId ?? this.userId,
      badgeId: badgeId ?? this.badgeId,
      awardedAt: awardedAt ?? this.awardedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
