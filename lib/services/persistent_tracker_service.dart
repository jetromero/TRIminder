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
  DateTime? screenOffTime; // Track when screen went off for timeout logic
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

  /// Get current session data directly from background service
  static Future<Map<String, dynamic>> getCurrentSessionData() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (!isRunning) {
        return {
          'hasActiveSession': false,
          'sessionStartTime': null,
          'currentMinutes': 0,
          'todayTotal': 0,
          'error': 'Service not running',
        };
      }

      // Trigger session data update in background service
      service.invoke('get_session_data');
      
      // Wait for the background service to update SharedPreferences
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Get the updated data from SharedPreferences
      Map<String, dynamic> sessionData = await _getSessionDataFromSharedPreferences();
      
      return sessionData;
    } catch (e) {
      print('❌ Error getting session data from service: $e');
      // Fallback to SharedPreferences
      return await _getSessionDataFromSharedPreferences();
    }
  }

  /// Fallback method to get session data from SharedPreferences
  static Future<Map<String, dynamic>> _getSessionDataFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasActiveSession = prefs.getBool('has_active_session') ?? false;
      final sessionStartTimeMs = prefs.getInt('session_start_time');
      final currentMinutes = prefs.getInt('current_session_minutes') ?? 0;
      
      return {
        'hasActiveSession': hasActiveSession,
        'sessionStartTime': sessionStartTimeMs,
        'currentMinutes': currentMinutes,
        'todayTotal': 0, // Would need to load from DB
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'SharedPreferences',
      };
    } catch (e) {
      return {
        'hasActiveSession': false,
        'sessionStartTime': null,
        'currentMinutes': 0,
        'todayTotal': 0,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Request necessary permissions for background operation
  static Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.notification,
      Permission.systemAlertWindow, // For screen state detection
      Permission.phone, // For device state monitoring
      Permission.ignoreBatteryOptimizations, // 🔥 Critical for background survival
    ];

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Check if all required permissions are granted
    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      print('⚠️ Some permissions not granted: $statuses');
      
      // Try to request battery optimization bypass again if denied
      if (statuses[Permission.ignoreBatteryOptimizations] != PermissionStatus.granted) {
        print('🔋 CRITICAL: Battery optimization bypass denied - app will be killed during sleep!');
        print('🔋 Please manually enable "Allow background activity" in device settings');
        
        // Try one more time with a delay
        await Future.delayed(const Duration(seconds: 2));
        final retryResult = await Permission.ignoreBatteryOptimizations.request();
        if (retryResult == PermissionStatus.granted) {
          print('✅ Battery optimization bypass granted on retry');
          allGranted = true;
        } else {
          print('❌ Battery optimization bypass still denied - app will not survive background');
        }
      }
    } else {
      print('✅ All permissions granted');
    }

    // Request auto-start permission (for some Android devices)
    try {
      final autoStartStatus = await Permission.ignoreBatteryOptimizations.status;
      if (autoStartStatus == PermissionStatus.granted) {
        print('✅ Auto-start permission available');
      }
    } catch (e) {
      print('⚠️ Auto-start permission not available: $e');
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

    // Start tracking immediately if screen is currently on
    // This ensures tracking starts right after login, not waiting for screen events
    serviceData.screenOnTime = DateTime.now();
    print('📱 Tracking started immediately at ${serviceData.screenOnTime}');

    // Immediately store session data for dashboard access
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_active_session', true);
      await prefs.setInt('session_start_time', serviceData.screenOnTime!.millisecondsSinceEpoch);
      await prefs.setInt('current_session_minutes', 0);
      print('💾 Initial session data stored for dashboard');
    } catch (e) {
      print('❌ Error storing initial session data: $e');
    }

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

    // Periodic tasks (every 5 minutes)
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        // Checkpoint save for long-running sessions (every 5 minutes)
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int elapsedSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          if (elapsedSeconds >= 300) { // 5 minutes
            final int saved = await _savePossiblySplitSession(serviceData.screenOnTime!, now);
            print('⏱️ Checkpoint: active ${elapsedSeconds}s → saved ${saved}m, resetting start');
            // Reset start to now for the next chunk
            serviceData.screenOnTime = now;
          }
          
          // Check for screen off timeout (1 minute)
          if (serviceData.screenOffTime != null) {
            final timeSinceScreenOff = DateTime.now().difference(serviceData.screenOffTime!).inMinutes;
            if (timeSinceScreenOff >= 1) {
              print('⏰ Screen OFF timeout: ${timeSinceScreenOff}m since screen off, ending session');
              serviceData.screenOnTime = null;
              serviceData.screenOffTime = null;
              // Clear session data from SharedPreferences
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_active_session', false);
                await prefs.remove('session_start_time');
                await prefs.setInt('current_session_minutes', 0);
                print('🧹 Cleared session data after screen off timeout');
              } catch (e) {
                print('❌ Error clearing session data after screen off timeout: $e');
              }
            }
          }
          
          // End session after 30 minutes of total inactivity (1800 seconds)
          if (elapsedSeconds >= 1800) {
            print('⏰ Session timeout: ${elapsedSeconds}s of inactivity, ending session');
            serviceData.screenOnTime = null;
            serviceData.screenOffTime = null;
            // Clear session data from SharedPreferences
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_active_session', false);
              await prefs.remove('session_start_time');
              await prefs.setInt('current_session_minutes', 0);
              print('🧹 Cleared session data after timeout');
            } catch (e) {
              print('❌ Error clearing session data after timeout: $e');
            }
          }
        }

        // Reload today's total from DB (every tick since we're now on 5-minute intervals)
        await _loadTodayScreenTime(serviceData);

        // Compute live display with current session (for dashboard only, not notification)
        int liveExtra = 0;
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          liveExtra = sessionSeconds ~/ 60; // floor to minutes
          
          // Store current session info for dashboard access via SharedPreferences
          await _updateSessionDataInSharedPreferences(true, serviceData.screenOnTime!, liveExtra);
        } else {
          // No active session
          await _updateSessionDataInSharedPreferences(false, null, 0);
        }

        // Notification shows only database total (no live session) to match dashboard
        final int hours = serviceData.todayScreenTime ~/ 60;
        final int minutes = serviceData.todayScreenTime % 60;
        final String timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'TRIminder Tracking',
            content: 'Today: $timeStr',
          );
        }

        // Check if new day - reset daily counter
        final now = DateTime.now();
        if (now.day != serviceData.lastSaveDate.day) {
          print('📅 New day detected - resetting daily counter');
          serviceData.lastSaveDate = now;
          serviceData.todayScreenTime = 0;
          await _loadTodayScreenTime(serviceData);
        }

        // Auto-restart check (every 10 minutes = every 2 ticks)
        if (timer.tick % 2 == 0) {
          print('🔍 Auto-restart check: Service running for ${timer.tick * 5} minutes');
          // Keep the service alive by updating notification (simplified)
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'TRIminder Tracking',
              content: 'Today: $timeStr',
            );
          }
        }

      } catch (e) {
        print('❌ Error in periodic task: $e');
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

    // Listen for session data request
    service.on('get_session_data').listen((event) async {
      print('📊 Session data request received');
      
      // Calculate current session minutes
      int currentMinutes = 0;
      if (serviceData.screenOnTime != null) {
        final now = DateTime.now();
        final sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
        currentMinutes = sessionSeconds ~/ 60;
      }
      
      // Update session data in SharedPreferences using consolidated method
      await _updateSessionDataInSharedPreferences(
        serviceData.screenOnTime != null,
        serviceData.screenOnTime,
        currentMinutes,
      );
    });

    // Listen for notification update request (after sync)
    service.on('update_notification').listen((event) async {
      print('📱 Notification update request received');
      
      final title = event?['title'] ?? 'TRIminder Tracking';
      final content = event?['content'] ?? 'Today: 0m';
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
        print('📱 Notification updated: $title - $content');
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
          // Clear screen off timeout since user is back
          if (serviceData.screenOffTime != null) {
            final timeSinceScreenOff = DateTime.now().difference(serviceData.screenOffTime!).inMinutes;
            print('📱 Screen ON - user returned after ${timeSinceScreenOff}m, continuing session');
            serviceData.screenOffTime = null;
          }
          
          // Only start new session if not already tracking
          if (serviceData.screenOnTime == null) {
          serviceData.screenOnTime = DateTime.now();
            print('📱 Screen ON - started new session at ${serviceData.screenOnTime}');
          } else {
            print('📱 Screen ON - continuing existing session since ${serviceData.screenOnTime}');
          }
          break;
          
        case ScreenStateEvent.SCREEN_OFF:
          if (serviceData.screenOnTime != null) {
            final DateTime screenOffTime = DateTime.now();
            final DateTime start = serviceData.screenOnTime!;
            final int sessionSeconds = screenOffTime.difference(start).inSeconds;

            final int savedMinutes = await _savePossiblySplitSession(start, screenOffTime);
            print('📱 Screen OFF - Session: ${sessionSeconds}s → saved ${savedMinutes}m');

            // Reset the session store after saving to prevent duplicates
            serviceData.screenOnTime = null;
            print('🔄 Session store reset after screen OFF save');

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
            
            // Start a timeout timer for screen OFF
            // If no SCREEN_ON within 1 minute, end the session
            serviceData.screenOffTime = screenOffTime;
            print('⏰ Screen OFF timeout started - session will end in 1 minute if no activity');
          }
          break;
          
        case ScreenStateEvent.SCREEN_UNLOCKED:
          // Some devices only emit UNLOCK; start a session if none active
          if (serviceData.screenOnTime == null) {
            serviceData.screenOnTime = DateTime.now();
            print('📱 Screen unlocked → starting session at ${serviceData.screenOnTime}');
          } else {
            print('📱 Screen unlocked - already tracking since ${serviceData.screenOnTime}');
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

  /// Force refresh notification after sync completion
  static Future<void> refreshNotificationAfterSync() async {
    try {
      print('🔄 Refreshing notification after sync completion');
      
      // Reload today's data from database
      final serviceData = _ServiceData();
      await _loadTodayScreenTime(serviceData);
      
      // Update notification with fresh data
      final int hours = serviceData.todayScreenTime ~/ 60;
      final int minutes = serviceData.todayScreenTime % 60;
      final String timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      
      // Send event to background service to update notification
      FlutterBackgroundService().invoke('update_notification', {
        'title': 'TRIminder Tracking',
        'content': 'Today: $timeStr',
      });
      
      print('📱 Notification refresh event sent after sync: $timeStr');
    } catch (e) {
      print('❌ Error refreshing notification after sync: $e');
    }
  }

  /// Update session data in SharedPreferences
  static Future<void> _updateSessionDataInSharedPreferences(
    bool hasActiveSession,
    DateTime? sessionStartTime,
    int currentMinutes,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_active_session', hasActiveSession);
      if (sessionStartTime != null) {
        await prefs.setInt('session_start_time', sessionStartTime.millisecondsSinceEpoch);
      } else {
        await prefs.remove('session_start_time');
      }
      await prefs.setInt('current_session_minutes', currentMinutes);
      print('💾 Updated session data in SharedPreferences: active=$hasActiveSession, start=${sessionStartTime?.toLocal()}, minutes=$currentMinutes');
    } catch (e) {
      print('❌ Error updating session data in SharedPreferences: $e');
    }
  }
}
