import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/app_usage_models.dart';

/// Service for interacting with Android UsageStatsManager via platform channel
class UsageStatsService {
  static const MethodChannel _channel = MethodChannel('usage_stats');
  
  static bool? _cachedPermissionStatus;
  static DateTime? _lastPermissionCheck;

  /// Check if USAGE_STATS permission is granted
  /// Caches result for 5 minutes to avoid repeated platform calls
  static Future<bool> isPermissionGranted() async {
    final now = DateTime.now();
    
    // Return cached result if still valid (5 minutes)
    if (_cachedPermissionStatus != null && 
        _lastPermissionCheck != null &&
        now.difference(_lastPermissionCheck!).inMinutes < 5) {
      return _cachedPermissionStatus!;
    }
    
    try {
      final granted = await _channel.invokeMethod<bool>('isUsageStatsPermissionGranted') ?? false;
      _cachedPermissionStatus = granted;
      _lastPermissionCheck = now;
      return granted;
    } catch (e) {
      print('Error checking UsageStats permission: $e');
      return false;
    }
  }

  /// Request USAGE_STATS permission (launches settings)
  /// Returns true if settings intent was launched successfully
  static Future<bool> requestPermission() async {
    try {
      final launched = await _channel.invokeMethod<bool>('requestUsageStatsPermission') ?? false;
      // Clear cache when requesting permission
      _cachedPermissionStatus = null;
      _lastPermissionCheck = null;
      return launched;
    } catch (e) {
      print('Error requesting UsageStats permission: $e');
      return false;
    }
  }

  /// Get currently running foreground app package name
  static Future<String?> getCurrentForegroundApp() async {
    if (!await isPermissionGranted()) return null;
    
    try {
      final packageName = await _channel.invokeMethod<String>('getCurrentForegroundApp');
      return packageName;
    } catch (e) {
      print('Error getting foreground app: $e');
      return null;
    }
  }

  /// Query UsageEvents for a time range
  /// Returns list of app usage events
  static Future<List<AppUsageEvent>> queryUsageEvents(DateTime start, DateTime end) async {
    if (!await isPermissionGranted()) return [];
    
    try {
      final result = await _channel.invokeMethod<String>(
        'queryUsageEvents',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      
      if (result == null) return [];
      
      final jsonArray = jsonDecode(result) as List;
      return jsonArray.map((e) => AppUsageEvent.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error querying usage events: $e');
      return [];
    }
  }

  /// Query aggregated usage stats for a time range
  static Future<Map<String, AppUsageStats>> queryUsageStats({
    required DateTime start,
    required DateTime end,
    int intervalType = 0, // INTERVAL_DAILY
  }) async {
    if (!await isPermissionGranted()) return {};
    
    try {
      final result = await _channel.invokeMethod<String>(
        'queryUsageStats',
        {
          'intervalType': intervalType,
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      
      if (result == null) return {};
      
      final jsonMap = jsonDecode(result) as Map<String, dynamic>;
      final statsMap = <String, AppUsageStats>{};
      
      jsonMap.forEach((packageName, value) {
        final statsJson = value as Map<String, dynamic>;
        statsMap[packageName] = AppUsageStats.fromJson(packageName, statsJson);
      });
      
      return statsMap;
    } catch (e) {
      print('Error querying usage stats: $e');
      return {};
    }
  }

  /// Get per-app usage for a specific date
  /// Returns map of packageName -> usageMinutes
  static Future<Map<String, int>> getAppUsageForDate(DateTime date) async {
    if (!await isPermissionGranted()) return {};
    
    try {
      // Get start of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final dateMillis = startOfDay.millisecondsSinceEpoch;
      
      final result = await _channel.invokeMethod<String>(
        'getAppUsageForDate',
        {'dateMillis': dateMillis},
      );
      
      if (result == null) return {};
      
      final jsonMap = jsonDecode(result) as Map<String, dynamic>;
      return jsonMap.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      print('Error getting app usage for date: $e');
      return {};
    }
  }

  /// Get app name from package name
  static Future<String> getAppName(String packageName) async {
    try {
      final appName = await _channel.invokeMethod<String>(
        'getAppName',
        {'packageName': packageName},
      );
      
      // Validate app name is not null, empty, or just the package name
      if (appName == null || appName.isEmpty || appName == packageName) {
        print('⚠️ App name retrieval returned invalid value for package: $packageName (got: $appName)');
        return packageName;
      }
      
      return appName;
    } on PlatformException catch (e) {
      print('❌ Platform error getting app name for $packageName: ${e.code} - ${e.message}');
      return packageName;
    } catch (e) {
      print('❌ Error getting app name for $packageName: $e');
      return packageName;
    }
  }

  /// Get app icon as base64 encoded PNG string
  /// Returns null if icon cannot be retrieved
  static Future<String?> getAppIconBase64(String packageName) async {
    try {
      final iconBase64 = await _channel.invokeMethod<String>(
        'getAppIconBase64',
        {'packageName': packageName},
      );
      
      if (iconBase64 == null || iconBase64.isEmpty) {
        print('⚠️ App icon retrieval returned null/empty for package: $packageName');
        return null;
      }
      
      return iconBase64;
    } on PlatformException catch (e) {
      print('❌ Platform error getting app icon for $packageName: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error getting app icon for $packageName: $e');
      return null;
    }
  }

  /// Clear cached permission status (call after user grants/denies permission)
  static void clearPermissionCache() {
    _cachedPermissionStatus = null;
    _lastPermissionCheck = null;
  }
  /// Get device unlock count for today
  /// Uses native platform channel to get actual unlock count from UsageStatsManager
  static Future<int> getTodayUnlockCount() async {
    if (!await isPermissionGranted()) return 0;
    
    try {
      final count = await _channel.invokeMethod<int>('getTodayUnlockCount');
      return count ?? 0;
    } catch (e) {
      print('Error getting unlock count: $e');
      return 0;
    }
  }
}

/// App usage statistics from UsageStatsManager
class AppUsageStats {
  final String packageName;
  final String appName;
  final int totalTimeInForeground; // milliseconds
  final int lastTimeUsed; // milliseconds since epoch

  AppUsageStats({
    required this.packageName,
    required this.appName,
    required this.totalTimeInForeground,
    required this.lastTimeUsed,
  });

  factory AppUsageStats.fromJson(String packageName, Map<String, dynamic> json) {
    return AppUsageStats(
      packageName: packageName,
      appName: json['appName'] as String? ?? packageName,
      totalTimeInForeground: json['totalTimeInForeground'] as int? ?? 0,
      lastTimeUsed: json['lastTimeUsed'] as int? ?? 0,
    );
  }

  /// Get usage time in minutes
  int get usageMinutes => (totalTimeInForeground / 60000).round();
}

