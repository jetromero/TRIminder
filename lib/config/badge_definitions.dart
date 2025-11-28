import '../models/badge_models.dart';

class BadgeDefinitions {
  /// Get default badge definitions for the app
  static List<Badge> getDefaultBadges() {
    return [
      // Daily Badges - Based on daily screen time thresholds
      Badge(
        id: 1,
        name: 'Digital Sage',
        description: 'Keep screen time under 2 hours today',
        category: BadgeCategory.daily,
        rarity: BadgeRarity.rare,
        requiredValue: 120, // minutes
        xpReward: 50,
        unlockConditions: {'type': 'daily', 'threshold': 120},
      ),
      Badge(
        id: 2,
        name: 'Mindful Master',
        description: 'Keep screen time under 4 hours today',
        category: BadgeCategory.daily,
        rarity: BadgeRarity.common,
        requiredValue: 240, // minutes
        xpReward: 25,
        unlockConditions: {'type': 'daily', 'threshold': 240},
      ),
      Badge(
        id: 3,
        name: 'Balanced User',
        description: 'Keep screen time under 6 hours today',
        category: BadgeCategory.daily,
        rarity: BadgeRarity.common,
        requiredValue: 360, // minutes
        xpReward: 15,
        unlockConditions: {'type': 'daily', 'threshold': 360},
      ),
      Badge(
        id: 4,
        name: 'Conscious User',
        description: 'Keep screen time under 8 hours today',
        category: BadgeCategory.daily,
        rarity: BadgeRarity.common,
        requiredValue: 480, // minutes
        xpReward: 10,
        unlockConditions: {'type': 'daily', 'threshold': 480},
      ),

      // Streak Badges - Consecutive days of healthy screen time
      Badge(
        id: 10,
        name: 'Week Warrior',
        description: 'Maintain healthy screen time for 7 consecutive days',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.rare,
        requiredValue: 7, // days
        xpReward: 100,
        unlockConditions: {'type': 'streak', 'days': 7},
      ),
      Badge(
        id: 11,
        name: 'Month Master',
        description: 'Maintain healthy screen time for 30 consecutive days',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.epic,
        requiredValue: 30, // days
        xpReward: 500,
        unlockConditions: {'type': 'streak', 'days': 30},
      ),

      // Milestone Badges - Level achievements
      Badge(
        id: 20,
        name: 'Level 10 Champion',
        description: 'Reach level 10',
        category: BadgeCategory.milestone,
        rarity: BadgeRarity.common,
        requiredValue: 10, // level
        xpReward: 200,
        unlockConditions: {'type': 'level', 'level': 10},
      ),
      Badge(
        id: 21,
        name: 'Level 25 Hero',
        description: 'Reach level 25',
        category: BadgeCategory.milestone,
        rarity: BadgeRarity.rare,
        requiredValue: 25, // level
        xpReward: 500,
        unlockConditions: {'type': 'level', 'level': 25},
      ),
    ];
  }
}

