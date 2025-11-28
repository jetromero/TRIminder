import '../models/badge_models.dart';

/// Service for calculating badge progress and managing badge-related logic
class BadgeService {
  /// Calculate progress toward earning a badge
  /// 
  /// Returns a value between 0.0 and 1.0 representing progress:
  /// - 0.0 = no progress
  /// - 1.0 = badge achieved (or 100% progress)
  /// 
  /// For daily/weekly/monthly badges (screen time limits):
  /// - Progress is 1.0 if current value <= required value (under/at limit)
  /// - Progress is 0.0 if current value > required value (over limit)
  /// 
  /// For streak/milestone/social badges (achievement goals):
  /// - Progress is calculated as min(1.0, current / required)
  Future<double> getBadgeProgress(
    Badge badge, {
    int? dailyScreenTimeMinutes,
    int? weeklyAverageMinutes,
    int? monthlyAverageMinutes,
    int? currentStreak,
    int? totalXP,
    int? level,
    int? friendCount,
  }) async {
    // Return 0.0 if requiredValue is null
    if (badge.requiredValue == null) {
      return 0.0;
    }

    final required = badge.requiredValue!;

    switch (badge.category) {
      case BadgeCategory.daily:
        // Daily badges: "Keep screen time under X minutes"
        // Progress = 1.0 if current <= required, 0.0 if current > required
        if (dailyScreenTimeMinutes == null) {
          return 0.0;
        }
        return dailyScreenTimeMinutes <= required ? 1.0 : 0.0;

      case BadgeCategory.weekly:
        // Weekly badges: "Keep weekly average under X minutes"
        // Progress = 1.0 if current <= required, 0.0 if current > required
        if (weeklyAverageMinutes == null) {
          return 0.0;
        }
        return weeklyAverageMinutes <= required ? 1.0 : 0.0;

      case BadgeCategory.monthly:
        // Monthly badges: "Keep monthly average under X minutes"
        // Progress = 1.0 if current <= required, 0.0 if current > required
        if (monthlyAverageMinutes == null) {
          return 0.0;
        }
        return monthlyAverageMinutes <= required ? 1.0 : 0.0;

      case BadgeCategory.streak:
        // Streak badges: "Maintain streak for X days"
        // Progress = min(1.0, current / required)
        if (currentStreak == null) {
          return 0.0;
        }
        if (required <= 0) return 0.0;
        return (currentStreak / required).clamp(0.0, 1.0);

      case BadgeCategory.milestone:
        // Milestone badges: "Reach level X" or "Earn X XP"
        // Progress = min(1.0, current / required)
        final unlockType = badge.unlockConditions?['type'];
        
        if (unlockType == 'level') {
          // Level-based milestone
          if (level == null) {
            return 0.0;
          }
          if (required <= 0) return 0.0;
          return (level / required).clamp(0.0, 1.0);
        } else if (unlockType == 'xp') {
          // XP-based milestone
          if (totalXP == null) {
            return 0.0;
          }
          if (required <= 0) return 0.0;
          return (totalXP / required).clamp(0.0, 1.0);
        } else {
          // Unknown milestone type, default to level if available
          if (level != null && required > 0) {
            return (level / required).clamp(0.0, 1.0);
          }
          return 0.0;
        }

      case BadgeCategory.social:
        // Social badges: "Have X friends"
        // Progress = min(1.0, current / required)
        if (friendCount == null) {
          return 0.0;
        }
        if (required <= 0) return 0.0;
        return (friendCount / required).clamp(0.0, 1.0);

      case BadgeCategory.special:
        // Special badges have no progress tracking
        return 0.0;
    }
  }
}
