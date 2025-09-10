import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:screen_state/screen_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../services/improved_sync_service.dart';
import '../utils/simplified_logger.dart';


/// Data wrapper class for service variables (enables reference passing)
class _ServiceData {
  DateTime? screenOnTime;
  DateTime? screenOffTime; // Track when screen went off for timeout logic
  int todayScreenTime = 0;
  DateTime lastSaveDate = DateTime.now();
  
  // Enhanced midnight detection
  DateTime? lastMidnightCheck; // Track last midnight check to avoid missing sessions

  // Session timeout timer
  Timer? sessionTimeoutTimer;
}


/// Persistent background service that runs automatically on device boot
/// Tracks screen time 24/7 without user intervention
/// Survives app closure, phone restarts, and system termination
@pragma('vm:entry-point')
class PersistentTrackerService {
  static const int _minRecordableSeconds = 180; // 3 minutes = 180 seconds
  static const Duration _periodicTaskInterval = Duration(seconds: 5);
  static const Duration _sessionTimeoutInterval = Duration(minutes: 1);

  
  

  static int _roundSecondsToMinutesNearest(int seconds) {
    final int minutes = (seconds / 60).round();
    return minutes;
  }

  static Future<int> _saveSessionRounded(DateTime start, DateTime end) async {
    final int seconds = end.difference(start).inSeconds;
    if (seconds < _minRecordableSeconds) {
      SimplifiedLogger.verbose('Session below threshold (${seconds}s < ${_minRecordableSeconds}s) - skipped');
      return 0;
    }
    final int minutes = _roundSecondsToMinutesNearest(seconds);
    if (minutes > 0) {
      await _saveSession(start, end, minutes);
      SimplifiedLogger.database('Saved session: ${minutes}m (${seconds}s)');
    } else {
      SimplifiedLogger.verbose('Session too short after rounding (${seconds}s) - skipped');
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
        SimplifiedLogger.error('Required permissions not granted');
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
      SimplifiedLogger.success('Persistent tracker service initialized');
      return true;

    } catch (e) {
      SimplifiedLogger.error('Failed to initialize persistent service: $e');
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
        SimplifiedLogger.service('Service already running');
        return true;
      }

      await FlutterBackgroundService().startService();
      SimplifiedLogger.service('Background service started');
      return true;

    } catch (e) {
      SimplifiedLogger.error('Failed to start service: $e');
      return false;
    }
  }

  /// Check if user is authenticated and start tracking if so
  static Future<bool> checkAuthAndStartTracking() async {
    try {
      // Check if there's an authenticated user
      final userId = SupabaseService().currentUserId;
      
      if (userId != null && userId.isNotEmpty) {
        SimplifiedLogger.user('User authenticated - starting tracking');
        return await startService();
      } else {
        SimplifiedLogger.warning('No authenticated user found - skipping tracking startup');
        return false;
      }
    } catch (e) {
      SimplifiedLogger.error('Error checking authentication: $e');
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
        SimplifiedLogger.service('Background service stopped');
      }
    } catch (e) {
      SimplifiedLogger.error('Failed to stop service: $e');
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
        SimplifiedLogger.verbose('Sent reload command to background service');
      } else {
        SimplifiedLogger.warning('Background service is not running!');
      }
    } catch (e) {
      SimplifiedLogger.error('Error sending reload command: $e');
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
        SimplifiedLogger.verbose('Sent status request to background service');
        return {'running': true, 'message': 'Service is running'};
      } else {
        SimplifiedLogger.warning('Background service is not running!');
        return {'running': false, 'message': 'Service stopped'};
      }
    } catch (e) {
      SimplifiedLogger.error('Error checking service status: $e');
      return {'running': false, 'error': e.toString()};
    }
  }

  /// Get current session data directly from background service (for isWorkingOnlyOnDashboard use)
  static Future<Map<String, dynamic>> getCurrentSessionData() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      SimplifiedLogger.verbose("getCurrentSessionData: isRunning: $isRunning");
      
      if (!isRunning) {
        return {
          'hasActiveSession': false,
          'sessionStartTime': null,
          'currentMinutes': 0,
          'todayTotal': 0,
          'error': 'Service not running',
        };
      }

      // Create a unique request ID to avoid conflicts
      final requestId = DateTime.now().millisecondsSinceEpoch;
      final completer = Completer<Map<String, dynamic>>();
      StreamSubscription? subscription;
      
      try {
        // Set up listener with unique identifier
        subscription = service.on('session_data_response').listen((data) {
          
          
          if (data != null && data['requestId'] == requestId) {
            completer.complete(Map<String, dynamic>.from(data));
            SimplifiedLogger.verbose("Session data received: ${data}");
          }
        });
        
        // Send request with unique ID
        service.invoke('get_session_data', {'requestId': requestId});
        SimplifiedLogger.verbose("Request ID: $requestId");
        
        // Wait for response with longer timeout
        final result = await completer.future.timeout(
          const Duration(minutes: 1), // Increased timeout
          onTimeout: () => {
            'hasActiveSession': false,
            'sessionStartTime': null,
            'currentMinutes': 0,
            'todayTotal': 0,
            'error': 'Timeout 1 minute',
          },
        );
        
        return result;
        
      } finally {
        // Always clean up the subscription
        subscription?.cancel();
      }
      
    } catch (e) {
      SimplifiedLogger.error('Error getting session data from service: $e');
      return {
        'hasActiveSession': false,
        'sessionStartTime': null,
        'currentMinutes': 0,
        'todayTotal': 0,
        'error': e.toString(),
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
    // Ensure Flutter binding and plugins are registered in the background isolate
    try {
      WidgetsFlutterBinding.ensureInitialized();
      // Registers all plugins (fixes MissingPluginException in background isolate)
      ui.DartPluginRegistrant.ensureInitialized();
    } catch (_) {}

    print('🎯 Background service started in isolate');

    // Initialize service data with wrapper class for reference passing
    final serviceData = _ServiceData();
    
    serviceData.lastSaveDate = DateTime.now();

    // Load today's total screen time from database
    await _loadTodayScreenTime(serviceData);

    // Start tracking immediately if screen is currently on
    // This ensures tracking starts right after login, not waiting for screen events
    // Instead of always setting screenOnTime on app open:
    if (serviceData.screenOnTime == null) {
      // Only set if no session is already active
      serviceData.screenOnTime = DateTime.now();
    } else {
      // Continue existing session
      print('Continuing existing session since ${serviceData.screenOnTime}');
    }

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

    // Periodic tasks (every 5 seconds) - for real-time updates
    Timer.periodic(_periodicTaskInterval, (timer) async {
      try {

        // Reload today's total from DB
        await _loadTodayScreenTime(serviceData);

        // Calculate total: database + current session
        int totalMinutes = serviceData.todayScreenTime; // Database total
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          totalMinutes += sessionSeconds ~/ 60; // Add current session
        }
        
        

        // Update notification with total including current live session
        if (service is AndroidServiceInstance) {
          final int hours = totalMinutes ~/ 60;
          final int minutes = totalMinutes % 60;
          final String timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
          
          try {
            String? userId;
            try {
              userId = SupabaseService().currentUserId;
            } catch (e) {
              // Fallback to persisted user ID
              final db = DatabaseService();
              userId = await db.getSyncMetadata('current_user_id');
            }
            
            if (userId != null && userId.isNotEmpty) {
              service.setForegroundNotificationInfo(
              title: 'TRIminder Tracking',
              content: 'Today: $timeStr',
            );
              
              
            } else {
              service.setForegroundNotificationInfo(
                title: 'TRIminder Tracking',
                content: 'Today: $timeStr',
              );
            }
          } catch (e) {
            print('❌ Error updating notification: $e');
            // Fallback to basic notification
            service.setForegroundNotificationInfo(
              title: 'TRIminder Tracking',
              content: 'Today: $timeStr',
            );
          }
        }

        // Store current session info for dashboard access via SharedPreferences
        int liveExtra = 0;
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          liveExtra = sessionSeconds ~/ 60; // floor to minutes
          
          await _updateSessionDataInSharedPreferences(true, serviceData.screenOnTime!, liveExtra);
        } else {
          await _updateSessionDataInSharedPreferences(false, null, 0);
        }


        // Check if new day - reset daily counter
        final now = DateTime.now();
        if (now.day != serviceData.lastSaveDate.day) {
          print('📅 New day detected - resetting daily counter');
          
          // CRITICAL: Save any ongoing session that crossed midnight
          if (serviceData.screenOnTime != null) {
            final yesterdayEnd = DateTime(now.year, now.month, now.day); // Start of today
            final yesterdayStart = serviceData.screenOnTime!;
            
            // Save the yesterday portion of the session
            final savedMinutes = await _savePossiblySplitSession(yesterdayStart, yesterdayEnd);
            print('📅 Saved yesterday session: ${savedMinutes}m (${yesterdayStart.toLocal()} to ${yesterdayEnd.toLocal()})');
            
            // Start new session for today
            serviceData.screenOnTime = now;
            print('📱 New day session started at ${serviceData.screenOnTime}');
          }
          
          serviceData.lastSaveDate = now;
          serviceData.todayScreenTime = 0;
          
          await _loadTodayScreenTime(serviceData);
        }

        

        

      } catch (e) {
        print('❌ Error in 3-second periodic task: $e');
      }
    });



    // Listen for stop command
    service.on('stop').listen((event) async {
      print('🛑 Received stop command');

      // Cancel any pending timeout
      serviceData.sessionTimeoutTimer?.cancel();
      serviceData.sessionTimeoutTimer = null;
      
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


    // Listen for session data request
    service.on('get_session_data').listen((event) async {
      final reqId = event?['requestId'];

      print("🔍 reqId: $reqId");

      int currentMinutes = 0;
      if (serviceData.screenOnTime != null) {
        final now = DateTime.now();
        final sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
        currentMinutes = sessionSeconds ~/ 60;
      }

      service.invoke('session_data_response', {
        'requestId': reqId, // critical for matching
        'hasActiveSession': serviceData.screenOnTime != null,
        'sessionStartTime': serviceData.screenOnTime?.millisecondsSinceEpoch,
        'currentMinutes': currentMinutes,
        'todayTotal': serviceData.todayScreenTime,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Handle explicit reload request from foreground
    service.on('reload_today_data').listen((event) async {
      try {
        // Reload today's total from DB
        await _loadTodayScreenTime(serviceData);

        // Recompute live session minutes for dashboard consumers
        int liveExtra = 0;
        if (serviceData.screenOnTime != null) {
          final DateTime now = DateTime.now();
          final int sessionSeconds = now.difference(serviceData.screenOnTime!).inSeconds;
          liveExtra = sessionSeconds ~/ 60; // floor to minutes
        }

        // Persist session snapshot for UI access (parity with periodic task)
        await _updateSessionDataInSharedPreferences(
          serviceData.screenOnTime != null,
          serviceData.screenOnTime,
          liveExtra,
        );

      } catch (e) {
        print('❌ Error handling reload_today_data: $e');
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
        
          
        case ScreenStateEvent.SCREEN_OFF:

          if (serviceData.screenOnTime != null) {
          // Store the actual screen off time for accurate session calculation
          serviceData.screenOffTime = DateTime.now();
          
          print('⏰ Screen OFF timeout started - session will end in ${_sessionTimeoutInterval.inMinutes} minutes if no activity');
          serviceData.sessionTimeoutTimer = Timer(_sessionTimeoutInterval, () async {
            final DateTime timeoutTime = DateTime.now();
            final DateTime start = serviceData.screenOnTime!;
            final DateTime actualScreenOffTime = serviceData.screenOffTime!;
            final int sessionSeconds = actualScreenOffTime.difference(start).inSeconds;

            // Cancel any existing timeout timer
            serviceData.sessionTimeoutTimer?.cancel();
            serviceData.sessionTimeoutTimer = null;

            print('⏰ Session timeout reached - forcing session end');
            await _forceEndSession(service, serviceData, timeoutTime, sessionSeconds, start, actualScreenOffTime);
          });
}
          break;
          
        case ScreenStateEvent.SCREEN_UNLOCKED:
          // THIS is the real user interaction - clear timeout here

          // Cancel timeout timer if user returns
          serviceData.sessionTimeoutTimer?.cancel();
          serviceData.sessionTimeoutTimer = null;

          if (serviceData.screenOffTime != null) {
            final timeSinceScreenOff = DateTime.now().difference(serviceData.screenOffTime!).inMinutes;
            print('📱 Screen UNLOCKED - user returned after ${timeSinceScreenOff}m, continuing session');
            serviceData.screenOffTime = null;
          }
          
          // Start session if none active
          if (serviceData.screenOnTime == null) {
            serviceData.screenOnTime = DateTime.now();
            print('📱 Screen unlocked → starting session at ${serviceData.screenOnTime}');
          } else {
            print('📱 Screen unlocked - already tracking since ${serviceData.screenOnTime}');
          }
          break;
        case ScreenStateEvent.SCREEN_ON:
          // Cancel timeout timer if user returns
          serviceData.sessionTimeoutTimer?.cancel();
          serviceData.sessionTimeoutTimer = null;
          print('🔄 Screen ON - timeout timer cancelled');
          
          // Start session if none active (screen is on, user might be using it)
          if (serviceData.screenOnTime == null) {
            serviceData.screenOnTime = DateTime.now();
            print('📱 Screen ON → starting session at ${serviceData.screenOnTime}');
          } else {
            print('📱 Screen ON - already tracking since ${serviceData.screenOnTime}');
          }
          break;
      }
    } catch (e) {
      print('❌ Error handling screen event: $e');
    }
  }

  /// Force end session due to timeout
  static Future<void> _forceEndSession(
    ServiceInstance service,
    _ServiceData serviceData,
    DateTime endTime,
    int sessionSeconds,
    DateTime start,
    DateTime screenOffTime,
  ) async {
    // Resolve user id (same as _saveSession)
    String? userId;

    try { userId = SupabaseService().currentUserId; } catch (_) {}
    if (userId == null || userId.isEmpty) {
      try {
        final db = DatabaseService();
        final persisted = await db.getSyncMetadata('current_user_id');
        if (persisted != null && persisted.isNotEmpty) {
          userId = persisted;
        }
      } catch (_) {}
    }

    if (userId == null || userId.isEmpty) {
      print('⚠️ No authenticated user found, skipping save');
      serviceData.screenOnTime = null;
      return;
    }


    // Ignore ultra-short blips (< 3 min)
    if (sessionSeconds < _minRecordableSeconds) {
      print('🪙 Session below recordable threshold (${sessionSeconds}s < ${_minRecordableSeconds}s) - ignored');
    } else {
      // Save session immediately - no staging, no aggregation
      final int savedMinutes = await _savePossiblySplitSession(start, screenOffTime);
      print('💾 Saved individual session: ${(sessionSeconds/60).round()}m → saved ${savedMinutes}m');
    }
    


    // Reset the session store
    serviceData.screenOnTime = null;
    print('🔄 Session store reset after screen OFF handling');

    // Reload today's total from DB to ensure consistency
    await _loadTodayScreenTime(serviceData);

    

    serviceData.screenOffTime = screenOffTime;
    
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
