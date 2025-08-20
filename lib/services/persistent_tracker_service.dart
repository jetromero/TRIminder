import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:screen_state/screen_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/improved_sync_service.dart';


/// Data wrapper class for service variables (enables reference passing)
class _ServiceData {
  DateTime? screenOnTime;
  int todayScreenTime = 0;
  DateTime lastSaveDate = DateTime.now();
}

/// Persistent background service that runs automatically on device boot
/// Tracks screen time 24/7 without user intervention
/// Survives app closure, phone restarts, and system termination
@pragma('vm:entry-point')
class PersistentTrackerService {
  static const int _minSessionSeconds = 20;

  static int _roundSecondsToMinutesNearest(int seconds) {
    final int minutes = ((seconds + 30) / 60).floor();
    return minutes < 1 ? 1 : minutes;
  }

  static Future<int> _saveSessionRounded(DateTime start, DateTime end) async {
    final int seconds = end.difference(start).inSeconds;
    if (seconds < _minSessionSeconds) {
      print('🪙 Session below threshold (${seconds}s < ${_minSessionSeconds}s) - skipped');
      return 0;
    }
    final int minutes = _roundSecondsToMinutesNearest(seconds);
    if (minutes > 0) {
      await _saveSession(start, end, minutes);
      print('💾 Saved session: ${minutes}m (${seconds}s)');
    } else {
      print('⚠️ Session too short after rounding (${seconds}s) - skipped');
    }
    return minutes;
  }

