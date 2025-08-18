import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';


/// Service for tracking screen time with hybrid approach:
/// - Manual start/stop controls
/// - Automatic app lifecycle detection
/// - Background/foreground state monitoring
/// - XP rewards for tracking sessions
class ScreenTimeService extends ChangeNotifier {
  static final ScreenTimeService _instance = ScreenTimeService._internal();
  factory ScreenTimeService() => _instance;
  ScreenTimeService._internal();

  // Tracking state
  bool _isTracking = false;
  DateTime? _sessionStartTime;
  DateTime? _lastPauseTime;
  int _totalPausedMinutes = 0;
  Timer? _trackingTimer;
  
  // Session data
  int _currentSessionMinutes = 0;
  int _todayTotalMinutes = 0;
  
  // XP and rewards
  int _sessionXP = 0;
  List<String> _sessionBadges = [];

  // Getters
  bool get isTracking => _isTracking;
  int get currentSessionMinutes => _currentSessionMinutes;
  int get todayTotalMinutes => _todayTotalMinutes;
  int get sessionXP => _sessionXP;
  List<String> get sessionBadges => _sessionBadges;
  String get sessionDuration => _formatDuration(_currentSessionMinutes);
  String get todayTotal => _formatDuration(_todayTotalMinutes);

  /// Start a new tracking session
  Future<bool> startTracking() async {
    if (_isTracking) return false;

    try {
      _isTracking = true;
      _sessionStartTime = DateTime.now();
      _lastPauseTime = null;
      _totalPausedMinutes = 0;
      _currentSessionMinutes = 0;
      _sessionXP = 0;
      _sessionBadges.clear();

      // Start the tracking timer (updates every minute)
      _trackingTimer = Timer.periodic(const Duration(minutes: 1), _onTimerTick);
      
      notifyListeners();
      print('Screen time tracking started at $_sessionStartTime');
      return true;
    } catch (e) {
      print('Error starting tracking: $e');
      return false;
    }
  }

  /// Stop the current tracking session and save data
  Future<bool> stopTracking() async {
    if (!_isTracking || _sessionStartTime == null) return false;

    try {
      _isTracking = false;
      _trackingTimer?.cancel();
      _trackingTimer = null;

      // Calculate final session duration
      final endTime = DateTime.now();
      final totalMinutes = _calculateSessionMinutes(_sessionStartTime!, endTime);
      _currentSessionMinutes = totalMinutes;

      // Calculate XP earned
      _sessionXP = _calculateXPEarned(totalMinutes);

      // Check for badges
      _sessionBadges = _checkForBadges(totalMinutes);

      // Save the session
      await _saveSession(endTime, totalMinutes);

      // Update today's total
      await _loadTodayTotal();

      notifyListeners();
      print('Screen time tracking stopped. Session: ${totalMinutes}m, XP: $_sessionXP');
      return true;
    } catch (e) {
      print('Error stopping tracking: $e');
      return false;
    }
  }

  /// Pause tracking (when app goes to background)
  void pauseTracking() {
    if (!_isTracking || _lastPauseTime != null) return;
    
    _lastPauseTime = DateTime.now();
    print('Screen time tracking paused');
    notifyListeners();
  }

  /// Resume tracking (when app comes to foreground)
  void resumeTracking() {
    if (!_isTracking || _lastPauseTime == null) return;

    final pauseDuration = DateTime.now().difference(_lastPauseTime!);
    _totalPausedMinutes += pauseDuration.inMinutes;
    _lastPauseTime = null;
    
    print('Screen time tracking resumed after ${pauseDuration.inMinutes}m pause');
    notifyListeners();
  }

  /// Load today's total screen time
  Future<void> loadTodayTotal() async {
    await _loadTodayTotal();
    notifyListeners();
  }

  /// Timer callback - updates current session time
  void _onTimerTick(Timer timer) {
    if (!_isTracking || _sessionStartTime == null) return;

    final now = DateTime.now();
    final totalMinutes = _calculateSessionMinutes(_sessionStartTime!, now);
    _currentSessionMinutes = totalMinutes;

    // Calculate XP in real-time
    _sessionXP = _calculateXPEarned(totalMinutes);

    notifyListeners();
  }

