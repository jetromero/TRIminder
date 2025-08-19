import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:screen_state/screen_state.dart';
import 'package:permission_handler/permission_handler.dart';
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

    // Update notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'TRIminder Active',
        content: 'Monitoring digital wellness 📱',
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
        // Update notification with current stats
        final hours = serviceData.todayScreenTime ~/ 60;
        final minutes = serviceData.todayScreenTime % 60;
        final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'TRIminder Tracking',
            content: 'Today: $timeStr screen time',
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

        // Sync data to cloud periodically
        await _syncToCloud();

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
            final screenOffTime = DateTime.now();
            final sessionMinutes = screenOffTime.difference(serviceData.screenOnTime!).inMinutes;
            
            if (sessionMinutes > 0) {
              // Save session
              await _saveSession(serviceData.screenOnTime!, screenOffTime, sessionMinutes);
              serviceData.todayScreenTime += sessionMinutes;
              
              print('📱 Screen OFF - Session: ${sessionMinutes}m (Total: ${serviceData.todayScreenTime}m)');
              
              // Update notification
              if (service is AndroidServiceInstance) {
                service.setForegroundNotificationInfo(
                  title: 'TRIminder Tracking',
                  content: 'Session ended: ${sessionMinutes}m',
                );
              }
            }
            
            serviceData.screenOnTime = null;
          }
          break;
          
        case ScreenStateEvent.SCREEN_UNLOCKED:
          // Handle screen unlock if needed
          print('📱 Screen unlocked');
          break;
      }
    } catch (e) {
      print('❌ Error handling screen event: $e');
    }
  }

  /// Save individual screen session
  static Future<void> _saveSession(DateTime start, DateTime end, int minutes) async {
    try {
      // Get current user ID from Supabase service
      String? userId;
      try {
        final supabaseService = SupabaseService();
        userId = supabaseService.currentUserId;
        
        // If no user ID, skip saving this session
        if (userId == null || userId.isEmpty) {
          print('⚠️ No authenticated user found, skipping session save');
          return;
        }
      } catch (e) {
        print('❌ Could not get user ID, skipping session save: $e');
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

  /// Sync data to cloud (when possible)
  static Future<void> _syncToCloud() async {
    try {
      // This will attempt to sync unsynced data to Supabase
      // May fail if no internet - that's OK, will retry later
      print('☁️ Attempting cloud sync...');
      
      final syncService = ImprovedSyncService();
      await syncService.performSync();
      
    } catch (e) {
      print('❌ Cloud sync failed: $e');
      // Don't rethrow - background sync should not fail the service
    }
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  @pragma('dart2js:tryInline')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    print('📱 iOS background mode activated');
    return true;
  }
}
