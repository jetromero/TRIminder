import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    final permissions = [
      Permission.notification,
      Permission.systemAlertWindow,
      Permission.phone,
    ];

    // Request basic permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Log permission results
    statuses.forEach((permission, status) {
      print('   ${permission.toString().split('.').last}: $status');
    });

    // Request battery optimization bypass
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus != PermissionStatus.granted) {
        print('🔋 Requesting battery optimization bypass...');
        final batteryResult = await Permission.ignoreBatteryOptimizations.request();
        print('   Battery optimization: $batteryResult');
      } else {
        print('✅ Battery optimization already bypassed');
      }
    } catch (e) {
      print('⚠️ Could not request battery optimization: $e');
    }
  }

  /// Configure background settings
  static Future<void> _configureBackgroundSettings() async {
    print('⚙️ Configuring background settings...');

    // Check if we can request battery optimization bypass
    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (batteryStatus == PermissionStatus.granted) {
        print('✅ Battery optimization bypassed - background service will run continuously');
        await markBackgroundConfigured();
      } else {
        print('⚠️ Battery optimization not bypassed - user may need to manually configure');
        print('💡 Guide user to: Settings → Apps → TRIminder → Battery → "Run in Background"');
      }
    } catch (e) {
      print('⚠️ Could not check battery optimization status: $e');
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
    
    // Check permissions
    final notificationStatus = await Permission.notification.status;
    final systemAlertStatus = await Permission.systemAlertWindow.status;
    final phoneStatus = await Permission.phone.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    results['permissions'] = {
      'notification': notificationStatus == PermissionStatus.granted,
      'systemAlert': systemAlertStatus == PermissionStatus.granted,
      'phone': phoneStatus == PermissionStatus.granted,
      'batteryOptimization': batteryStatus == PermissionStatus.granted,
    };

    // Check if all permissions are granted
    results['allPermissionsGranted'] = results['permissions'].values.every((granted) => granted == true);
    
    // Check if background is configured
    results['backgroundConfigured'] = batteryStatus == PermissionStatus.granted; // Simplified check

    return results;
  }
}
