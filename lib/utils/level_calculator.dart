/// Utility class for calculating user levels and XP requirements
/// Uses exponential scaling with 1.25x multiplier per level
class LevelCalculator {
  // Base XP requirement for the first level
  static const int baseXP = 100;
  
  // Multiplier for exponential scaling
  static const double multiplier = 1.25;

  /// Calculate the current level based on total XP
  /// 
  /// Args:
  ///   xp: Total XP accumulated by the user
  /// 
  /// Returns:
  ///   Current level (starts at 1)
  static int getLevel(int xp) {
    if (xp < baseXP) return 1; // Starting level
    
    int level = 1;
    int totalXpNeeded = 0;
    
    while (totalXpNeeded <= xp) {
      int xpForThisLevel = getXPRequiredForLevel(level);
      if (totalXpNeeded + xpForThisLevel > xp) break;
      totalXpNeeded += xpForThisLevel;
      level++;
    }
    
    return level;
  }

  /// Calculate XP required to advance from a specific level
  /// 
  /// Args:
  ///   level: The level to calculate XP requirement for
  /// 
  /// Returns:
  ///   XP needed to advance from this level to the next
  /// 
  /// Example:
  ///   Level 1→2: 100 XP
  ///   Level 2→3: 125 XP
  ///   Level 3→4: 156 XP
  static int getXPRequiredForLevel(int level) {
    // Each level requires: base * (multiplier ^ (level - 1))
    return (baseXP * _power(multiplier, level - 1)).round();
  }

  /// Calculate total XP needed to reach a specific level
  /// 
  /// Args:
  ///   level: Target level
  /// 
  /// Returns:
  ///   Total XP needed from level 1 to reach target level
  static int getTotalXPForLevel(int level) {
    int totalXP = 0;
    for (int i = 1; i < level; i++) {
      totalXP += getXPRequiredForLevel(i);
    }
    return totalXP;
  }

  /// Calculate progress percentage towards next level
  /// 
  /// Args:
  ///   currentXP: User's current total XP
  /// 
  /// Returns:
  ///   Progress as a double between 0.0 and 1.0
  static double getProgressToNextLevel(int currentXP) {
    final currentLevel = getLevel(currentXP);
    final xpForCurrentLevel = getTotalXPForLevel(currentLevel);
    final xpForNextLevel = getTotalXPForLevel(currentLevel + 1);
    final xpInCurrentLevel = currentXP - xpForCurrentLevel;
    final xpNeededForLevel = xpForNextLevel - xpForCurrentLevel;
    
    return xpNeededForLevel > 0 ? xpInCurrentLevel / xpNeededForLevel : 0.0;
  }

  /// Get XP remaining to reach next level
  /// 
  /// Args:
  ///   currentXP: User's current total XP
  /// 
  /// Returns:
  ///   XP needed to reach the next level
  static int getXPRemainingToNextLevel(int currentXP) {
    final currentLevel = getLevel(currentXP);
    final currentLevelBaseXP = getTotalXPForLevel(currentLevel);
    final xpInCurrentLevel = currentXP - currentLevelBaseXP;
    final xpNeededForNextLevel = getXPRequiredForLevel(currentLevel);
    
    return xpNeededForNextLevel - xpInCurrentLevel;
  }

  /// Get XP progress within current level
  /// 
  /// Args:
  ///   currentXP: User's current total XP
  /// 
  /// Returns:
  ///   Map with current level XP info:
  ///   - 'currentLevelXP': XP gained in current level
  ///   - 'requiredForNextLevel': XP needed for next level
  ///   - 'remaining': XP remaining to next level
  static Map<String, int> getCurrentLevelProgress(int currentXP) {
    final currentLevel = getLevel(currentXP);
    final currentLevelBaseXP = getTotalXPForLevel(currentLevel);
    final xpInCurrentLevel = currentXP - currentLevelBaseXP;
    final xpNeededForNextLevel = getXPRequiredForLevel(currentLevel);
    final xpRemaining = xpNeededForNextLevel - xpInCurrentLevel;

    return {
      'currentLevelXP': xpInCurrentLevel,
      'requiredForNextLevel': xpNeededForNextLevel,
      'remaining': xpRemaining,
    };
  }

  /// Generate a level progression table for debugging/display
  /// 
  /// Args:
  ///   maxLevel: Maximum level to generate (default: 20)
  /// 
  /// Returns:
  ///   List of maps containing level progression data
  static List<Map<String, dynamic>> getLevelTable({int maxLevel = 20}) {
    List<Map<String, dynamic>> table = [];
    
    for (int level = 1; level <= maxLevel; level++) {
      final xpRequired = getXPRequiredForLevel(level);
      final totalXP = getTotalXPForLevel(level + 1);
      
      table.add({
        'level': level,
        'xpRequired': xpRequired,
        'totalXP': totalXP,
        'range': '${getTotalXPForLevel(level)} - ${totalXP - 1}',
      });
    }
    
    return table;
  }

  /// Helper method to calculate power without using math library
  /// 
  /// Args:
  ///   base: Base number
  ///   exponent: Exponent (must be non-negative integer)
  /// 
  /// Returns:
  ///   Result of base^exponent
  static double _power(double base, int exponent) {
    if (exponent == 0) return 1.0;
    if (exponent < 0) throw ArgumentError('Exponent must be non-negative');
    
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
