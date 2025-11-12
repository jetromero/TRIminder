import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_info_helper.dart';

/// Helper class for handling Android App Hibernation settings (Android 12+)
/// App Hibernation automatically revokes permissions and stops background services
/// for apps that haven't been used recently. This can break TRIminder's tracking.
class AppHibernationHelper {
  static const String _promptFlagKey = 'pending_app_hibernation_prompt';
  static const MethodChannel _settingsChannel = MethodChannel('com.triminder/settings');
  
  /// Check if app hibernation feature is available (Android 12+)
  static Future<bool> isAppHibernationAvailable() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final sdkInt = await DeviceInfoHelper.getAndroidSdkInt();
      // App Hibernation was introduced in Android 12 (API 31)
      return sdkInt >= 31;
    } catch (e) {
      print('Error checking app hibernation availability: $e');
      return false;
    }
  }

  /// Get app hibernation status
  /// Note: Cannot be directly detected via API, so we provide proactive guidance
  static Future<AppHibernationStatus> getAppHibernationStatus() async {
    final isAvailable = await isAppHibernationAvailable();
    final manufacturer = await _getDeviceManufacturer();
    
    return AppHibernationStatus(
      isAvailable: isAvailable,
      manufacturer: manufacturer,
      requiresAttention: isAvailable, // Assume it needs attention if available
      deepLink: isAvailable ? _getManufacturerDeepLink(manufacturer) : null,
      instructions: isAvailable ? _getManufacturerInstructions(manufacturer) : null,
    );
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

  /// Get manufacturer-specific deep link to app hibernation settings
  static String? _getManufacturerDeepLink(String manufacturer) {
    switch (manufacturer) {
      case 'samsung':
        return 'samsung://settings/device_care/battery';
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
      case 'oneplus':
        return 'oneplus://settings/battery';
      case 'tecno':
      case 'transsion':
        return 'tecno://phonemaster';
      default:
        return null;
    }
  }

  /// Get manufacturer-specific instructions for disabling app hibernation
  static List<String> _getManufacturerInstructions(String manufacturer) {
    switch (manufacturer) {
      case 'samsung':
        return [
          '1. Open Settings → Device care → Battery',
          '2. Tap "Background app limits"',
          '3. Tap "Put unused apps to sleep"',
          '4. Find "TRIminder" in the list',
          '5. Remove TRIminder from the sleep list (or disable the toggle)',
          '6. Also check: Settings → Apps → TRIminder → Battery → "Allow background activity"',
        ];
      case 'xiaomi':
        return [
          '1. Open Settings → Apps → Manage apps',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery saver" → Select "No restrictions"',
          '4. Go to Settings → Battery & performance → Battery optimization',
          '5. Find TRIminder and set to "Don\'t optimize"',
          '6. Ensure TRIminder is not in "Sleeping apps" list',
        ];
      case 'huawei':
      case 'honor':
        return [
          '1. Open Settings → Apps → Apps',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → More battery settings',
          '5. Tap "App launch" → Find TRIminder → Enable "Manual"',
          '6. Check that TRIminder is not in "App hibernation" list',
        ];
      case 'oppo':
      case 'realme':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → More settings',
          '5. Find "Background app management" → Allow TRIminder',
          '6. Disable "Freeze background apps" for TRIminder',
          '7. Check that TRIminder is not in "Sleeping apps" list',
        ];
      case 'vivo':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Background activity"',
          '4. Go to Settings → Battery → Background app management',
          '5. Find TRIminder and set to "Allow"',
          '6. Disable "Background app freeze" for TRIminder',
          '7. Check that TRIminder is not in "Sleeping apps" list',
        ];
      case 'oneplus':
        return [
          '1. Open Settings → Apps → App management',
          '2. Find "TRIminder" and tap on it',
          '3. Tap "Battery" → Enable "Allow background activity"',
          '4. Go to Settings → Battery → Battery optimization',
          '5. Find TRIminder and set to "Don\'t optimize"',
          '6. Go to Settings → Apps → Special app access → Unused apps',
          '7. Ensure TRIminder is not listed or is excluded',
        ];
      case 'tecno':
      case 'transsion':
        return [
          '1. Open Settings → Apps → TRIminder',
          '2. Tap "Battery" → Set to "No restrictions"',
          '3. Enable "Allow background activity"',
          '4. Go to Settings → Phone Master → Clear apps',
          '5. Remove "TRIminder" from the clear list',
          '6. Go to Settings → Battery → Battery optimization',
          '7. Find TRIminder and set to "Don\'t optimize"',
          '8. Check that TRIminder is not in "Sleeping apps" list',
        ];
      default:
        // Stock Android (Android 12+)
        return [
          '1. Open Settings → Apps → TRIminder',
          '2. Tap "Unused apps" (or "App hibernation")',
          '3. Turn OFF "Remove permissions and free up space"',
          '4. If the option is not visible, go to Settings → Apps → Special app access',
          '5. Tap "Unused apps" → Find TRIminder → Disable hibernation',
          '6. Also ensure: Settings → Apps → TRIminder → Battery → "Allow background activity"',
        ];
    }
  }

  /// Launch manufacturer-specific app hibernation settings
  static Future<bool> launchAppHibernationSettings() async {
    try {
      final manufacturer = await _getDeviceManufacturer();
      final deepLink = _getManufacturerDeepLink(manufacturer);
      
      if (deepLink != null) {
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      
      // Fallback to generic app settings
      return await _launchGenericAppSettings();
    } catch (e) {
      print('Error launching app hibernation settings: $e');
      return false;
    }
  }

  /// Launch generic Android app settings
  static Future<bool> _launchGenericAppSettings() async {
    try {
      // Prefer native method channel to open app details with proper package URI
      if (Platform.isAndroid) {
        try {
          final bool opened = await _settingsChannel.invokeMethod<bool>('openAppDetailsSettings') ?? false;
          if (opened) return true;
        } catch (_) {}
      }

      // Fallback: generic intent (may not include package, so less reliable)
      final uri = Uri.parse('android.settings.APPLICATION_DETAILS_SETTINGS');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('Error launching generic app settings: $e');
      return false;
    }
  }

  /// Show app hibernation setup dialog
  static Future<void> showAppHibernationDialog(BuildContext context) async {
    final status = await getAppHibernationStatus();
    
    if (status.isAvailable) {
      // Clear any pending prompt flag when dialog is shown
      await clearPromptPending();
      showDialog(
        context: context,
        builder: (context) => AppHibernationDialog(
          status: status,
        ),
      );
    }
  }

  /// Get instructions for a specific manufacturer
  static Future<List<String>> getInstructions() async {
    final manufacturer = await _getDeviceManufacturer();
    return _getManufacturerInstructions(manufacturer);
  }

  /// Mark that we should auto-prompt the user about App Hibernation
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
}

/// App hibernation status information
class AppHibernationStatus {
  final bool isAvailable;
  final String manufacturer;
  final bool requiresAttention;
  final String? deepLink;
  final List<String>? instructions;

  AppHibernationStatus({
    required this.isAvailable,
    required this.manufacturer,
    required this.requiresAttention,
    this.deepLink,
    this.instructions,
  });
}

/// Dialog for showing app hibernation setup instructions
class AppHibernationDialog extends StatelessWidget {
  final AppHibernationStatus status;

  const AppHibernationDialog({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Disable App Hibernation'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Android\'s App Hibernation feature can automatically revoke permissions '
              'and stop background services for apps that haven\'t been used recently. '
              'For TRIminder to work properly, you need to disable this feature.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (status.instructions != null) ...[
              const Text(
                'Please follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...status.instructions!.map((instruction) => Padding(
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
        if (status.deepLink != null)
          ElevatedButton(
            onPressed: () async {
              await AppHibernationHelper.launchAppHibernationSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
      ],
    );
  }
}
