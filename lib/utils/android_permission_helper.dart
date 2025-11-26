import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/usage_stats_service.dart';

/// Helper class for handling Android-specific permissions that require special handling
/// Includes exact alarms (Android 12+) and USAGE_STATS (all versions)
class AndroidPermissionHelper {
  
  /// Check if exact alarm permission is granted (Android 12+)
  /// Note: This requires a native implementation or platform channel
  /// For now, we'll check SDK version and provide guidance
  static Future<bool> isExactAlarmPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      // Exact alarms require permission only on Android 12+ (API 31+)
      if (sdkInt < 31) {
        return true; // Not required on older versions
      }
      
      // On Android 12+, exact alarms are granted by default but can be revoked
      // We need to check via AlarmManager.canScheduleExactAlarms()
      // This requires a platform channel - for now, assume granted if on Android 12+
      // TODO: Implement platform channel to check AlarmManager.canScheduleExactAlarms()
      return true;
    } catch (e) {
      print('Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission (Android 12+)
  /// On Android 12+, this opens Settings > Apps > Special app access > Alarms & reminders
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      // Only required on Android 12+ (API 31+)
      if (sdkInt < 31) {
        return true; // Not required on older versions
      }
      
      // On Android 12+, exact alarms permission must be granted via Settings
      // Try multiple intent formats for different Android versions
      final intents = [
        'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        'android.settings.action.REQUEST_SCHEDULE_EXACT_ALARM',
        'android.settings.ALARM_AND_REMINDER_SETTINGS',
      ];
      
      for (final intent in intents) {
        try {
          final uri = Uri.parse(intent);
          if (await canLaunchUrl(uri)) {
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (launched) return true;
          }
        } catch (e) {
          // Try next intent
          continue;
        }
      }
      
      // Fallback: Try to open app settings where user can find exact alarms
      return await _openAppSettings();
    } catch (e) {
      print('Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Check if USAGE_STATS permission is granted
  /// Uses UsageStatsService to check permission status
  static Future<bool> isUsageStatsPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await UsageStatsService.isPermissionGranted();
    } catch (e) {
      print('Error checking USAGE_STATS permission: $e');
      return false;
    }
  }

  /// Request USAGE_STATS permission
  /// Launches settings intent for usage access
  static Future<bool> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await UsageStatsService.requestPermission();
    } catch (e) {
      print('Error requesting USAGE_STATS permission: $e');
      return false;
    }
  }

  /// Check and request UsageStats permission if not granted
  static Future<bool> checkAndRequestUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    
    final isGranted = await isUsageStatsPermissionGranted();
    if (isGranted) {
      return true;
    }
    
    return await requestUsageStatsPermission();
  }

  /// Open app settings page
  static Future<bool> _openAppSettings() async {
    try {
      // Open app-specific settings using package name
      // Format: android.settings.APPLICATION_DETAILS_SETTINGS with data=package:com.triminder
      final uri = Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS');
      // Note: We need to use a platform channel or method channel to pass the package name
      // For now, just open general app settings
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('Error opening app settings: $e');
      return false;
    }
  }

  /// Get instructions for granting exact alarm permission (Android 12+)
  static List<String> getExactAlarmInstructions() {
    return [
      '1. Open Settings on your device',
      '2. Go to Apps → Special app access',
      '3. Tap "Alarms & reminders"',
      '4. Find "TRIminder" in the list',
      '5. Enable "Allow exact alarms"',
      '6. Return to TRIminder to continue',
    ];
  }

  /// Get instructions for granting USAGE_STATS permission
  static List<String> getUsageStatsInstructions() {
    return [
      '1. Open Settings on your device',
      '2. Go to Apps → Special app access',
      '3. Tap "Usage access"',
      '4. Find "TRIminder" in the list',
      '5. Enable "Permit usage access"',
      '6. Return to TRIminder to continue',
    ];
  }

  /// Check Android version and return capability flags
  static Future<Map<String, bool>> getPermissionCapabilities() async {
    if (!Platform.isAndroid) {
      return {
        'supportsExactAlarms': false,
        'supportsUsageStats': false,
      };
    }
    
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      return {
        'supportsExactAlarms': sdkInt >= 31, // Android 12+
        'supportsUsageStats': true, // Available on all Android versions
      };
    } catch (e) {
      print('Error getting permission capabilities: $e');
      return {
        'supportsExactAlarms': false,
        'supportsUsageStats': false,
      };
    }
  }

  /// Request all Android-specific permissions that require special handling
  static Future<Map<String, bool>> requestAllSpecialPermissions() async {
    final results = <String, bool>{};
    
    if (!Platform.isAndroid) {
      return results;
    }
    
    try {
      final capabilities = await getPermissionCapabilities();
      
      // Request exact alarm permission if supported (Android 12+)
      if (capabilities['supportsExactAlarms'] == true) {
        print('📱 Requesting exact alarm permission (Android 12+)...');
        final exactAlarmGranted = await requestExactAlarmPermission();
        results['exactAlarm'] = exactAlarmGranted;
        if (exactAlarmGranted) {
          print('✅ Exact alarm permission request launched');
        } else {
          print('⚠️ Failed to launch exact alarm permission settings');
        }
      }
      
      // Request USAGE_STATS permission
      if (capabilities['supportsUsageStats'] == true) {
        print('📱 Requesting USAGE_STATS permission...');
        final usageStatsGranted = await requestUsageStatsPermission();
        results['usageStats'] = usageStatsGranted;
        if (usageStatsGranted) {
          print('✅ USAGE_STATS permission request launched');
        } else {
          print('⚠️ Failed to launch USAGE_STATS permission settings');
        }
      }
      
      return results;
    } catch (e) {
      print('❌ Error requesting special permissions: $e');
      return results;
    }
  }
}

