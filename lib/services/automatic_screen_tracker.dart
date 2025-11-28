import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';
import '../models/user_models.dart';
import '../services/persistent_tracker_service.dart';
import '../utils/simplified_logger.dart';

/// Automatic screen time tracker that detects phone screen state
/// Tracks screen ON/OFF events and calculates daily usage
/// LESS screen time = MORE XP (digital wellness approach)
class AutomaticScreenTracker extends ChangeNotifier {
  static final AutomaticScreenTracker _instance = AutomaticScreenTracker._internal();
  factory AutomaticScreenTracker() => _instance;
  AutomaticScreenTracker._internal();

  // Screen state monitoring (simplified - no timer manager)
  
  // Tracking state
  bool _isUserActive = false;
  bool _isMonitoring = false;
  DateTime? _currentSessionStart;
  
  // Daily statistics (loaded from database)
  int _todayScreenTimeMinutes = 0;
  int _todayScreenTimeFromDatabase = 0; // Base total from database (without current session)
  int _currentSessionMinutes = 0;
  
  // XP and wellness data
  int _todayPotentialXP = 0; // XP that will be awarded at end of day
  String _wellnessRating = 'Unknown';
  List<String> _todayBadges = [];
  DateTime? _lastXPAwardDate; // Track when XP was last awarded

  // Getters
  bool get isMonitoring => _isMonitoring;
  int get todayScreenTimeMinutes => _todayScreenTimeMinutes;
  int get currentSessionMinutes => _currentSessionMinutes;
  int get todayXP => _todayPotentialXP;
  String get wellnessRating => _wellnessRating;
  List<String> get todayBadges => _todayBadges;
  String get todayScreenTime => _formatDuration(_todayScreenTimeMinutes);
  String get currentSession => _formatDuration(_currentSessionMinutes);
  bool get isUserActive => _isUserActive;
  