  /// Calculate session minutes excluding paused time
  int _calculateSessionMinutes(DateTime start, DateTime end) {
    final totalDuration = end.difference(start);
    final activeDuration = totalDuration.inMinutes - _totalPausedMinutes;
    
    // Account for current pause
    if (_lastPauseTime != null) {
      final currentPause = DateTime.now().difference(_lastPauseTime!);
      return activeDuration - currentPause.inMinutes;
    }
    
    return activeDuration.clamp(0, double.infinity).toInt();
  }

  /// Calculate XP earned based on DIGITAL WELLNESS goals
  /// LESS screen time = MORE XP (encourages healthy usage)
  int _calculateXPEarned(int minutes) {
    if (minutes <= 0) return 0;
    
    // Digital Wellness XP Formula: Rewards LESS screen time
    // 0-30min: 50 XP (excellent!)
    // 30-60min: 30 XP (good)
    // 60-120min: 15 XP (moderate)
    // 120-180min: 5 XP (concerning)
    // 180+ min: 0 XP (excessive usage)
    
    if (minutes <= 30) {
      return 50; // Excellent digital wellness
    } else if (minutes <= 60) {
      return 30; // Good usage
    } else if (minutes <= 120) {
      return 15; // Moderate usage
    } else if (minutes <= 180) {
      return 5; // Concerning usage
    } else {
      return 0; // Excessive usage - no XP reward
    }
  }

  /// Check for badges earned based on DIGITAL WELLNESS goals
  /// Rewards LOW screen time usage
  List<String> _checkForBadges(int minutes) {
    List<String> badges = [];
    
    // Digital wellness badges - reward LOW usage
    if (minutes <= 15) {
      badges.add('Digital Minimalist'); // Excellent!
    } else if (minutes <= 30) {
      badges.add('Mindful User'); // Very good
    } else if (minutes <= 60) {
      badges.add('Balanced User'); // Good
    } else if (minutes <= 90) {
      badges.add('Awareness Badge'); // Getting better
    }
    // No badges for excessive usage (120+ minutes)
    
    return badges;
  }

  /// Save tracking session to database
  Future<void> _saveSession(DateTime endTime, int minutes) async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      // Create screen time log
      final log = ScreenTimeLog(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        startTime: _sessionStartTime!,
        endTime: endTime,
        durationMinutes: minutes,
        breakTaken: _totalPausedMinutes > 0,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      // Save to local database
      final db = DatabaseService();
      await db.insertScreenTimeEntry(log);

      // Try to sync to Supabase
      try {
        await SupabaseService().insertScreenTimeLog(log);
        // Mark as synced if successful
        await db.markScreenTimeEntrySynced(log.id);
      } catch (e) {
        print('Failed to sync to Supabase, will retry later: $e');
      }

      // Update user XP
      await _updateUserXP(userId, _sessionXP);

    } catch (e) {
      print('Error saving session: $e');
    }
  }

  /// Update user XP in profile
  Future<void> _updateUserXP(String userId, int xpToAdd) async {
    try {
      final userProfile = await SupabaseService().getUserProfile(userId);
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(
          xp: userProfile.xp + xpToAdd,
        );
        await SupabaseService().updateUserProfile(updatedProfile);
      }
    } catch (e) {
      print('Error updating user XP: $e');
    }
  }

  /// Load today's total screen time from database
  Future<void> _loadTodayTotal() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final db = DatabaseService();
      final todayLogs = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfDay, 
        endOfDay
      );

      _todayTotalMinutes = todayLogs
          .where((log) => log.durationMinutes != null)
          .fold(0, (sum, log) => sum + log.durationMinutes!);

    } catch (e) {
      print('Error loading today total: $e');
      _todayTotalMinutes = 0;
    }
  }

  /// Format duration in minutes to readable string
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

  /// Reset session data (for debugging/testing)
  void resetSession() {
    _isTracking = false;
    _sessionStartTime = null;
    _lastPauseTime = null;
    _totalPausedMinutes = 0;
    _currentSessionMinutes = 0;
    _sessionXP = 0;
    _sessionBadges.clear();
    _trackingTimer?.cancel();
    _trackingTimer = null;
    notifyListeners();
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'isTracking': _isTracking,
      'sessionMinutes': _currentSessionMinutes,
      'sessionXP': _sessionXP,
      'sessionBadges': _sessionBadges,
      'todayTotal': _todayTotalMinutes,
      'pausedMinutes': _totalPausedMinutes,
      'startTime': _sessionStartTime?.toIso8601String(),
    };
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }
}
