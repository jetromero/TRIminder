import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Helper class for detecting device information and manufacturer-specific features
class DeviceInfoHelper {
  static DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static Map<String, dynamic>? _cachedDeviceInfo;

  /// Get comprehensive device information
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _cachedDeviceInfo = {
          'platform': 'Android',
          'manufacturer': androidInfo.manufacturer.toLowerCase(),
          'brand': androidInfo.brand.toLowerCase(),
          'model': androidInfo.model,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'product': androidInfo.product,
          'device': androidInfo.device,
          'board': androidInfo.board,
          'hardware': androidInfo.hardware,
          'host': androidInfo.host,
          'tags': androidInfo.tags,
          'type': androidInfo.type,
          'display': androidInfo.display,
          'fingerprint': androidInfo.fingerprint,
          'id': androidInfo.id,
          'supported32BitAbis': androidInfo.supported32BitAbis,
          'supported64BitAbis': androidInfo.supported64BitAbis,
          'supportedAbis': androidInfo.supportedAbis,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _cachedDeviceInfo = {
          'platform': 'iOS',
          'manufacturer': 'apple',
          'brand': 'apple',
          'model': iosInfo.model,
          'iosVersion': iosInfo.systemVersion,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'localizedModel': iosInfo.localizedModel,
          'identifierForVendor': iosInfo.identifierForVendor,
        };
      } else {
        _cachedDeviceInfo = {
          'platform': 'Unknown',
          'manufacturer': 'unknown',
          'brand': 'unknown',
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
      _cachedDeviceInfo = {
        'platform': 'Unknown',
        'manufacturer': 'unknown',
        'brand': 'unknown',
        'error': e.toString(),
      };
    }

    return _cachedDeviceInfo!;
  }

  /// Get device manufacturer
  static Future<String> getManufacturer() async {
    final deviceInfo = await getDeviceInfo();
    return deviceInfo['manufacturer'] ?? 'unknown';
  }

  /// Get device brand
  static Future<String> getBrand() async {
    final deviceInfo = await getDeviceInfo();
    return deviceInfo['brand'] ?? 'unknown';
  }

  /// Get Android version
  static Future<String> getAndroidVersion() async {
    final deviceInfo = await getDeviceInfo();
    return deviceInfo['androidVersion'] ?? 'unknown';
  }

  /// Get Android SDK version
  static Future<int> getAndroidSdkInt() async {
    final deviceInfo = await getDeviceInfo();
    return deviceInfo['sdkInt'] ?? 0;
  }

  /// Check if device is a specific manufacturer
  static Future<bool> isManufacturer(String manufacturer) async {
    final deviceManufacturer = await getManufacturer();
    final deviceBrand = await getBrand();
    
    return deviceManufacturer.contains(manufacturer.toLowerCase()) ||
           deviceBrand.contains(manufacturer.toLowerCase());
  }

  /// Check if device is Tecno
  static Future<bool> isTecno() async {
    return await isManufacturer('tecno') || 
           await isManufacturer('transsion');
  }

  /// Check if device is Xiaomi
  static Future<bool> isXiaomi() async {
    return await isManufacturer('xiaomi') || 
           await isManufacturer('redmi');
  }

  /// Check if device is Huawei
  static Future<bool> isHuawei() async {
    return await isManufacturer('huawei') || 
           await isManufacturer('honor');
  }

  /// Check if device is Samsung
  static Future<bool> isSamsung() async {
    return await isManufacturer('samsung');
  }

  /// Check if device is Oppo
  static Future<bool> isOppo() async {
    return await isManufacturer('oppo') || 
           await isManufacturer('realme') ||
           await isManufacturer('oneplus');
  }

  /// Check if device is Vivo
  static Future<bool> isVivo() async {
    return await isManufacturer('vivo');
  }

  /// Get device-specific information for debugging
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final deviceInfo = await getDeviceInfo();
    
    return {
      'manufacturer': deviceInfo['manufacturer'],
      'brand': deviceInfo['brand'],
      'model': deviceInfo['model'],
      'androidVersion': deviceInfo['androidVersion'],
      'sdkInt': deviceInfo['sdkInt'],
      'isPhysicalDevice': deviceInfo['isPhysicalDevice'],
      'platform': deviceInfo['platform'],
      'isTecno': await isTecno(),
      'isXiaomi': await isXiaomi(),
      'isHuawei': await isHuawei(),
      'isSamsung': await isSamsung(),
      'isOppo': await isOppo(),
      'isVivo': await isVivo(),
    };
  }

  /// Get device capabilities for feature detection
  static Future<Map<String, bool>> getDeviceCapabilities() async {
    final sdkInt = await getAndroidSdkInt();
    
    return {
      'supportsNotificationChannels': sdkInt >= 26, // Android 8.0
      'supportsBackgroundRestrictions': sdkInt >= 26, // Android 8.0
      'supportsExactAlarms': sdkInt >= 31, // Android 12
      'supportsNotificationPermission': sdkInt >= 33, // Android 13
      'supportsForegroundServiceTypes': sdkInt >= 34, // Android 14
      'supportsBatteryOptimization': sdkInt >= 23, // Android 6.0
      'supportsAutoStart': sdkInt >= 26, // Android 8.0
      'isAndroid15': sdkInt >= 35, // Android 15
      'requiresForegroundServiceType': sdkInt >= 34, // Android 14+
      'hasStrictBackgroundRestrictions': sdkInt >= 30, // Android 11+
    };
  }

  /// Check if device has aggressive battery management
  static Future<bool> hasAggressiveBatteryManagement() async {
    if (await isTecno()) return true;
    if (await isXiaomi()) return true;
    if (await isHuawei()) return true;
    if (await isOppo()) return true;
    if (await isVivo()) return true;
    return false;
  }

  /// Get manufacturer-specific settings app package
  static Future<String?> getSettingsPackage() async {
    if (await isTecno()) return 'com.tecno.phonemaster';
    if (await isXiaomi()) return 'com.miui.securitycenter';
    if (await isHuawei()) return 'com.huawei.systemmanager';
    if (await isSamsung()) return 'com.samsung.android.lool';
    if (await isOppo()) return 'com.coloros.safecenter';
    if (await isVivo()) return 'com.vivo.safecenter';
    return null;
  }

  /// Get device-specific battery optimization settings path
  static Future<String> getBatteryOptimizationPath() async {
    if (await isTecno()) {
      return 'Settings → Phone Master → Auto-start → TRIminder → Enable';
    }
    if (await isXiaomi()) {
      return 'Settings → Apps → Manage apps → TRIminder → Battery saver → No restrictions';
    }
    if (await isHuawei()) {
      return 'Settings → Apps → Apps → TRIminder → Battery → Allow background activity';
    }
    if (await isSamsung()) {
      return 'Settings → Device care → Battery → App power management → TRIminder → Unrestricted';
    }
    if (await isOppo()) {
      return 'Settings → Apps → App management → TRIminder → Battery → Allow background activity';
    }
    if (await isVivo()) {
      return 'Settings → Apps → App management → TRIminder → Battery → Allow background activity';
    }
    return 'Settings → Apps → TRIminder → Battery → Allow background activity';
  }

  /// Clear cached device info (useful for testing)
  static void clearCache() {
    _cachedDeviceInfo = null;
  }
}
