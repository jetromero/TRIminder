import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

import '../services/persistent_tracker_service.dart';

/// Automatic screen time tracker that detects phone screen state
/// Tracks screen ON/OFF events and calculates daily usage
/// LESS screen time = MORE XP (digital wellness approach)
class AutomaticScreenTracker extends ChangeNotifier {
  static final AutomaticScreenTracker _instance = AutomaticScreenTracker._internal();
  factory AutomaticScreenTracker() => _instance;
  AutomaticScreenTracker._internal();

  // Screen state monitoring (simplified - no timer manager)
  
  // Tracking state
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
  
  /// Start automatic screen monitoring (data display only - actual tracking handled by PersistentTrackerService)
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    try {
      // Note: We don't start screen state monitoring here since PersistentTrackerService handles it
      // This service only displays data and manages UI state
      
      _isMonitoring = true;
      await _loadTodayData();
      
      print('Automatic screen monitoring started (display mode)');
      notifyListeners();
      return true;
      
    } catch (e) {
      print('Failed to start screen monitoring: $e');
      return false;
    }
  }

  /// Stop automatic screen monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    print('Automatic screen monitoring stopped');
    notifyListeners();
  }

  // Note: Screen state monitoring methods removed - handled by PersistentTrackerService



  /// Reset current session (when screen turns off or app goes to background)
  void resetCurrentSession() {
    _currentSessionStart = null;
    _currentSessionMinutes = 0;
    _updateRealTimeTodayTotal(); // Update total to show only database data
    notifyListeners();
    print('Current session reset');
  }

  /// Start new session (when screen turns on or app comes to foreground)
  void startNewSession() {
    // Don't automatically start a new session - let PersistentTrackerService handle it
    // Just refresh the data to show current state
    refreshTodayData();
    print('Session display refreshed - letting background service handle actual tracking');
  }

  Future<int> _getStagedMinutes() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        return await PersistentTrackerService.getStagedMinutesForToday(userId);
      }
    } catch (e) {
      print('❌ Error getting staged minutes: $e');
    }
    return 0;
  }

  void _updateRealTimeTodayTotal() async {
  // Calculate total from database + current session + staged
  final stagedMinutes = await _getStagedMinutes();
  _todayScreenTimeMinutes = _todayScreenTimeFromDatabase + _currentSessionMinutes + stagedMinutes;
  
  print("🔍 _currentSessionMinutes: $_currentSessionMinutes");
  print("🔍 Staged minutes: $stagedMinutes");
  print("🔍 Total: $_todayScreenTimeMinutes");
  
    
    // Also update the wellness stats based on new total
    _todayPotentialXP = _calculateDailyXP(_todayScreenTimeMinutes);
    _wellnessRating = _getWellnessRating(_todayScreenTimeMinutes);
    _todayBadges = _getDailyBadges(_todayScreenTimeMinutes);
    
    // Notify listeners since this updates the main display data
    print('📊 AutomaticScreenTracker: Updating total to ${_todayScreenTimeMinutes}m, notifying listeners');
    notifyListeners();
  }

  /// Update daily statistics display only (no XP award)
  Future<void> _updateDailyStatsDisplay() async {
    // Calculate potential XP that will be awarded at end of day
    _todayPotentialXP = _calculateDailyXP(_todayScreenTimeMinutes);
    
    // Determine wellness rating
    _wellnessRating = _getWellnessRating(_todayScreenTimeMinutes);
    
    // Check for badges
    _todayBadges = _getDailyBadges(_todayScreenTimeMinutes);
    
    print('📊 AutomaticScreenTracker: Notifying listeners of data update');
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

      // Get screen time for the specific date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final db = DatabaseService();
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
          // Award the XP to user profile
          await _updateUserDailyXP(finalXP);
          _lastXPAwardDate = date;
          
          print('End-of-day XP awarded for ${date.toLocal()}: $finalXP XP for ${dayScreenTimeMinutes}m screen time');
        }
      }
    } catch (e) {
      print('Error awarding end-of-day XP: $e');
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
    else if (totalMinutes <= 240) {
      badges.add('Mindful Master'); // Excellent
    } 
    else if (totalMinutes <= 360) {
      badges.add('Balanced User'); // Very good
    } 
    else if (totalMinutes <= 480) {
      badges.add('Conscious User'); // Good
    } 
    else if (totalMinutes <= 600) {
      badges.add('Aware User'); // Okay
    }
    // No badges for excessive usage
    
    return badges;
  }

  /// Update user's daily XP in profile (only called at end of day)
  Future<void> _updateUserDailyXP(int xpToAward) async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      final userProfile = await SupabaseService().getUserProfile(userId);
      if (userProfile != null) {
        // Award daily XP (only once per day)
        final updatedProfile = userProfile.copyWith(
          xp: userProfile.xp + xpToAward,
        );
        await SupabaseService().updateUserProfile(updatedProfile);
        print('User XP updated: +$xpToAward (Total: ${updatedProfile.xp})');
      }
    } catch (e) {
      print('Error updating user XP: $e');
    }
  }

  /// Load today's screen time data
  Future<void> _loadTodayData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        print('No user ID available for loading screen time data');
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

      print('🔍 Dashboard debug:');
      print('   - User ID: $userId');
      print('   - Date range: ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}');
      print('   - Found ${todayLogs.length} logs');

      print('Loaded ${todayLogs.length} screen time entries for today');
      
      // Debug: Print all entries
      for (final log in todayLogs) {
        print('Entry: ${log.userId} - ${log.durationMinutes}m at ${log.startTime}');
      }

      // Store database total separately (without current session)
      _todayScreenTimeFromDatabase = todayLogs
          .where((log) => log.durationMinutes != null)
          .fold(0, (sum, log) => sum + log.durationMinutes!);

      // Update real-time total (database + current session)
      _updateRealTimeTodayTotal();

      print('Database screen time for today: $_todayScreenTimeFromDatabase minutes');
      print('Current session minutes: $_currentSessionMinutes minutes');
      print('Real-time total screen time: $_todayScreenTimeMinutes minutes (including current session)');
      print('Formatted display: ${_formatDuration(_todayScreenTimeMinutes)}');

      await _updateDailyStatsDisplay();

    } catch (e) {
      print('Error loading today data: $e');
    }
  }

  /// Refresh today's data (call periodically to sync with background service)
  Future<void> refreshTodayData() async {
    print('🔄 AutomaticScreenTracker: refreshTodayData() called');
    
    // Load fresh data from database first
    await _loadTodayData();
    
    // Try to get current session state from background service
    await _syncCurrentSessionFromBackground();
    
    
    // Update the total to show database + live session
    _updateRealTimeTodayTotal();
    
    print('🔄 AutomaticScreenTracker: refreshTodayData() completed, notifying listeners');
    notifyListeners();
  }

  /// Force refresh after sync completion (call after successful sync)
  Future<void> forceRefreshAfterSync() async {
    print('🔄 AutomaticScreenTracker: forceRefreshAfterSync() called');
    
    // Clear any cached data
    _todayScreenTimeFromDatabase = 0;
    _currentSessionMinutes = 0;
    
    // Load fresh data from database
    await _loadTodayData();
    
    // Sync with background service
    await _syncCurrentSessionFromBackground();
    
    // Update totals
    _updateRealTimeTodayTotal();
    
    print('🔄 AutomaticScreenTracker: forceRefreshAfterSync() completed, notifying listeners');
    notifyListeners();
  }

  /// Try to sync current session state from background service
  /// This uses the same data source as the notification for consistency
