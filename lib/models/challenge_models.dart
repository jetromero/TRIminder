import 'dart:convert';
import 'badge_models.dart';

enum ChallengeResetInterval {
  daily,
  weekly,
  monthly,
  streak,
  milestone,
  social,
  special;

  String toJson() => name;

  static ChallengeResetInterval fromJson(String value) {
    return ChallengeResetInterval.values.firstWhere(
      (interval) => interval.name == value,
      orElse: () => ChallengeResetInterval.daily,
    );
  }

  static ChallengeResetInterval fromBadgeCategory(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.daily:
        return ChallengeResetInterval.daily;
      case BadgeCategory.weekly:
        return ChallengeResetInterval.weekly;
      case BadgeCategory.monthly:
        return ChallengeResetInterval.monthly;
      case BadgeCategory.streak:
        return ChallengeResetInterval.streak;
      case BadgeCategory.milestone:
        return ChallengeResetInterval.milestone;
      case BadgeCategory.social:
        return ChallengeResetInterval.social;
      case BadgeCategory.special:
        return ChallengeResetInterval.special;
    }
  }
}

class Challenge {
  final int id;
  final int badgeId;
  final String title;
  final String? description;
  final BadgeCategory category;
  final ChallengeResetInterval resetInterval;
  final int? targetValue;
  final Map<String, dynamic>? metadata;
  final int sortOrder;
  final bool isActive;
  final Badge? badge;

  const Challenge({
    required this.id,
    required this.badgeId,
    required this.title,
    required this.category,
    required this.resetInterval,
    this.description,
    this.targetValue,
    this.metadata,
    this.sortOrder = 0,
    this.isActive = true,
    this.badge,
  });

  Challenge copyWith({
    int? id,
    int? badgeId,
    String? title,
    String? description,
    BadgeCategory? category,
    ChallengeResetInterval? resetInterval,
    int? targetValue,
    Map<String, dynamic>? metadata,
    int? sortOrder,
    bool? isActive,
    Badge? badge,
  }) {
    return Challenge(
      id: id ?? this.id,
      badgeId: badgeId ?? this.badgeId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      resetInterval: resetInterval ?? this.resetInterval,
      targetValue: targetValue ?? this.targetValue,
      metadata: metadata ?? this.metadata,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      badge: badge ?? this.badge,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'badge_id': badgeId,
      'title': title,
      'description': description,
      'category': category.toJson(),
      'reset_interval': resetInterval.toJson(),
      'target_value': targetValue,
      'metadata': metadata,
      'sort_order': sortOrder,
      'is_active': isActive,
      'badge': badge?.toJson(),
    };
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadata;
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      metadata = rawMetadata;
    } else if (rawMetadata is String && rawMetadata.isNotEmpty) {
      try {
        metadata = jsonDecode(rawMetadata) as Map<String, dynamic>?;
      } catch (_) {
        metadata = null;
      }
    }

    Badge? badge;
    if (json['badge'] is Map<String, dynamic>) {
      badge = Badge.fromJson(json['badge'] as Map<String, dynamic>);
    }

    return Challenge(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      badgeId: json['badge_id'] is int
          ? json['badge_id']
          : int.tryParse('${json['badge_id']}') ?? 0,
      title: json['title']?.toString() ?? 'Challenge',
      description: json['description']?.toString(),
      category: json['category'] != null
          ? BadgeCategory.fromJson(json['category'].toString())
          : BadgeCategory.daily,
      resetInterval: json['reset_interval'] != null
          ? ChallengeResetInterval.fromJson(json['reset_interval'].toString())
          : ChallengeResetInterval.daily,
      targetValue: json['target_value'] is int
          ? json['target_value']
          : int.tryParse('${json['target_value']}'),
      metadata: metadata,
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse('${json['sort_order']}') ?? 0,
      isActive: json['is_active'] is bool
          ? json['is_active']
          : '${json['is_active']}'.toLowerCase() != 'false',
      badge: badge,
    );
  }

  factory Challenge.fromBadge(Badge badge) {
    return Challenge(
      id: badge.id,
      badgeId: badge.id,
      title: badge.name,
      description: badge.description,
      category: badge.category,
      resetInterval: ChallengeResetInterval.fromBadgeCategory(badge.category),
      targetValue: badge.requiredValue,
      metadata: badge.unlockConditions,
      sortOrder: badge.id,
      badge: badge,
    );
  }

  Badge toBadgeFallback() {
    if (badge != null) return badge!;
    return Badge(
      id: badgeId,
      name: title,
      description: description,
      category: category,
      rarity: BadgeRarity.common,
      requiredValue: targetValue,
      xpReward: badge?.xpReward ??
          (metadata?['xp_reward'] is int ? metadata!['xp_reward'] as int : 0),
      unlockConditions: metadata,
    );
  }
}

