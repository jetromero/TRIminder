import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'device_info_helper.dart';

/// Helper class for handling battery optimization settings across different Android manufacturers
/// Provides manufacturer-specific deep links and user guidance
class BatteryOptimizationHelper {
  
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
          '6. Disable "Put unused apps to sleep" for TRIminder'
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

  /// Launch manufacturer-specific battery settings
  static Future<bool> launchBatterySettings() async {
    try {
      final manufacturer = await _getDeviceManufacturer();
      final deepLink = _getManufacturerDeepLink(manufacturer);
      
      if (deepLink != null) {
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }
      
      // Fallback to generic battery settings
      return await _launchGenericBatterySettings();
    } catch (e) {
      print('Error launching battery settings: $e');
      return false;
    }
  }

  /// Launch generic Android battery settings
  static Future<bool> _launchGenericBatterySettings() async {
    try {
      final uri = Uri.parse('android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      
      // Alternative generic settings
      final altUri = Uri.parse('android.settings.BATTERY_OPTIMIZATION_SETTINGS');
      if (await canLaunchUrl(altUri)) {
        return await launchUrl(altUri);
      }
      
      return false;
    } catch (e) {
      print('Error launching generic battery settings: $e');
      return false;
    }
  }

  /// Show battery optimization setup dialog
  static Future<void> showBatteryOptimizationDialog(BuildContext context) async {
    final result = await requestBatteryOptimizationBypass();
    
    if (!result.success && result.requiresManualSetup) {
      showDialog(
        context: context,
        builder: (context) => BatteryOptimizationDialog(
          result: result,
        ),
      );
    }
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

/// Dialog for showing battery optimization setup instructions
class BatteryOptimizationDialog extends StatelessWidget {
  final BatteryOptimizationResult result;

  const BatteryOptimizationDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Battery Optimization Setup'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'For TRIminder to work properly, you need to disable battery optimization. '
              'This ensures the app can track screen time even when the phone is idle.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (result.instructions != null) ...[
              const Text(
                'Please follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...result.instructions!.map((instruction) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  instruction,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I\'ll do this later'),
        ),
        if (result.deepLink != null)
          ElevatedButton(
            onPressed: () async {
              await BatteryOptimizationHelper.launchBatterySettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ElevatedButton(
          onPressed: () async {
            final success = await BatteryOptimizationHelper.launchBatterySettings();
            if (!success) {
              // Show fallback instructions
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please manually open Settings → Battery → Battery optimization'),
                ),
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
