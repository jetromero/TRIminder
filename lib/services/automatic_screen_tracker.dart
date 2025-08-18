import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_state/screen_state.dart';
import '../models/user_models.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

/// Automatic screen time tracker that detects phone screen state
/// Tracks screen ON/OFF events and calculates daily usage
/// LESS screen time = MORE XP (digital wellness approach)
class AutomaticScreenTracker extends ChangeNotifier {
  static final AutomaticScreenTracker _instance = AutomaticScreenTracker._internal();
  factory AutomaticScreenTracker() => _instance;
  AutomaticScreenTracker._internal();

  // Screen state monitoring
  StreamSubscription<ScreenStateEvent>? _screenStateSubscription;
  Screen? _screen;
  
  // Tracking state
  bool _isMonitoring = false;
  DateTime? _screenOnTime;
  DateTime? _lastScreenOffTime;
  
  // Daily statistics
  int _todayScreenTimeMinutes = 0;
  int _currentSessionMinutes = 0;
  final List<ScreenSession> _todaySessions = [];
  
  // XP and wellness data
  int _todayXP = 0;
  String _wellnessRating = 'Unknown';
  List<String> _todayBadges = [];

  // Getters
  bool get isMonitoring => _isMonitoring;
  int get todayScreenTimeMinutes => _todayScreenTimeMinutes;
  int get currentSessionMinutes => _currentSessionMinutes;
  int get todayXP => _todayXP;
  String get wellnessRating => _wellnessRating;
  List<String> get todayBadges => _todayBadges;
  String get todayScreenTime => _formatDuration(_todayScreenTimeMinutes);
  String get currentSession => _formatDuration(_currentSessionMinutes);
  
  /// Start automatic screen monitoring
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    try {
      _screen = Screen();
      
      // Listen to screen state changes
      _screenStateSubscription = _screen!.screenStateStream?.listen(
        _onScreenStateChanged,
        onError: (error) {
          print('Screen state monitoring error: $error');
        },
      );

      _isMonitoring = true;
      await _loadTodayData();
      
      print('Automatic screen monitoring started');
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

    await _screenStateSubscription?.cancel();
    _screenStateSubscription = null;
    _screen = null;
    _isMonitoring = false;

    // Save any ongoing session
    if (_screenOnTime != null) {
      await _endCurrentSession();
    }

    print('Automatic screen monitoring stopped');
    notifyListeners();
  }

  /// Handle screen state changes (ON/OFF)
  void _onScreenStateChanged(ScreenStateEvent event) async {
    switch (event) {
      case ScreenStateEvent.SCREEN_ON:
        await _onScreenTurnedOn();
        break;
      case ScreenStateEvent.SCREEN_OFF:
        await _onScreenTurnedOff();
        break;
      default:
        break;
    }
  }

  /// Handle screen turned ON event
  Future<void> _onScreenTurnedOn() async {
    _screenOnTime = DateTime.now();
    print('Screen turned ON at $_screenOnTime');
    
    // Start tracking current session
    _startSessionTimer();
    notifyListeners();
  }

  /// Handle screen turned OFF event
  Future<void> _onScreenTurnedOff() async {
    if (_screenOnTime == null) return;

    _lastScreenOffTime = DateTime.now();
    print('Screen turned OFF at $_lastScreenOffTime');
    
    await _endCurrentSession();
    notifyListeners();
  }

  /// End current screen session and save data
  Future<void> _endCurrentSession() async {
    if (_screenOnTime == null || _lastScreenOffTime == null) return;

    final sessionDuration = _lastScreenOffTime!.difference(_screenOnTime!);
    final sessionMinutes = sessionDuration.inMinutes;

    if (sessionMinutes > 0) {
      // Create session record
      final session = ScreenSession(
        startTime: _screenOnTime!,
        endTime: _lastScreenOffTime!,
        durationMinutes: sessionMinutes,
      );

      _todaySessions.add(session);
      _todayScreenTimeMinutes += sessionMinutes;

      // Save to database
      await _saveSession(session);
      
      // Update daily statistics
      await _updateDailyStats();

      print('Session ended: ${sessionMinutes}m (Total today: ${_todayScreenTimeMinutes}m)');
    }

    // Reset session tracking
    _screenOnTime = null;
    _lastScreenOffTime = null;
    _currentSessionMinutes = 0;
  }