  static Future<int> _savePossiblySplitSession(DateTime start, DateTime end) async {
    if (start.isAfter(end)) return 0;
    int totalMinutes = 0;
    DateTime cursorStart = start;
    final bool sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) {
      totalMinutes += await _saveSessionRounded(start, end);
    } else {
      while (!(cursorStart.year == end.year && cursorStart.month == end.month && cursorStart.day == end.day)) {
        final DateTime dayEnd = DateTime(cursorStart.year, cursorStart.month, cursorStart.day).add(const Duration(days: 1));
        totalMinutes += await _saveSessionRounded(cursorStart, dayEnd);
        cursorStart = dayEnd;
      }
      totalMinutes += await _saveSessionRounded(cursorStart, end);
    }
    return totalMinutes;
  }
  static bool _isInitialized = false;

  /// Initialize the persistent background service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request necessary permissions
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        print('❌ Required permissions not granted');
        return false;
      }

      // Configure the background service
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: true, // 🔥 Auto-start on device boot!
          isForegroundMode: true, // Runs in foreground for reliability
          notificationChannelId: 'triminder_tracking',
          initialNotificationTitle: 'TRIminder Digital Wellness',
          initialNotificationContent: 'Tracking screen time automatically',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      _isInitialized = true;
      print('✅ Persistent tracker service initialized');
      return true;

    } catch (e) {
      print('❌ Failed to initialize persistent service: $e');
      return false;
    }
  }

  /// Start the background tracking service
  static Future<bool> startService() async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }

      final isRunning = await FlutterBackgroundService().isRunning();
      if (isRunning) {
        print('⚡ Service already running');
        return true;
      }

      await FlutterBackgroundService().startService();
      print('🚀 Background service started');
      return true;

    } catch (e) {
      print('❌ Failed to start service: $e');
      return false;
    }
  }

  /// Stop the background tracking service
  static Future<void> stopService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (isRunning) {
        service.invoke('stop');
        print('⏹️ Background service stopped');
      }
    } catch (e) {
      print('❌ Failed to stop service: $e');
    }
  }

  /// Check if service is currently running
  static Future<bool> isRunning() async {
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (e) {
      return false;
    }
  }

  /// Force reload today's screen time data (called from foreground app)
  static Future<void> reloadTodayData() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (isRunning) {
        // Send message to background service to reload data
        service.invoke('reload_today_data');
        print('📊 Sent reload command to background service');
      } else {
        print('⚠️ Background service is not running!');
      }
    } catch (e) {
      print('❌ Error sending reload command: $e');
    }
  }

  /// Check service status and get current data
  static Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (isRunning) {
        // Send status request to background service
        service.invoke('get_status');
        print('📊 Sent status request to background service');
        return {'running': true, 'message': 'Service is running'};
      } else {
        print('⚠️ Background service is not running!');
        return {'running': false, 'message': 'Service stopped'};
      }
    } catch (e) {
      print('❌ Error checking service status: $e');
      return {'running': false, 'error': e.toString()};
    }
  }

  /// Get current session state from background service
  static Future<DateTime?> getCurrentSessionStartTime() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (isRunning) {
        // Send session state request to background service
        service.invoke('get_session_state');
        print('📱 Sent session state request to background service');
        // Note: This would need to be implemented in the background service
        // For now, return null as the background service doesn't expose this
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print('❌ Error getting session state: $e');
      return null;
    }
  }

  /// Request necessary permissions for background operation
  static Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.notification,
      Permission.systemAlertWindow, // For screen state detection
      Permission.phone, // For device state monitoring
    ];

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check if all required permissions are granted
    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      print('⚠️ Some permissions not granted: $statuses');
    }

    // Request battery optimization bypass (Android 6.0+)
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus != PermissionStatus.granted) {
        print('🔋 Requesting battery optimization bypass...');
        final batteryResult = await Permission.ignoreBatteryOptimizations.request();
        if (batteryResult == PermissionStatus.granted) {
          print('✅ Battery optimization bypass granted');
        } else {
          print('⚠️ Battery optimization bypass denied - app may be killed during sleep');
        }
      } else {
        print('✅ Battery optimization already bypassed');
      }
    } catch (e) {
      print('⚠️ Could not request battery optimization bypass: $e');
    }

    return allGranted;
  }

  /// Background service entry point (runs in isolate)
  @pragma('vm:entry-point')
  @pragma('dart2js:tryInline')
  static void _onStart(ServiceInstance service) async {
    print('🎯 Background service started in isolate');

    // Initialize service data with wrapper class for reference passing
    final serviceData = _ServiceData();
    serviceData.lastSaveDate = DateTime.now();

    // Load today's total screen time from database
    await _loadTodayScreenTime(serviceData);

    // Update notification with loaded total
    if (service is AndroidServiceInstance) {
      final hours = serviceData.todayScreenTime ~/ 60;
      final minutes = serviceData.todayScreenTime % 60;
      final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      service.setForegroundNotificationInfo(
        title: 'TRIminder Active',
        content: 'Today: $timeStr screen time 📱',
      );
    }

    // Initialize screen state monitoring
    Screen? screen;
    StreamSubscription<ScreenStateEvent>? screenSubscription;

    try {
      screen = Screen();
      screenSubscription = screen.screenStateStream.listen(
        (event) => _handleScreenEvent(service, event, serviceData),
        onError: (error) {
          print('❌ Screen monitoring error: $error');
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'TRIminder Error',
              content: 'Screen monitoring failed',
            );
          }
        },
      );

      print('✅ Screen state monitoring initialized');
      
    } catch (e) {
      print('❌ Failed to initialize screen monitoring: $e');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'TRIminder Error', 
          content: 'Failed to start monitoring',
        );
      }
    }

    // Periodic tasks (every 1 minute)
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        // Checkpoint save for long-running sessions (every ~5 minutes for production)
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int elapsedSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          if (elapsedSeconds >= 300) { // 5 minutes
            final int saved = await _savePossiblySplitSession(serviceData.screenOnTime!, now);
            print('⏱️ Checkpoint: active ${elapsedSeconds}s → saved ${saved}m, resetting start');
            // Reset start to now for the next chunk
            serviceData.screenOnTime = now;
          }
        }

        // Reload today's total from DB (every 5 minutes to reduce DB calls)
        if (timer.tick % 5 == 0) {
          await _loadTodayScreenTime(serviceData);
        }

        // Compute live display with current session
        int liveExtra = 0;
        String sessionInfo = '';
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          liveExtra = sessionSeconds ~/ 60; // floor to minutes
          if (liveExtra > 0) {
            sessionInfo = ' + ${liveExtra}m active';
          }
          
          // Store current session info for dashboard access via SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_active_session', true);
            await prefs.setInt('session_start_time', serviceData.screenOnTime!.millisecondsSinceEpoch);
            await prefs.setInt('current_session_minutes', liveExtra);
            print('💾 Stored session data: active=true, start=${serviceData.screenOnTime!.toLocal()}, minutes=$liveExtra');
          } catch (e) {
            print('❌ Error storing session data: $e');
          }
        } else {
          // No active session
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_active_session', false);
            await prefs.remove('session_start_time');
            await prefs.setInt('current_session_minutes', 0);
          } catch (e) {
            print('❌ Error clearing session data: $e');
          }
        }

        final int displayMinutes = serviceData.todayScreenTime + liveExtra;
        final int hours = displayMinutes ~/ 60;
        final int minutes = displayMinutes % 60;
        final String timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'TRIminder Tracking',
            content: 'Today: $timeStr$sessionInfo',
          );
        }

        // Check if new day - reset daily counter
        final now = DateTime.now();
        if (now.day != serviceData.lastSaveDate.day) {
          await _saveDailyData(serviceData.todayScreenTime);
          serviceData.todayScreenTime = 0;
          serviceData.lastSaveDate = now;
          print('🗓️ New day detected - reset daily counter');
        }

        // No cloud sync here: background service is write-only.
        // Cloud sync will be handled by ImprovedSyncService in foreground.

      } catch (e) {
        print('❌ Periodic task error: $e');
      }
    });

    // Listen for stop command
    service.on('stop').listen((event) async {
      print('🛑 Received stop command');
      
      // Save any ongoing session
      final currentTime = DateTime.now();
      if (serviceData.screenOnTime != null) {
        final sessionMinutes = currentTime.difference(serviceData.screenOnTime!).inMinutes;
        serviceData.todayScreenTime += sessionMinutes;
        await _saveSession(serviceData.screenOnTime!, currentTime, sessionMinutes);
      }

      // Save daily data
      await _saveDailyData(serviceData.todayScreenTime);

      // Cleanup
      await screenSubscription?.cancel();
      service.stopSelf();
    });

    // Listen for reload command
    service.on('reload_today_data').listen((event) async {
      print('🔄 Received reload command');
      await _loadTodayScreenTime(serviceData);
      
      // Update notification with new data
      if (service is AndroidServiceInstance) {
        final hours = serviceData.todayScreenTime ~/ 60;
        final minutes = serviceData.todayScreenTime % 60;
        final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        service.setForegroundNotificationInfo(
          title: 'TRIminder Tracking',
          content: 'Today: $timeStr screen time',
        );
      }
    });

    // Listen for status request
    service.on('get_status').listen((event) async {
      print('📊 Status request received');
      final hours = serviceData.todayScreenTime ~/ 60;
      final minutes = serviceData.todayScreenTime % 60;
      final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      
      print('📊 Background Service Status:');
      print('   - Running: true');
      print('   - Today screen time: $timeStr (${serviceData.todayScreenTime} minutes)');
      print('   - Screen on time: ${serviceData.screenOnTime}');
      print('   - Last save date: ${serviceData.lastSaveDate}');
      
      // Recreate notification if it was removed
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'TRIminder Tracking',
          content: 'Today: $timeStr screen time',
        );
        print('📱 Recreated notification');
      }
    });
  }

  /// Load today's total screen time from database
  static Future<void> _loadTodayScreenTime(_ServiceData serviceData) async {
    try {
      // Get current user ID (try Supabase first, then fallback to persisted)
      String? userId;
      try {
        userId = SupabaseService().currentUserId;
      } catch (e) {
        print('ℹ️ Supabase not available in background isolate: $e');
      }

      if (userId == null || userId.isEmpty) {
        try {
          final db = DatabaseService();
          final persisted = await db.getSyncMetadata('current_user_id');
          if (persisted != null && persisted.isNotEmpty) {
            userId = persisted;
            print('ℹ️ Using persisted user id for loading today\'s total: $userId');
          }
        } catch (e) {
          print('❌ Failed to read persisted user id: $e');
        }
      }

      if (userId == null || userId.isEmpty) {
        print('⚠️ No authenticated user found, starting with 0 minutes');
        serviceData.todayScreenTime = 0;
        return;
      }

      // Calculate today's date range
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Query database for today's sessions
      final db = DatabaseService();
      final todayLogs = await db.getScreenTimeEntriesForDateRange(userId, todayStart, todayEnd);
      
      // Calculate total minutes for today
      int totalMinutes = 0;
      for (final log in todayLogs) {
        if (log.durationMinutes != null) {
          totalMinutes += log.durationMinutes!;
        }
      }

      serviceData.todayScreenTime = totalMinutes;
      print('📊 Today\'s total: ${totalMinutes}m (${todayLogs.length} sessions)');
      
    } catch (e) {
      print('❌ Error loading today\'s screen time: $e');
      serviceData.todayScreenTime = 0;
    }
  }

  /// Handle screen state events in background
  @pragma('vm:entry-point')
  static void _handleScreenEvent(
    ServiceInstance service,
    ScreenStateEvent event,
    _ServiceData serviceData,
  ) async {
    try {
      switch (event) {
        case ScreenStateEvent.SCREEN_ON:
          serviceData.screenOnTime = DateTime.now();
          print('📱 Screen ON at ${serviceData.screenOnTime}');
          break;
          
        case ScreenStateEvent.SCREEN_OFF:
          if (serviceData.screenOnTime != null) {
            final DateTime screenOffTime = DateTime.now();
            final DateTime start = serviceData.screenOnTime!;
            final int sessionSeconds = screenOffTime.difference(start).inSeconds;

            final int savedMinutes = await _savePossiblySplitSession(start, screenOffTime);
            print('📱 Screen OFF - Session: ${sessionSeconds}s → saved ${savedMinutes}m');

            // Reload today's total from DB to ensure consistency
            await _loadTodayScreenTime(serviceData);

            // Update notification using DB-backed total
            if (service is AndroidServiceInstance) {
              final int hours = serviceData.todayScreenTime ~/ 60;
              final int minutes = serviceData.todayScreenTime % 60;
              final String totalStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
              service.setForegroundNotificationInfo(
                title: 'TRIminder Tracking',
                content: 'Today: $totalStr screen time',
              );
            }
            
            serviceData.screenOnTime = null;
          }
          break;
          
        case ScreenStateEvent.SCREEN_UNLOCKED:
          // Some devices only emit UNLOCK; start a session if none active
          if (serviceData.screenOnTime == null) {
            serviceData.screenOnTime = DateTime.now();
            print('📱 Screen unlocked → starting session at ${serviceData.screenOnTime}');
          } else {
            print('📱 Screen unlocked');
          }
          break;
      }
    } catch (e) {
      print('❌ Error handling screen event: $e');
    }
  }

  /// Save individual screen session
  static Future<void> _saveSession(DateTime start, DateTime end, int minutes) async {
    try {
      // Get current user ID from Supabase if available; otherwise fallback to persisted id
      String? userId;
      // Supabase may not be initialized in the background isolate – do not return here
      try {
        userId = SupabaseService().currentUserId;
      } catch (e) {
        print('ℹ️ Supabase not available in background isolate: $e');
      }

      // Fallback: use persisted last logged-in user id
      if (userId == null || userId.isEmpty) {
        try {
          final db = DatabaseService();
          final persisted = await db.getSyncMetadata('current_user_id');
          if (persisted != null && persisted.isNotEmpty) {
            userId = persisted;
            print('ℹ️ Using persisted user id for background save: $userId');
          }
        } catch (e) {
          print('❌ Failed to read persisted user id: $e');
        }
      }

      // If still no user ID, skip saving this session
      if (userId == null || userId.isEmpty) {
        print('⚠️ No authenticated user found, skipping session save');
        return;
      }

      // Store in local database
      final db = DatabaseService();
      
      // Generate unique ID using microseconds + random component
      final now = DateTime.now();
      final uniqueId = now.microsecondsSinceEpoch + (now.millisecond * 1000);
      
      final log = ScreenTimeLog(
        id: uniqueId,
        userId: userId,
        startTime: start,
        endTime: end,
        durationMinutes: minutes,
        breakTaken: false,
        createdAt: now,
        isSynced: false,
      );

      await db.insertScreenTimeEntry(log);
      print('💾 Session saved locally: ${minutes}m for user: $userId');
      
      // Trigger sync attempt (will be handled by improved sync service)
      try {
        final syncService = ImprovedSyncService();
        // Don't await - let it run in background
        syncService.performSync();
      } catch (e) {
        print('⚠️ Could not trigger sync: $e');
      }
      
    } catch (e) {
      print('❌ Error saving session: $e');
    }
  }

  /// Save daily summary data
  static Future<void> _saveDailyData(int totalMinutes) async {
    try {
      // Calculate wellness XP
      final xp = _calculateWellnessXP(totalMinutes);
      print('📊 Daily summary: ${totalMinutes}m screen time, ${xp} XP');
      
      // TODO: Store daily summary in database
      // This will be synced to cloud when app is opened
      
    } catch (e) {
      print('❌ Error saving daily data: $e');
    }
  }

  /// Calculate digital wellness XP
  static int _calculateWellnessXP(int minutes) {
    if (minutes <= 60) return 100;      // Excellent
    if (minutes <= 120) return 75;      // Great
    if (minutes <= 180) return 50;      // Good
    if (minutes <= 240) return 25;      // Fair
    if (minutes <= 360) return 10;      // High
    return 0;                           // Excessive
  }

  // Removed cloud sync from background service

  /// iOS background handler
  @pragma('vm:entry-point')
  @pragma('dart2js:tryInline')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    print('📱 iOS background mode activated');
    return true;
  }
}
