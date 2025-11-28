import 'database_service.dart';
import 'supabase_service.dart';

/// Service for managing badge leveling and completion tracking
class BadgeLevelingService {
  final DatabaseService _db = DatabaseService();
  final SupabaseService _supabase = SupabaseService();

  /// Record a daily challenge completion for a specific date
  /// Returns true if successful, false if completion already exists
  Future<bool> recordDailyChallengeCompletion(
    String userId,
    int badgeId,
    DateTime date,
  ) async {
    try {
      // Check if completion already exists for this date
      final hasCompletion = await _db.hasCompletionForDate(userId, badgeId, date);
      if (hasCompletion) {
        print('⚠️ Completion already exists for badge $badgeId on ${date.toIso8601String().split('T')[0]}');
        return false;
      }

      // Insert into local database
      await _db.insertDailyChallengeCompletion(userId, badgeId, date);

      // Try to sync to Supabase if online
      final isOnline = await _supabase.isConnected();
      if (isOnline) {
        try {
          await _supabase.insertDailyChallengeCompletion(userId, badgeId, date);
        } catch (e) {
          print('⚠️ Failed to sync completion to Supabase: $e');
          // Continue - local record is saved
        }
      }

      return true;
    } catch (e) {
      print('❌ Error recording daily challenge completion: $e');
      return false;
    }
  }

  /// Calculate badge level based on completion count and thresholds
  /// Returns the level (1-5) based on how many times the badge has been completed
  int calculateBadgeLevel(int completionCount, List<int>? thresholds) {
    if (thresholds == null || thresholds.isEmpty) {
      return 1;
    }

    // Find the highest threshold that the count has reached
    int level = 1;
    for (int i = 0; i < thresholds.length; i++) {
      if (completionCount >= thresholds[i]) {
        level = i + 1; // Level is 1-indexed
      } else {
        break;
      }
    }

    return level;
  }

  /// Check and level up a badge if completion count has increased
  /// Returns level up information: {leveledUp: bool, oldLevel: int, newLevel: int}
  Future<Map<String, dynamic>> checkAndLevelUpBadge(
    String userId,
    int badgeId,
  ) async {
    try {
      // Get current user badge
      final userBadge = await _db.getUserBadge(userId, badgeId);
      if (userBadge == null) {
        return {
          'leveledUp': false,
          'oldLevel': 1,
          'newLevel': 1,
        };
      }

      // Get badge definition to access thresholds
      final badge = await _db.getBadgeById(badgeId);
      if (badge == null) {
        return {
          'leveledUp': false,
          'oldLevel': userBadge.level,
          'newLevel': userBadge.level,
        };
      }

      // Count completions from daily_challenge_completions table
      final completionCount = await _db.getCompletionCountForBadge(userId, badgeId);

      // Calculate new level based on completion count
      final newLevel = calculateBadgeLevel(completionCount, badge.levelThresholds);
      final oldLevel = userBadge.level;

      // Update user badge if level increased or completion count changed
      if (newLevel != oldLevel || completionCount != userBadge.completionCount) {
        final updatedBadge = userBadge.copyWith(
          level: newLevel,
          completionCount: completionCount,
        );

        await _db.updateUserBadge(updatedBadge);

        // Try to sync to Supabase if online
        final isOnline = await _supabase.isConnected();
        if (isOnline) {
          try {
            await _supabase.updateUserBadge(updatedBadge);
          } catch (e) {
            print('⚠️ Failed to sync badge update to Supabase: $e');
          }
        }

        return {
          'leveledUp': newLevel > oldLevel,
          'oldLevel': oldLevel,
          'newLevel': newLevel,
          'completionCount': completionCount,
        };
      }

      return {
        'leveledUp': false,
        'oldLevel': oldLevel,
        'newLevel': newLevel,
        'completionCount': completionCount,
      };
    } catch (e) {
      print('❌ Error checking and leveling up badge: $e');
      return {
        'leveledUp': false,
        'oldLevel': 1,
        'newLevel': 1,
      };
    }
  }

  /// Get badge level progress information
  /// Returns: {currentLevel: int, completionCount: int, nextLevelThreshold: int?, progressToNext: double}
  Future<Map<String, dynamic>> getBadgeLevelProgress(
    String userId,
    int badgeId,
  ) async {
    try {
      // Get current user badge
      final userBadge = await _db.getUserBadge(userId, badgeId);
      if (userBadge == null) {
        return {
          'currentLevel': 1,
          'completionCount': 0,
          'nextLevelThreshold': null,
          'progressToNext': 0.0,
        };
      }

      // Get badge definition to access thresholds
      final badge = await _db.getBadgeById(badgeId);
      if (badge == null || badge.levelThresholds == null || badge.levelThresholds!.isEmpty) {
        return {
          'currentLevel': userBadge.level,
          'completionCount': userBadge.completionCount,
          'nextLevelThreshold': null,
          'progressToNext': 0.0,
        };
      }

      final thresholds = badge.levelThresholds!;
      final currentLevel = userBadge.level;
      final completionCount = userBadge.completionCount;

      // Find next level threshold
      int? nextLevelThreshold;
      if (currentLevel < thresholds.length) {
        nextLevelThreshold = thresholds[currentLevel];
      }

      // Calculate progress to next level
      double progressToNext = 0.0;
      if (nextLevelThreshold != null) {
        final currentThreshold = currentLevel > 1 ? thresholds[currentLevel - 2] : 0;
        final thresholdRange = nextLevelThreshold - currentThreshold;
        final progress = completionCount - currentThreshold;
        progressToNext = (progress / thresholdRange).clamp(0.0, 1.0);
      }

      return {
        'currentLevel': currentLevel,
        'completionCount': completionCount,
        'nextLevelThreshold': nextLevelThreshold,
        'progressToNext': progressToNext,
      };
    } catch (e) {
      print('❌ Error getting badge level progress: $e');
      return {
        'currentLevel': 1,
        'completionCount': 0,
        'nextLevelThreshold': null,
        'progressToNext': 0.0,
      };
    }
  }
}

