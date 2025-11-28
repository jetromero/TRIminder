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
  final List<int>? levelThresholds;

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
    this.levelThresholds,
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
      'levelThresholds': levelThresholds != null
          ? jsonEncode(levelThresholds)
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

    // Parse levelThresholds if stored as string or JSON
    List<int>? levelThresholds;
    if (map['levelThresholds'] != null) {
      if (map['levelThresholds'] is List) {
        levelThresholds = (map['levelThresholds'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      } else if (map['levelThresholds'] is String) {
        try {
          final decoded = jsonDecode(map['levelThresholds'] as String);
          if (decoded is List) {
            levelThresholds = decoded
                .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                .where((e) => e > 0)
                .cast<int>()
                .toList();
          }
        } catch (_) {
          levelThresholds = null;
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
      levelThresholds: levelThresholds,
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
      'level_thresholds': levelThresholds,
    };
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    // Parse levelThresholds from JSON
    List<int>? levelThresholds;
    if (json['level_thresholds'] != null) {
      if (json['level_thresholds'] is List) {
        levelThresholds = (json['level_thresholds'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e > 0)
            .toList();
      }
    }

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
      levelThresholds: levelThresholds,
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
    List<int>? levelThresholds,
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
      levelThresholds: levelThresholds ?? this.levelThresholds,
    );
  }

  /// Calculate the level based on completion count and thresholds
  /// Returns the level (1-5) based on how many times the badge has been completed
  /// Returns 1 if thresholds are null or empty
  int getLevelForCompletions(int completionCount) {
    if (levelThresholds == null || levelThresholds!.isEmpty) {
      return 1;
    }

    // Find the highest threshold that the count has reached
    int level = 1;
    for (int i = 0; i < levelThresholds!.length; i++) {
      if (completionCount >= levelThresholds![i]) {
        level = i + 1; // Level is 1-indexed
      } else {
        break;
      }
    }

    return level;
  }
}

// User earned badges matching Supabase user_badges table
class UserBadge {
  final String userId;
  final int badgeId;
  final DateTime awardedAt;
  final int level;
  final int completionCount;
  final bool isSynced;

  UserBadge({
    required this.userId,
    required this.badgeId,
    required this.awardedAt,
    this.level = 1,
    this.completionCount = 1,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'badgeId': badgeId,
      'awardedAt': awardedAt.toIso8601String(),
      'level': level,
      'completionCount': completionCount,
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
      level: map['level'] is int
          ? map['level']
          : (map['level'] != null ? int.tryParse(map['level'].toString()) ?? 1 : 1),
      completionCount: map['completionCount'] is int
          ? map['completionCount']
          : (map['completionCount'] != null ? int.tryParse(map['completionCount'].toString()) ?? 1 : 1),
      isSynced: (map['isSynced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
      'awarded_at': awardedAt.toIso8601String(),
      'level': level,
      'completion_count': completionCount,
    };
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      userId: json['user_id']?.toString() ?? '',
      badgeId: json['badge_id'] is int
          ? json['badge_id']
          : int.tryParse(json['badge_id']?.toString() ?? '0') ?? 0,
      awardedAt: DateTime.parse(json['awarded_at'] ?? json['earned_at']),
      level: json['level'] is int
          ? json['level']
          : (json['level'] != null ? int.tryParse(json['level'].toString()) ?? 1 : 1),
      completionCount: json['completion_count'] is int
          ? json['completion_count']
          : (json['completion_count'] != null ? int.tryParse(json['completion_count'].toString()) ?? 1 : 1),
      isSynced: true,
    );
  }

  UserBadge copyWith({
    String? userId,
    int? badgeId,
    DateTime? awardedAt,
    int? level,
    int? completionCount,
    bool? isSynced,
  }) {
    return UserBadge(
      userId: userId ?? this.userId,
      badgeId: badgeId ?? this.badgeId,
      awardedAt: awardedAt ?? this.awardedAt,
      level: level ?? this.level,
      completionCount: completionCount ?? this.completionCount,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
