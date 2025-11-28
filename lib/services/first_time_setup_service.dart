import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../utils/battery_optimization_helper.dart';
import '../utils/android_permission_helper.dart';
import '../utils/app_hibernation_helper.dart';
import '../utils/usage_stats_helper.dart';

/// Service to handle first-time setup and automatic background configuration
class FirstTimeSetupService {
  static const String _firstRunKey = 'first_run_completed';
  static const String _backgroundConfiguredKey = 'background_configured';

  /// Check if this is the first time running the app
  static Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final firstRunCompleted = prefs.getBool(_firstRunKey);
    return firstRunCompleted != true;
  }

  /// Mark first run as completed
  static Future<void> markFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRunKey, true);
  }

  /// Check if background has been configured
  static Future<bool> isBackgroundConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundConfiguredKey) ?? false;
  }

  /// Mark background as configured
  static Future<void> markBackgroundConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundConfiguredKey, true);
  }

  /// Perform first-time setup
  static Future<void> performFirstTimeSetup() async {
    if (!await isFirstRun()) {
      print('📱 Not first run, skipping setup');
      return;
    }

    print('🚀 Performing first-time setup...');

    try {
      // Request all necessary permissions
      await _requestAllPermissions();
      
      // Configure background settings
      await _configureBackgroundSettings();
      
      // Mark setup as completed
      await markFirstRunCompleted();
      
      print('✅ First-time setup completed successfully');
    } catch (e) {
      print('❌ First-time setup failed: $e');
    }
  }

  /// Request all necessary permissions for background operation
  /// Android 8.0+ (API 26+): Notification channels, battery optimization
  /// Android 12+ (API 31+): Exact alarm permission
  /// Android 13+ (API 33+): Notification permission
  /// All versions: USAGE_STATS permission (for screen state detection)
  static Future<void> _requestAllPermissions() async {
    print('🔐 Requesting permissions...');

    try {
      // Core permissions needed for background operation
      final permissions = <Permission>[];
      
      // Add notification permission only for Android 13+ (API 33+)
      if (Platform.isAndroid) {
        try {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            permissions.add(Permission.notification);
          }
        } catch (e) {
          print('⚠️ Error checking Android version for notification permission: $e');
          // Default to requesting notification permission if version check fails
          permissions.add(Permission.notification);
        }
      }

      // Request basic permissions with error handling
      if (permissions.isNotEmpty) {
        try {
          Map<Permission, PermissionStatus> statuses = await permissions.request();
          
          // Log permission results
          statuses.forEach((permission, status) {
            print('   ${permission.toString().split('.').last}: $status');
          });
        } catch (e) {
          print('⚠️ Error requesting basic permissions: $e');
          // Continue with setup even if permission request fails
        }
      }

      // Check exact alarm permission status but DON'T redirect to settings before login
      // This permission request will be shown after user logs in
      if (Platform.isAndroid) {
        try {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          if (androidInfo.version.sdkInt >= 31) {
            print('📱 Checking exact alarm permission status (not requesting yet)...');
            final exactAlarmGranted = await AndroidPermissionHelper.isExactAlarmPermissionGranted();
            if (exactAlarmGranted) {
              print('✅ Exact alarm permission already granted');
            } else {
              print('ℹ️ Exact alarm permission not granted - will prompt after login');
              // Will be handled in permission status widget after login
            }
          }
        } catch (e) {
          print('⚠️ Error checking exact alarm permission: $e');
        }
      }

      // Check USAGE_STATS permission status but DON'T redirect to settings before login
      // This permission request will be shown after user logs in via UsageStatsHelper
      if (Platform.isAndroid) {
        try {
          print('📱 Checking USAGE_STATS permission status (not requesting yet)...');
          final usageStatsGranted = await AndroidPermissionHelper.isUsageStatsPermissionGranted();
          if (usageStatsGranted) {
            print('✅ USAGE_STATS permission already granted');
          } else {
            print('ℹ️ USAGE_STATS permission not granted - will prompt after login');
            // Set pending flag so it will be prompted after login
            await UsageStatsHelper.setPromptPending();
          }
        } catch (e) {
          print('⚠️ Error checking USAGE_STATS permission: $e');
        }
      }

      // Check battery optimization status and set pending flag if needed
      await _checkBatteryOptimizationStatus();
      
      // Check app hibernation status (Android 12+)
      await _checkAppHibernationStatus();
      
    } catch (e) {
      print('❌ Critical error in permission setup: $e');
      // Don't throw - continue with setup even if permissions fail
    }
  }


  /// Check battery optimization status and set pending flag if needed
  static Future<void> _checkBatteryOptimizationStatus() async {
    try {
      final status = await BatteryOptimizationHelper.getBatteryOptimizationStatus();
      if (!status.isBypassed) {
        print('⚠️ Battery optimization not bypassed - will prompt user after login');
        print('💡 Manual setup required for ${status.manufacturer}');
        if (status.deepLink != null) {
          print('   Deep link available: ${status.deepLink}');
        }
        if (status.instructions != null) {
          print('   Instructions available: ${status.instructions!.length} steps');
        }
        // Set pending flag to show dialog after login
        await BatteryOptimizationHelper.setPromptPending();
      } else {
        print('✅ Battery optimization bypassed - background service will run continuously');
      }
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
      // Set pending flag anyway to ensure user sees the prompt
      await BatteryOptimizationHelper.setPromptPending();
    }
  }

  /// Configure background settings with enhanced error handling
  static Future<void> _configureBackgroundSettings() async {
    print('⚙️ Configuring background settings...');

    try {
      // Check battery optimization status using the helper
      final status = await BatteryOptimizationHelper.getBatteryOptimizationStatus();
      if (status.isBypassed) {
        print('✅ Battery optimization bypassed - background service will run continuously');
        await markBackgroundConfigured();
      } else {
        print('⚠️ Battery optimization not bypassed - will prompt user after login');
        if (status.requiresAttention) {
          print('💡 Manual setup required for ${status.manufacturer}');
          if (status.deepLink != null) {
            print('   Deep link available: ${status.deepLink}');
          }
          if (status.instructions != null) {
            print('   Instructions available: ${status.instructions!.length} steps');
          }
        }
        // Set pending flag to show dialog after login
        await BatteryOptimizationHelper.setPromptPending();
      }

      // Check app hibernation status (Android 12+)
      await _checkAppHibernationStatus();
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
      // Continue with setup even if battery optimization check fails
      print('⚠️ Continuing with setup despite battery optimization check failure');
      // Set pending flag anyway to ensure user sees the prompt
      await BatteryOptimizationHelper.setPromptPending();
    }
  }

  /// Check app hibernation status and provide guidance
  static Future<void> _checkAppHibernationStatus() async {
    try {
      final hibernationStatus = await AppHibernationHelper.getAppHibernationStatus();
      if (hibernationStatus.isAvailable) {
        print('📱 App Hibernation feature detected (Android 12+)');
        if (hibernationStatus.requiresAttention) {
          print('⚠️ App Hibernation may affect background tracking');
          print('💡 Manual setup required for ${hibernationStatus.manufacturer}');
          if (hibernationStatus.deepLink != null) {
            print('   Deep link available: ${hibernationStatus.deepLink}');
          }
          if (hibernationStatus.instructions != null) {
            print('   Instructions available: ${hibernationStatus.instructions!.length} steps');
            print('   First step: ${hibernationStatus.instructions!.first}');
          }
          // Auto-prompt the user via UI layer
          await AppHibernationHelper.setPromptPending();
        } else {
          print('✅ App Hibernation configured - tracking should continue');
        }
      } else {
        print('ℹ️ App Hibernation not available (Android < 12)');
      }
    } catch (e) {
      print('⚠️ Could not check app hibernation status: $e');
      // Continue with setup even if app hibernation check fails
    }
  }

  /// Show setup instructions to user
  static List<String> getSetupInstructions() {
    return [
      '🔋 For continuous tracking, please:',
      '1. Go to Settings → Apps → TRIminder',
      '2. Tap "Battery"',
      '3. Select "Run in Background"',
      '4. This ensures tracking works during sleep',
    ];
  }

  /// Check if setup is optimal for background tracking
  /// Android 8.0+ (API 26+): Notification channels, battery optimization
  /// Android 12+ (API 31+): Exact alarm permission
  /// Android 13+ (API 33+): Notification permission
  /// All versions: USAGE_STATS permission (for screen state detection)
  static Future<Map<String, dynamic>> checkSetupStatus() async {
    final results = <String, dynamic>{};
    
    // Check permissions with version safety
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    
    // Only check notification permission on Android 13+ (API 33+)
    bool notificationGranted = false;
    bool exactAlarmGranted = false;
    bool usageStatsGranted = false;
    
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        // Check notification permission (Android 13+)
        if (sdkInt >= 33) {
          final notificationStatus = await Permission.notification.status;
          notificationGranted = notificationStatus == PermissionStatus.granted;
        } else {
          notificationGranted = true; // Not required on older versions
        }
        
        // Check exact alarm permission (Android 12+)
        if (sdkInt >= 31) {
          exactAlarmGranted = await AndroidPermissionHelper.isExactAlarmPermissionGranted();
        } else {
          exactAlarmGranted = true; // Not required on older versions
        }
        
        // Check USAGE_STATS permission (all versions, but optional)
        usageStatsGranted = await AndroidPermissionHelper.isUsageStatsPermissionGranted();
        // Note: USAGE_STATS check may return false even if granted, as it requires native check
        // We'll treat it as optional for now
      } catch (e) {
        print('Error checking permissions: $e');
        // Assume granted if check fails to avoid blocking setup
        notificationGranted = true;
        exactAlarmGranted = true;
        usageStatsGranted = false; // Default to false for USAGE_STATS as it's optional
      }
    } else {
      // Non-Android platforms
      notificationGranted = true;
      exactAlarmGranted = true;
      usageStatsGranted = false;
    }

    results['permissions'] = {
      'notification': notificationGranted,
      'batteryOptimization': batteryStatus == PermissionStatus.granted,
      'exactAlarm': exactAlarmGranted,
      'usageStats': usageStatsGranted, // Optional, so don't block on this
    };

    // Check if all critical permissions are granted (USAGE_STATS is optional)
    results['allPermissionsGranted'] = 
        notificationGranted && 
        batteryStatus == PermissionStatus.granted && 
        exactAlarmGranted;
    
    // Check if background is configured
    results['backgroundConfigured'] = batteryStatus == PermissionStatus.granted;
    
    // Add optional permissions status
    results['optionalPermissions'] = {
      'usageStats': usageStatsGranted,
    };

    return results;
  }
}
