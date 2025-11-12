import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_info_helper.dart';

/// Helper class for handling battery optimization settings across different Android manufacturers
/// Provides manufacturer-specific deep links and user guidance
class BatteryOptimizationHelper {
  static const String _promptFlagKey = 'pending_battery_optimization_prompt';
  
  /// Check if battery optimization is currently bypassed
  static Future<bool> isBatteryOptimizationBypassed() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Error checking battery optimization status: $e');
      return false;
    }
  }

  /// Request battery optimization bypass with manufacturer-specific guidance
  static Future<BatteryOptimizationResult> requestBatteryOptimizationBypass() async {
    try {
      // First try the standard Android approach
      final status = await Permission.ignoreBatteryOptimizations.request();
      
      if (status == PermissionStatus.granted) {
        return BatteryOptimizationResult(
          success: true,
          message: 'Battery optimization bypassed successfully',
          requiresManualSetup: false,
        );
      }

      // If standard approach fails, provide manufacturer-specific guidance
      final manufacturer = await _getDeviceManufacturer();
      return BatteryOptimizationResult(
        success: false,
        message: 'Standard battery optimization bypass failed',
        requiresManualSetup: true,
        manufacturer: manufacturer,
        deepLink: _getManufacturerDeepLink(manufacturer),
        instructions: _getManufacturerInstructions(manufacturer),
      );
    } catch (e) {
      return BatteryOptimizationResult(
        success: false,
        message: 'Error requesting battery optimization bypass: $e',
        requiresManualSetup: true,
      );
    }
  }

  /// Get device manufacturer using device_info_helper
  static Future<String> _getDeviceManufacturer() async {
    if (!Platform.isAndroid) return 'unknown';
    
    try {
      return await DeviceInfoHelper.getManufacturer();
    } catch (e) {
      print('Error getting device manufacturer: $e');
      return 'unknown';
    }
  }

  /// Get manufacturer-specific deep link to battery settings
  static String? _getManufacturerDeepLink(String manufacturer) {
    switch (manufacturer) {
      case 'xiaomi':
        return 'miui://powerkeeper';
      case 'huawei':
      case 'honor':
        return 'huawei://systemmanager';
      case 'oppo':
        return 'oppo://safecenter';
      case 'realme':
        return 'realme://safecenter';
      case 'vivo':
        return 'vivo://safecenter';
      case 'samsung':
        return 'samsung://settings/battery';
      case 'oneplus':
        return 'oneplus://settings/battery';
      case 'tecno':
      case 'transsion':
        return 'tecno://phonemaster';
      default:
        return null;
    }
  }

  /// Get manufacturer-specific instructions
  static List<String> _getManufacturerInstructions(String manufacturer) {
    switch (manufacturer) {
      case 'xiaomi':
        return [
          '1. Open Settings → Apps → Manage apps',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery saver" → Select "No restrictions"',
          '4. Also enable "Autostart" for TRIminder',
          '5. Go to Settings → Battery & performance → Battery optimization',
          '6. Find TRIminder and set to "Don\'t optimize"'
        ];
      case 'huawei':
      case 'honor':
        return [
          '1. Open Settings → Apps → Apps',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → More battery settings',
          '5. Tap "App launch" → Find TRIminder → Enable "Manual"',
          '6. Disable "Secondary launch" restrictions'
        ];
      case 'oppo':
      case 'realme':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → More settings',
          '5. Find "Background app management" → Allow TRIminder',
          '6. Disable "Freeze background apps" for TRIminder'
        ];
      case 'vivo':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Background activity"',
          '4. Go to Settings → Battery → Background app management',
          '5. Find TRIminder and set to "Allow"',
          '6. Disable "Background app freeze" for TRIminder'
        ];
      case 'samsung':
        return [
          '1. Open Settings → Apps → TRIminder',
          '2. Tap "Battery" → Enable "Allow background activity"',
          '3. Go to Settings → Device care → Battery',
          '4. Tap "App power management" → Find TRIminder',
          '5. Set to "Unrestricted" or "Optimized"',
          '6. Go to Settings → Device care → Battery → Background app limits',
          '7. Tap "Put unused apps to sleep" → Remove TRIminder from the list',
          '8. This prevents Android from hibernating TRIminder when unused'
        ];
      case 'oneplus':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → Battery optimization',
          '5. Find TRIminder and set to "Don\'t optimize"',
          '6. Disable "Advanced optimization" for TRIminder'
        ];
      case 'tecno':
      case 'transsion':
        return [
          '1. Open Settings → Phone Master → Auto-start',
          '2. Find "TRIminder" and enable it',
          '3. Go to Settings → Phone Master → Clear apps',
          '4. Remove "TRIminder" from the clear list',
          '5. Go to Settings → Battery → Battery optimization',
          '6. Find TRIminder and set to "Don\'t optimize"',
          '7. Enable "Allow background activity" for TRIminder',
          '8. Go to Settings → Apps → TRIminder → Battery',
          '9. Set to "No restrictions" or "Allow background activity"',
          '10. Disable "Battery optimization" for TRIminder'
        ];
      default:
        return [
          '1. Open Settings → Apps → TRIminder',
          '2. Tap "Battery" → Enable "Allow background activity"',
          '3. Go to Settings → Battery → Battery optimization',
          '4. Find TRIminder and set to "Don\'t optimize"',
          '5. Ensure "Background app refresh" is enabled',
          '6. Check that TRIminder is not in any "Sleep" or "Doze" lists'
        ];
    }
  }

  /// Launch battery optimization settings page directly
  /// Opens the system battery optimization dialog for this app
  static Future<bool> launchBatterySettings() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Use native method channel to open battery optimization settings directly
      // This opens the system battery optimization dialog for TRIminder
      const MethodChannel settingsChannel = MethodChannel('com.triminder/settings');
      final bool opened = await settingsChannel.invokeMethod<bool>('openBatteryOptimizationSettings') ?? false;
      if (opened) return true;
    } catch (e) {
      print('Error opening battery optimization settings via method channel: $e');
    }
    
    // Fallback: Try using permission handler to open battery optimization dialog
    try {
      await Permission.ignoreBatteryOptimizations.request();
      return true;
    } catch (e) {
      print('Error opening battery optimization via permission handler: $e');
    }
    
    return false;
  }

  /// Show battery optimization setup dialog (simple yes/no)
  static Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    final status = await getBatteryOptimizationStatus();
    
    // Clear any pending prompt flag when dialog is shown
    await clearPromptPending();
    
    if (status.requiresAttention && context.mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'TRIminder needs battery optimization to be disabled for continuous tracking. '
            'Would you like to open the settings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );
      
      if (shouldOpen == true && context.mounted) {
        await launchBatterySettings();
      }
    }
  }

  /// Mark that we should auto-prompt the user about battery optimization
  static Future<void> setPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptFlagKey, true);
  }

  /// Clear the auto-prompt flag
  static Future<void> clearPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_promptFlagKey);
  }

  /// Check whether we should auto-prompt the user
  static Future<bool> isPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptFlagKey) ?? false;
  }

  /// Get battery optimization status for display
  static Future<BatteryOptimizationStatus> getBatteryOptimizationStatus() async {
    final isBypassed = await isBatteryOptimizationBypassed();
    final manufacturer = await _getDeviceManufacturer();
    
    return BatteryOptimizationStatus(
      isBypassed: isBypassed,
      manufacturer: manufacturer,
      requiresAttention: !isBypassed,
      deepLink: isBypassed ? null : _getManufacturerDeepLink(manufacturer),
      instructions: isBypassed ? null : _getManufacturerInstructions(manufacturer),
    );
  }
}

/// Result of battery optimization bypass request
class BatteryOptimizationResult {
  final bool success;
  final String message;
  final bool requiresManualSetup;
  final String? manufacturer;
  final String? deepLink;
  final List<String>? instructions;

  BatteryOptimizationResult({
    required this.success,
    required this.message,
    required this.requiresManualSetup,
    this.manufacturer,
    this.deepLink,
    this.instructions,
  });
}

/// Battery optimization status information
class BatteryOptimizationStatus {
  final bool isBypassed;
  final String manufacturer;
  final bool requiresAttention;
  final String? deepLink;
  final List<String>? instructions;

  BatteryOptimizationStatus({
    required this.isBypassed,
    required this.manufacturer,
    required this.requiresAttention,
    this.deepLink,
    this.instructions,
  });
}