  /// Start automatic screen monitoring (data display only - actual tracking handled by PersistentTrackerService)
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    try {
      // Note: We don't start screen state monitoring here since PersistentTrackerService handles it
      // This service only displays data and manages UI state
      
      _isMonitoring = true;
      await _loadTodayData();
      
      SimplifiedLogger.service('Screen monitoring started (display mode)');
      notifyListeners();
      return true;
      
    } catch (e) {
      SimplifiedLogger.error('Failed to start screen monitoring: $e');
      return false;
    }
  }

  /// Stop automatic screen monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    SimplifiedLogger.service('Screen monitoring stopped');
    notifyListeners();
  }

  // Note: Screen state monitoring methods removed - handled by PersistentTrackerService

  

  void _updateRealTimeTodayTotal() async {
    // Calculate total from database + current live session
    _todayScreenTimeMinutes = _todayScreenTimeFromDatabase + _currentSessionMinutes;
    
    // Update user activity status
    _isUserActive = await _checkUserActivity();
    
    SimplifiedLogger.verbose("Current session: ${_currentSessionMinutes}m, Total: ${_todayScreenTimeMinutes}m, Active: $_isUserActive");
      
    // Also update the wellness stats based on new total
    _todayPotentialXP = _calculateDailyXP(_todayScreenTimeMinutes);
    _wellnessRating = _getWellnessRating(_todayScreenTimeMinutes);
    _todayBadges = _getDailyBadges(_todayScreenTimeMinutes);
    
    // Notify listeners since this updates the main display data
    SimplifiedLogger.screenTime('Total updated: ${_todayScreenTimeMinutes}m');
    notifyListeners();
  }

  /// Check user activity status
  Future<bool> _checkUserActivity() async {
    try {
      // Get session data from background service
      final sessionData = await PersistentTrackerService.getCurrentSessionData();
      return sessionData['isUserActive'] ?? false;
    } catch (e) {
      print('Error checking user activity: $e');
      return false;
    }
  }

  /// Update daily statistics display only (no XP award)
  Future<void> _updateDailyStatsDisplay() async {
    // Calculate potential XP that will be awarded at end of day
    _todayPotentialXP = _calculateDailyXP(_todayScreenTimeMinutes);
    
    // Determine wellness rating
    _wellnessRating = _getWellnessRating(_todayScreenTimeMinutes);
    
    // Check for badges
    _todayBadges = _getDailyBadges(_todayScreenTimeMinutes);
    
    SimplifiedLogger.verbose('Notifying listeners of data update');
    notifyListeners();
  }







  /// Check if it's a new day and award previous day's XP
  Future<void> _checkForNewDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // If we have screen time data but haven't awarded XP yet
    if (_lastXPAwardDate == null) {
      // This might be the first run, check if we should award yesterday's XP
      final yesterday = today.subtract(const Duration(days: 1));
      await _awardEndOfDayXPForDate(yesterday);
    } else {
      // Check if a day has passed since last XP award
      final daysSinceLastAward = today.difference(_lastXPAwardDate!).inDays;
      if (daysSinceLastAward >= 1) {
        // Award XP for the previous day(s)
        for (int i = 1; i <= daysSinceLastAward; i++) {
          final dateToAward = _lastXPAwardDate!.add(Duration(days: i));
          if (dateToAward.isBefore(today)) {
            await _awardEndOfDayXPForDate(dateToAward);
          }
        }
      }
    }
  }

  /// Award XP at the end of day for a specific date
  Future<void> _awardEndOfDayXPForDate(DateTime date) async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      final db = DatabaseService();
      
      // Check if XP was already awarded for this date (duplicate prevention)
      final existingHistory = await db.getXPAwardHistoryForDate(userId, date);
      if (existingHistory != null) {
        SimplifiedLogger.xp('XP already awarded for ${date.toString().split(' ')[0]}, skipping duplicate award');
        _lastXPAwardDate = date;
        return;
      }

      // Also check Supabase if online (for cross-device duplicate prevention)
      final supabaseService = SupabaseService();
      final isOnline = await supabaseService.isConnected();
      if (isOnline) {
        final alreadyAwarded = await supabaseService.checkXPAwardedForDate(userId, date);
        if (alreadyAwarded) {
          SimplifiedLogger.xp('XP already awarded in Supabase for ${date.toString().split(' ')[0]}, skipping duplicate award');
          _lastXPAwardDate = date;
          return;
        }
      }

      // Get screen time for the specific date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final dayLogs = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfDay, 
        endOfDay
      );

      final dayScreenTimeMinutes = dayLogs
          .where((log) => log.durationMinutes != null)
          .fold(0, (sum, log) => sum + log.durationMinutes!);

      if (dayScreenTimeMinutes > 0) {
        // Calculate final XP for that day
        final finalXP = _calculateDailyXP(dayScreenTimeMinutes);
        
        if (finalXP > 0) {
          // Award the XP to user profile and record history
          await _updateUserDailyXP(finalXP, dayScreenTimeMinutes, date);
          _lastXPAwardDate = date;
          
          SimplifiedLogger.xp('End-of-day XP awarded: $finalXP XP for ${dayScreenTimeMinutes}m screen time');
        }
      }
    } catch (e) {
      SimplifiedLogger.error('Error awarding end-of-day XP: $e');
    }
  }

  /// Calculate daily XP based on TOTAL screen time (LESS = MORE XP)
  int _calculateDailyXP(int totalMinutes) {
    // Digital wellness XP tiers (daily total)
    if (totalMinutes <= 120) {
      return 100; // 🏆 Excellent! (<2 hours)
    } else if (totalMinutes <= 240) {
      return 75;  // 🥇 Great! (2-4 hours)
    } else if (totalMinutes <= 360) {
      return 50;  // 🥈 Good (4-6 hours)
    } else if (totalMinutes <= 480) {
      return 25;  // 🥉 Fair (6-8 hours)
    } else if (totalMinutes <= 600) {
      return 10;  // ⚠️ High usage (8-10 hours)
    } else {
      return 0;   // 🚨 Excessive usage (10+ hours)
    }
  }

  /// Get wellness rating based on daily usage
  String _getWellnessRating(int totalMinutes) {
    if (totalMinutes <= 120) return 'Excellent 🏆';
    if (totalMinutes <= 240) return 'Great 🥇';
    if (totalMinutes <= 360) return 'Good 🥈';
    if (totalMinutes <= 480) return 'Fair 🥉';
    if (totalMinutes <= 600) return 'High ⚠️';
    return 'Touch some grass 🌱';
  }

  /// Get daily badges based on usage
  List<String> _getDailyBadges(int totalMinutes) {
    List<String> badges = [];
    
    if (totalMinutes <= 120) {
      badges.add('Digital Sage'); // Ultra minimal
    } 
    else if (totalMinutes <= 240 && totalMinutes > 120) {
      badges.add('Mindful Master'); // Excellent
    } 
    else if (totalMinutes <= 360 && totalMinutes > 240) {
      badges.add('Balanced User'); // Very good
    } 
    else if (totalMinutes <= 480 && totalMinutes > 360) {
      badges.add('Conscious User'); // Good
    } 
    else if (totalMinutes <= 600 && totalMinutes > 480) {
      badges.add('Aware User'); // Okay
    }
    // No badges for excessive usage
    
    return badges;
  }

  /// Update user's daily XP in profile (only called at end of day)
  /// Also records XP award history for duplicate prevention
  Future<void> _updateUserDailyXP(int xpToAward, int screenTimeMinutes, DateTime awardDate) async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        SimplifiedLogger.error('Cannot update XP: No user ID available');
        return;
      }

      if (xpToAward <= 0) {
        SimplifiedLogger.error('Cannot update XP: Invalid XP amount ($xpToAward)');
        return;
      }

      final db = DatabaseService();
      
      // Create XP award history record
      final history = XPAwardHistory(
        id: DateTime.now().microsecondsSinceEpoch,
        userId: userId,
        awardDate: awardDate,
        xpAwarded: xpToAward,
        screenTimeMinutes: screenTimeMinutes,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      // Check if we're online
      final supabaseService = SupabaseService();
      final isOnline = await supabaseService.isConnected();
      
      if (isOnline) {
        // Online: Update both Supabase and local database
        try {
          final userProfile = await supabaseService.getUserProfile(userId);
          if (userProfile == null) {
            SimplifiedLogger.error('Cannot update XP: User profile not found');
            return;
          }
          
          final updatedProfile = userProfile.copyWith(
            xp: userProfile.xp + xpToAward,
          );
          
          // Update Supabase profile
          final supabaseSuccess = await supabaseService.updateUserProfile(updatedProfile);
          
          // Insert XP award history to Supabase
          XPAwardHistory? supabaseHistory;
          if (supabaseSuccess != null) {
            try {
              supabaseHistory = await supabaseService.insertXPAwardHistory(history);
            } catch (historyError) {
              SimplifiedLogger.warning('Failed to insert XP award history to Supabase: $historyError');
            }
          }
          
          // Also update local database to keep them in sync
          if (supabaseSuccess != null) {
            try {
              await db.updateUserProfile(updatedProfile);
              
              // Insert or update local history
              if (supabaseHistory != null) {
                // Update with Supabase ID if available and mark as synced
                final updatedHistory = history.copyWith(id: supabaseHistory.id, isSynced: true);
                await db.insertXPAwardHistory(updatedHistory);
              } else {
                await db.insertXPAwardHistory(history);
              }
              
              SimplifiedLogger.xp('User XP updated online: +$xpToAward (Total: ${updatedProfile.xp})');
              // ✅ Exit early to prevent XPUpdateLog creation when online award succeeds
              return;
            } catch (localError) {
              SimplifiedLogger.warning('Supabase updated but local DB failed: $localError');
              // Supabase succeeded, local failed - exit early to prevent XPUpdateLog creation
              // Sync will download correct XP from Supabase later
              return;
            }
          } else {
            SimplifiedLogger.warning('Failed to update XP in Supabase, storing locally for later sync');
            // Fallback to offline storage if Supabase fails
            await _storeXPUpdateLocally(userId, xpToAward, screenTimeMinutes, awardDate);
          }
        } catch (onlineError) {
          SimplifiedLogger.error('Online XP update failed: $onlineError');
          // Fallback to offline storage
          await _storeXPUpdateLocally(userId, xpToAward, screenTimeMinutes, awardDate);
        }
      } else {
        // Offline: Store locally for later sync
        await _storeXPUpdateLocally(userId, xpToAward, screenTimeMinutes, awardDate);
      }
    } catch (e) {
      SimplifiedLogger.error('Critical error updating user XP: $e');
      // Last resort: try to store locally even if everything else fails
      try {
        final userId = SupabaseService().currentUserId;
        if (userId != null) {
          await _storeXPUpdateLocally(userId, xpToAward, screenTimeMinutes, awardDate);
        }
      } catch (fallbackError) {
        SimplifiedLogger.error('Even fallback XP storage failed: $fallbackError');
      }
    }
  }

  /// Helper method to store XP update locally (both XP update log and history)
  Future<void> _storeXPUpdateLocally(String userId, int xpToAward, int screenTimeMinutes, DateTime awardDate) async {
    try {
      final db = DatabaseService();
      
      // Check if XP was already stored for this date (duplicate prevention)
      final existingHistory = await db.getXPAwardHistoryForDate(userId, awardDate);
      if (existingHistory != null) {
        SimplifiedLogger.xp('XP already stored locally for ${awardDate.toString().split(' ')[0]}, skipping duplicate storage');
        return; // Already stored, no need to store again
      }
      
      // Store XP update log for sync
      final xpUpdate = XPUpdateLog(
        id: DateTime.now().microsecondsSinceEpoch,
        userId: userId,
        xpToAdd: xpToAward,
        date: awardDate,
        createdAt: DateTime.now(),
        isSynced: false,
      );
      
      await db.insertXPUpdateLog(xpUpdate);
      
      // Store XP award history for duplicate prevention
      // insertXPAwardHistory will also check for duplicates internally
      final history = XPAwardHistory(
        id: DateTime.now().microsecondsSinceEpoch,
        userId: userId,
        awardDate: awardDate,
        xpAwarded: xpToAward,
        screenTimeMinutes: screenTimeMinutes,
        createdAt: DateTime.now(),
        isSynced: false,
      );
      
      await db.insertXPAwardHistory(history);
      
      SimplifiedLogger.xp('XP update stored locally for sync: +$xpToAward');
    } catch (e) {
      SimplifiedLogger.error('Failed to store XP update locally: $e');
      rethrow; // Re-throw so caller knows it failed
    }
  }

  /// Load today's screen time data
  Future<void> _loadTodayData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        SimplifiedLogger.warning('No user ID available for loading screen time data');
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final db = DatabaseService();
      final todayLogs = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfDay, 
        endOfDay
      );

      SimplifiedLogger.verbose('Dashboard debug: User: $userId, Found ${todayLogs.length} logs');
      
      // Debug: Print all entries (verbose only)
      for (final log in todayLogs) {
        SimplifiedLogger.verbose('Entry: ${log.durationMinutes}m at ${log.startTime}');
      }

      // Store database total separately (without current session)
      _todayScreenTimeFromDatabase = todayLogs
          .where((log) => log.durationMinutes != null)
          .fold(0, (sum, log) => sum + log.durationMinutes!);

      // Update real-time total (database + current session)
      _updateRealTimeTodayTotal();

      SimplifiedLogger.screenTime('Today: ${_formatDuration(_todayScreenTimeMinutes)} (DB: ${_todayScreenTimeFromDatabase}m, Session: ${_currentSessionMinutes}m)');

      await _updateDailyStatsDisplay();

    } catch (e) {
      SimplifiedLogger.error('Error loading today data: $e');
    }
  }

  /// Refresh today's data (call periodically to sync with background service)
  Future<void> refreshTodayData() async {
    SimplifiedLogger.verbose('refreshTodayData() called');
    
    // Load fresh data from database first
    await _loadTodayData();
    
    // Try to get current session state from background service
    await _syncCurrentSessionFromBackground();
    
    
    // Update the total to show database + live session
    _updateRealTimeTodayTotal();
    
    SimplifiedLogger.verbose('refreshTodayData() completed');
    notifyListeners();
  }

  /// Force refresh after sync completion (call after successful sync)
  Future<void> forceRefreshAfterSync() async {
    SimplifiedLogger.verbose('forceRefreshAfterSync() called');
    
    // Clear any cached data
    _todayScreenTimeFromDatabase = 0;
    _currentSessionMinutes = 0;
    
    // Load fresh data from database
    await _loadTodayData();
    
    // Sync with background service
    await _syncCurrentSessionFromBackground();
    
    // Update totals
    _updateRealTimeTodayTotal();
    
    SimplifiedLogger.verbose('forceRefreshAfterSync() completed');
    notifyListeners();
  }

  /// Try to sync current session state from background service
  /// This uses the same data source as the notification for consistency
