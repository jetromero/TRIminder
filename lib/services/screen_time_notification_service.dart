import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/simplified_logger.dart';

/// Service for managing heads-up notifications about screen time milestones
class ScreenTimeNotificationService {
  static final ScreenTimeNotificationService _instance = ScreenTimeNotificationService._internal();
  factory ScreenTimeNotificationService() => _instance;
  ScreenTimeNotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (!Platform.isAndroid) {
      SimplifiedLogger.warning('Screen time notifications only supported on Android');
      return false;
    }

    try {
      _notifications = FlutterLocalNotificationsPlugin();

      // Initialize Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );

      await _notifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for heads-up notifications
      await _createNotificationChannel();

      _isInitialized = true;
      SimplifiedLogger.success('Screen time notification service initialized');
      return true;
    } catch (e) {
      SimplifiedLogger.error('Failed to initialize notification service: $e');
      return false;
    }
  }

  /// Create high-priority notification channel for heads-up display
  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;

    try {
      const androidChannel = AndroidNotificationChannel(
        AppConfig.reminderNotificationChannelId,
        AppConfig.reminderNotificationChannelName,
        description: AppConfig.reminderNotificationChannelDescription,
        importance: Importance.high, // Required for heads-up notifications
        playSound: true, // Sound enabled by default (can be disabled in settings)
        enableVibration: false, // Vibration disabled by default (can be enabled in settings)
      );

      await _notifications!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      SimplifiedLogger.verbose('Notification channel created: ${AppConfig.reminderNotificationChannelId}');
    } catch (e) {
      SimplifiedLogger.error('Failed to create notification channel: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    SimplifiedLogger.verbose('Notification tapped: ${response.id}');
    // Could navigate to app or specific screen if needed
  }

  /// Show session milestone notification
  /// [minutes] - Number of minutes of continuous screen time
  Future<void> showSessionMilestone(int minutes) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    // Check if we've already shown this milestone today
    final alreadyShown = await _hasShownMilestone('session_$minutes');
    SimplifiedLogger.info('🔔 Checking session milestone $minutes: alreadyShown=$alreadyShown');
    if (alreadyShown) {
      SimplifiedLogger.info('Session milestone $minutes already shown today, skipping');
      return;
    }

    try {
      final title = '$minutes minutes continuous use';
      final body = 'You\'ve been using your phone for $minutes minutes continuously. Take a break!';

      await _showNotification(
        id: _getNotificationId('session', minutes),
        title: title,
        body: body,
      );

      // Mark milestone as shown
      await _markMilestoneShown('session_$minutes');
      SimplifiedLogger.info('Shown session milestone notification: $minutes minutes');
    } catch (e) {
      SimplifiedLogger.error('Failed to show session milestone notification: $e');
    }
  }

  /// Show daily total milestone notification
  /// [minutes] - Total minutes of screen time today
  Future<void> showDailyMilestone(int minutes) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    // Check if we've already shown this milestone today
    if (await _hasShownMilestone('daily_$minutes')) {
      SimplifiedLogger.verbose('Daily milestone $minutes already shown today, skipping');
      return;
    }

    try {
      final hours = minutes ~/ 60;
      final title = hours > 0 ? '$hours ${hours == 1 ? 'hour' : 'hours'} today' : '$minutes minutes today';
      final body = 'You\'ve reached ${hours > 0 ? '$hours ${hours == 1 ? 'hour' : 'hours'}' : '$minutes minutes'} of screen time today. Consider taking a break!';

      await _showNotification(
        id: _getNotificationId('daily', minutes),
        title: title,
        body: body,
      );

      // Mark milestone as shown
      await _markMilestoneShown('daily_$minutes');
      SimplifiedLogger.info('Shown daily milestone notification: $minutes minutes ($hours hours)');
    } catch (e) {
      SimplifiedLogger.error('Failed to show daily milestone notification: $e');
    }
  }

  /// Show a heads-up notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_notifications == null) return;

    try {
      // Check user preferences for sound and vibration
      final prefs = await SharedPreferences.getInstance();
      final soundEnabled = prefs.getBool('reminder_notifications_sound') ?? true; // Default: enabled
      final vibrationEnabled = prefs.getBool('reminder_notifications_vibration') ?? true; // Default: enabled

      final androidDetails = AndroidNotificationDetails(
        AppConfig.reminderNotificationChannelId,
        AppConfig.reminderNotificationChannelName,
        channelDescription: AppConfig.reminderNotificationChannelDescription,
        importance: Importance.high, // Required for heads-up display
        priority: Priority.high,
        showWhen: true,
        enableVibration: vibrationEnabled,
        playSound: soundEnabled,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications!.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } catch (e) {
      SimplifiedLogger.error('Error showing notification: $e');
    }
  }
  
  /// Get current sound setting for reminder notifications
  static Future<bool> getSoundEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('reminder_notifications_sound') ?? true; // Default: enabled
    } catch (e) {
      return true; // Default to enabled on error
    }
  }
  
  /// Get current vibration setting for reminder notifications
  static Future<bool> getVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('reminder_notifications_vibration') ?? false; // Default: disabled
    } catch (e) {
      return false; // Default to disabled on error
    }
  }
  
  /// Set sound enabled/disabled for reminder notifications
  static Future<void> setSoundEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_notifications_sound', enabled);
    } catch (e) {
      SimplifiedLogger.error('Error saving sound setting: $e');
    }
  }
  
  /// Set vibration enabled/disabled for reminder notifications
  static Future<void> setVibrationEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_notifications_vibration', enabled);
    } catch (e) {
      SimplifiedLogger.error('Error saving vibration setting: $e');
    }
  }

  /// Generate unique notification ID based on milestone type and value
  int _getNotificationId(String type, int minutes) {
    // Use hash of type + minutes to generate consistent ID
    return (type.hashCode + minutes).abs() % 1000000;
  }

  /// Check if a milestone has already been shown today
  Future<bool> _hasShownMilestone(String milestoneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = '${milestoneKey}_${today.year}_${today.month}_${today.day}';
      return prefs.getBool(dateKey) ?? false;
    } catch (e) {
      SimplifiedLogger.error('Error checking milestone status: $e');
      return false; // If error, allow notification to show
    }
  }

  /// Mark a milestone as shown for today
  Future<void> _markMilestoneShown(String milestoneKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final dateKey = '${milestoneKey}_${today.year}_${today.month}_${today.day}';
      await prefs.setBool(dateKey, true);
    } catch (e) {
      SimplifiedLogger.error('Error marking milestone as shown: $e');
    }
  }

  /// Clear all milestone tracking (useful for testing or reset)
  Future<void> clearMilestoneTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('session_') || key.startsWith('daily_')) {
          await prefs.remove(key);
        }
      }
      SimplifiedLogger.verbose('Cleared all milestone tracking');
    } catch (e) {
      SimplifiedLogger.error('Error clearing milestone tracking: $e');
    }
  }
}