  /// Start timer for current session updates
  void _startSessionTimer() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_screenOnTime == null || !_isMonitoring) {
        timer.cancel();
        return;
      }

      _currentSessionMinutes = DateTime.now().difference(_screenOnTime!).inMinutes;
      notifyListeners();
    });
  }

  /// Save screen session to database
  Future<void> _saveSession(ScreenSession session) async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      final log = ScreenTimeLog(
        id: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        startTime: session.startTime,
        endTime: session.endTime,
        durationMinutes: session.durationMinutes,
        breakTaken: false,
        createdAt: DateTime.now(),
        isSynced: false,
      );

      // Save locally
      await DatabaseService().insertScreenTimeEntry(log);

      // Try to sync to Supabase
      try {
        await SupabaseService().insertScreenTimeLog(log);
        await DatabaseService().markScreenTimeEntrySynced(log.id);
      } catch (e) {
        print('Failed to sync session to Supabase: $e');
      }

    } catch (e) {
      print('Error saving session: $e');
    }
  }

  /// Update daily statistics and XP
  Future<void> _updateDailyStats() async {
    // Calculate XP based on TOTAL daily usage (digital wellness approach)
    _todayXP = _calculateDailyXP(_todayScreenTimeMinutes);
    
    // Determine wellness rating
    _wellnessRating = _getWellnessRating(_todayScreenTimeMinutes);
    
    // Check for badges
    _todayBadges = _getDailyBadges(_todayScreenTimeMinutes);

    // Update user XP in profile
    await _updateUserDailyXP();
    
    notifyListeners();
  }

  /// Calculate daily XP based on TOTAL screen time (LESS = MORE XP)
  int _calculateDailyXP(int totalMinutes) {
    // Digital wellness XP tiers (daily total)
    if (totalMinutes <= 60) {
      return 100; // 🏆 Excellent! (<1 hour)
    } else if (totalMinutes <= 120) {
      return 75;  // 🥇 Great! (1-2 hours)
    } else if (totalMinutes <= 180) {
      return 50;  // 🥈 Good (2-3 hours)
    } else if (totalMinutes <= 240) {
      return 25;  // 🥉 Fair (3-4 hours)
    } else if (totalMinutes <= 360) {
      return 10;  // ⚠️ High usage (4-6 hours)
    } else {
      return 0;   // 🚨 Excessive usage (6+ hours)
    }
  }

  /// Get wellness rating based on daily usage
  String _getWellnessRating(int totalMinutes) {
    if (totalMinutes <= 60) return 'Excellent 🏆';
    if (totalMinutes <= 120) return 'Great 🥇';
    if (totalMinutes <= 180) return 'Good 🥈';
    if (totalMinutes <= 240) return 'Fair 🥉';
    if (totalMinutes <= 360) return 'High ⚠️';
    return 'Excessive 🚨';
  }

  /// Get daily badges based on usage
  List<String> _getDailyBadges(int totalMinutes) {
    List<String> badges = [];
    
    if (totalMinutes <= 30) {
      badges.add('Digital Monk'); // Ultra minimal
    } else if (totalMinutes <= 60) {
      badges.add('Mindful Master'); // Excellent
    } else if (totalMinutes <= 90) {
      badges.add('Balanced User'); // Very good
    } else if (totalMinutes <= 120) {
      badges.add('Conscious User'); // Good
    } else if (totalMinutes <= 180) {
      badges.add('Aware User'); // Okay
    }
    // No badges for excessive usage
    
    return badges;
  }

  /// Update user's daily XP in profile
  Future<void> _updateUserDailyXP() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;

      final userProfile = await SupabaseService().getUserProfile(userId);
      if (userProfile != null) {
        // Award daily XP (replace, don't add to prevent double-counting)
        final updatedProfile = userProfile.copyWith(
          xp: userProfile.xp + _todayXP,
        );
        await SupabaseService().updateUserProfile(updatedProfile);
      }
    } catch (e) {
      print('Error updating user XP: $e');
    }
  }

  /// Load today's screen time data
  Future<void> _loadTodayData() async {
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

      _todayScreenTimeMinutes = todayLogs
          .where((log) => log.durationMinutes != null)
          .fold(0, (sum, log) => sum + log.durationMinutes!);

      await _updateDailyStats();

    } catch (e) {
      print('Error loading today data: $e');
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

  /// Get detailed daily statistics
  Map<String, dynamic> getDailyStats() {
    return {
      'totalMinutes': _todayScreenTimeMinutes,
      'totalFormatted': todayScreenTime,
      'sessionsCount': _todaySessions.length,
      'xpEarned': _todayXP,
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
