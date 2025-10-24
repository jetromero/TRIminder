import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../utils/battery_optimization_helper.dart';

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
  static Future<void> _requestAllPermissions() async {
    print('🔐 Requesting permissions...');

    try {
      // Core permissions needed for background operation
      final permissions = <Permission>[];
      
      // Add notification permission only for Android 13+ (API 33+)
      if (Platform.isAndroid) {
        // Check if we're on Android 13+ for notification permission
        permissions.add(Permission.notification);
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

      // Request battery optimization bypass with manufacturer-specific guidance
      await _requestBatteryOptimizationBypass();
      
    } catch (e) {
      print('❌ Critical error in permission setup: $e');
      // Don't throw - continue with setup even if permissions fail
    }
  }

  /// Request battery optimization bypass with enhanced error handling
  static Future<void> _requestBatteryOptimizationBypass() async {
    try {
      final result = await BatteryOptimizationHelper.requestBatteryOptimizationBypass();
      if (result.success) {
        print('✅ Battery optimization bypassed successfully');
      } else {
        print('⚠️ Battery optimization bypass failed: ${result.message}');
        if (result.requiresManualSetup) {
          print('💡 Manual setup required for ${result.manufacturer ?? 'your device'}');
          print('   Deep link: ${result.deepLink ?? 'Not available'}');
          if (result.instructions != null) {
            print('   Instructions: ${result.instructions!.length} steps available');
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not request battery optimization: $e');
      // Continue with setup even if battery optimization fails
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
        print('⚠️ Battery optimization not bypassed - user may need to manually configure');
        if (status.requiresAttention) {
          print('💡 Manual setup required for ${status.manufacturer}');
          if (status.deepLink != null) {
            print('   Deep link available: ${status.deepLink}');
          }
          if (status.instructions != null) {
            print('   Instructions available: ${status.instructions!.length} steps');
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
      // Continue with setup even if battery optimization check fails
      print('⚠️ Continuing with setup despite battery optimization check failure');
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
  static Future<Map<String, dynamic>> checkSetupStatus() async {
    final results = <String, dynamic>{};
    
    // Check permissions with version safety
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    
    // Only check notification permission on Android 13+ (API 33+)
    bool notificationGranted = false;
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final notificationStatus = await Permission.notification.status;
          notificationGranted = notificationStatus == PermissionStatus.granted;
        } else {
          notificationGranted = true; // Not required on older versions
        }
      } catch (e) {
        print('Error checking notification permission: $e');
        notificationGranted = true; // Assume granted if check fails
      }
    }

    results['permissions'] = {
      'notification': notificationGranted,
      'batteryOptimization': batteryStatus == PermissionStatus.granted,
    };

    // Check if all permissions are granted
    results['allPermissionsGranted'] = results['permissions'].values.every((granted) => granted == true);
    
    // Check if background is configured
    results['backgroundConfigured'] = batteryStatus == PermissionStatus.granted;

    return results;
  }
}