Future<void> _syncCurrentSessionFromBackground() async {
  try {
    // Get session data directly from background service (same as notification)
    final sessionData = await PersistentTrackerService.getCurrentSessionData();
    
    SimplifiedLogger.verbose('Background service session data: $sessionData');
    
    final hasActiveSession = sessionData['hasActiveSession'] ?? false;
    final sessionStartTimeMs = sessionData['sessionStartTime'];
    final currentMinutes = sessionData['currentMinutes'] ?? 0;

    // Use background service data directly - no fallback needed
    if (hasActiveSession && sessionStartTimeMs != null) {
      _currentSessionStart = DateTime.fromMillisecondsSinceEpoch(sessionStartTimeMs);
      _currentSessionMinutes = currentMinutes;
      SimplifiedLogger.session('Active session: ${currentMinutes}m (started at ${_currentSessionStart!.toLocal()})');
    } else {
      _currentSessionStart = null;
      _currentSessionMinutes = 0;
      SimplifiedLogger.verbose('No active session from background service');
    }
  } catch (e) {
    SimplifiedLogger.error('Error syncing session from background service: $e');
    // If background service fails, clear session data
    _currentSessionStart = null;
    _currentSessionMinutes = 0;
  }
}

  /// Format duration in minutes
  String _formatDuration(int minutes) {
    if (minutes == 0) return '0m';
    
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  /// Manual check for end of day (call when app resumes)
  Future<void> checkForEndOfDay() async {
    await _checkForNewDay();
  }

  /// Get detailed daily statistics
  Map<String, dynamic> getDailyStats() {
    return {
      'totalMinutes': _todayScreenTimeMinutes,
      'totalFormatted': todayScreenTime,
      'sessionsCount': 0, // Sessions tracked by PersistentTrackerService
      'xpEarned': _todayPotentialXP,
      'wellnessRating': _wellnessRating,
      'badges': _todayBadges,
      'isMonitoring': _isMonitoring,
    };
  }

  /// Get hourly usage data for today (24 values, one for each hour)
  /// Returns list of minutes spent in each hour
  Future<List<double>> getHourlyUsageForToday() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        return List.filled(24, 0.0);
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final db = DatabaseService();
      final todayLogs = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfDay, 
        endOfDay
      );

      // Initialize hourly buckets (24 hours)
      final hourlyMinutes = List<double>.filled(24, 0.0);

      // Distribute screen time entries to their respective hours
      for (final log in todayLogs) {
        final duration = log.durationMinutes ?? 0;
        if (duration <= 0) continue;
        
        final startHour = log.startTime.hour;
        final endTime = log.startTime.add(Duration(minutes: duration));
        final endHour = endTime.hour;
        
        if (startHour == endHour) {
          // Session within same hour
          hourlyMinutes[startHour] += duration.toDouble();
        } else {
          // Session spans multiple hours - distribute proportionally
          // Minutes in start hour
          final minutesInStartHour = 60 - log.startTime.minute;
          hourlyMinutes[startHour] += minutesInStartHour;
          
          // Full hours in between
          for (int h = startHour + 1; h < endHour && h < 24; h++) {
            hourlyMinutes[h] += 60;
          }
          
          // Minutes in end hour
          if (endHour < 24) {
            hourlyMinutes[endHour] += endTime.minute;
          }
        }
      }

      // Cap each hour at 60 minutes max
      for (int i = 0; i < 24; i++) {
        hourlyMinutes[i] = hourlyMinutes[i].clamp(0.0, 60.0);
      }

      return hourlyMinutes;
    } catch (e) {
      SimplifiedLogger.error('Error getting hourly usage: $e');
      return List.filled(24, 0.0);
    }
  }

  /// Get weekly usage data (7 values, one for each day Sun-Sat)
  /// Returns list of total minutes for each day of the current week
  Future<List<double>> getWeeklyUsage() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        return List.filled(7, 0.0);
      }

      final now = DateTime.now();
      // Get the start of the week (Sunday)
      final daysSinceSunday = now.weekday % 7;
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSunday));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final db = DatabaseService();
      final weekLogs = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfWeek, 
        endOfWeek
      );

      // Initialize daily buckets (7 days: Sun=0, Mon=1, ..., Sat=6)
      final dailyMinutes = List<double>.filled(7, 0.0);

      // Distribute screen time entries to their respective days
      for (final log in weekLogs) {
        final duration = log.durationMinutes ?? 0;
        if (duration <= 0) continue;
        
        final dayIndex = log.startTime.weekday % 7; // Sunday = 0
        dailyMinutes[dayIndex] += duration.toDouble();
      }

      return dailyMinutes;
    } catch (e) {
      SimplifiedLogger.error('Error getting weekly usage: $e');
      return List.filled(7, 0.0);
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

/// Helper class for screen sessions
class ScreenSession {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;

  ScreenSession({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });
}