Future<void> _syncCurrentSessionFromBackground() async {
  try {
    // Get session data directly from background service (same as notification)
    final sessionData = await PersistentTrackerService.getCurrentSessionData();
    
    print('🔍 DEBUG: Background service session data: $sessionData');
    
    final hasActiveSession = sessionData['hasActiveSession'] ?? false;
    final sessionStartTimeMs = sessionData['sessionStartTime'];
    final currentMinutes = sessionData['currentMinutes'] ?? 0;
    final todayTotal = sessionData['todayTotal'] ?? 0;
    final timestamp = sessionData['timestamp'];
    
    print('🔍 DEBUG: Background service values:');
    print('   - hasActiveSession: $hasActiveSession');
    print('   - sessionStartTime: $sessionStartTimeMs');
    print('   - currentMinutes: $currentMinutes');
    print('   - todayTotal: $todayTotal');
    print("   - Timestamp: $timestamp");


    bool assignedFromService = false;
    if (hasActiveSession && sessionStartTimeMs != null) {
      _currentSessionStart = DateTime.fromMillisecondsSinceEpoch(sessionStartTimeMs);
      _currentSessionMinutes = currentMinutes;
      assignedFromService = true;
      print('📱 Found active session via background service: ${currentMinutes}m (started at ${_currentSessionStart!.toLocal()})');
    }

    // Fallback to SharedPreferences-staged session if service not available or reported none
    if (!assignedFromService) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final bool prefActive = prefs.getBool('has_active_session') ?? false;
        final int? startMs = prefs.getInt('session_start_time');
        final int prefMinutes = prefs.getInt('current_session_minutes') ?? 0;

        if (prefActive && startMs != null) {
          final DateTime start = DateTime.fromMillisecondsSinceEpoch(startMs);
          final int liveMinutes = DateTime.now().difference(start).inMinutes;
          _currentSessionStart = start;
          _currentSessionMinutes = liveMinutes >= prefMinutes ? liveMinutes : prefMinutes;
          print('📱 Fallback from SharedPreferences: ${_currentSessionMinutes}m (started at ${start.toLocal()})');
        } else {
          _currentSessionStart = null;
          _currentSessionMinutes = 0;
          print('📱 No active session via SharedPreferences fallback (active=$prefActive)');
        }
      } catch (e) {
        print('❌ Error reading SharedPreferences for session fallback: $e');
        _currentSessionStart = null;
        _currentSessionMinutes = 0;
      }
    }
  } catch (e) {
    print('❌ Error syncing session from background service: $e');
    // Final fallback to SharedPreferences on channel errors
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool prefActive = prefs.getBool('has_active_session') ?? false;
      final int? startMs = prefs.getInt('session_start_time');
      final int prefMinutes = prefs.getInt('current_session_minutes') ?? 0;
      if (prefActive && startMs != null) {
        final DateTime start = DateTime.fromMillisecondsSinceEpoch(startMs);
        final int liveMinutes = DateTime.now().difference(start).inMinutes;
        _currentSessionStart = start;
        _currentSessionMinutes = liveMinutes >= prefMinutes ? liveMinutes : prefMinutes;
        print('📱 Fallback from SharedPreferences after error: ${_currentSessionMinutes}m (started at ${start.toLocal()})');
      } else {
        _currentSessionStart = null;
        _currentSessionMinutes = 0;
      }
    } catch (_) {
      _currentSessionStart = null;
      _currentSessionMinutes = 0;
    }
  }
}

  /// Sync current session state from background service
  void syncCurrentSessionState(DateTime? sessionStartTime) {
    if (sessionStartTime != null) {
      _currentSessionStart = sessionStartTime;
      final now = DateTime.now();
      _currentSessionMinutes = now.difference(sessionStartTime).inMinutes;
      _updateRealTimeTodayTotal();
    } else {
      _currentSessionStart = null;
      _currentSessionMinutes = 0;
      _updateRealTimeTodayTotal();
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
