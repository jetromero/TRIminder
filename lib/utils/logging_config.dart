import 'package:flutter/foundation.dart';

/// Centralized logging configuration for the TRIminder app
/// Allows fine-grained control over logging levels
class LoggingConfig {
  // Production vs Debug configuration
  static const bool isProduction = kReleaseMode;
  static const bool isDebug = kDebugMode;

  // Service-specific logging controls
  static const bool enableSyncLogging = !isProduction; // Only in debug
  static const bool enableDatabaseLogging = false; // Very verbose, disabled by default
  static const bool enableAuthLogging = !isProduction; // Security-sensitive
  static const bool enableTimerLogging = false; // Very frequent, disabled
  static const bool enableUILogging = false; // High frequency, disabled
  static const bool enableDebugHelperLogging = !isProduction; // Debug only

  // Critical logging (always enabled)
  static const bool enableErrorLogging = true;
  static const bool enableWarningLogging = true;
  static const bool enableSuccessLogging = !isProduction;

  // Performance and metrics
  static const bool enablePerformanceLogging = !isProduction;
  static const bool enableMetricsLogging = !isProduction;

  // Network and connectivity
  static const bool enableNetworkLogging = !isProduction;

  /// Check if logging is enabled for a specific category
  static bool isEnabled(String category) {
    switch (category.toLowerCase()) {
      case 'sync':
        return enableSyncLogging;
      case 'database':
      case 'db':
        return enableDatabaseLogging;
      case 'auth':
      case 'authentication':
        return enableAuthLogging;
      case 'timer':
        return enableTimerLogging;
      case 'ui':
        return enableUILogging;
      case 'debug':
        return enableDebugHelperLogging;
      case 'error':
        return enableErrorLogging;
      case 'warning':
        return enableWarningLogging;
      case 'success':
        return enableSuccessLogging;
      case 'performance':
      case 'perf':
        return enablePerformanceLogging;
      case 'metrics':
        return enableMetricsLogging;
      case 'network':
        return enableNetworkLogging;
      default:
        return !isProduction; // Default to debug-only for unknown categories
    }
  }

  /// Get the current logging configuration summary
  static Map<String, bool> getConfig() {
    return {
      'isProduction': isProduction,
      'isDebug': isDebug,
      'sync': enableSyncLogging,
      'database': enableDatabaseLogging,
      'auth': enableAuthLogging,
      'timer': enableTimerLogging,
      'ui': enableUILogging,
      'debugHelper': enableDebugHelperLogging,
      'error': enableErrorLogging,
      'warning': enableWarningLogging,
      'success': enableSuccessLogging,
      'performance': enablePerformanceLogging,
      'metrics': enableMetricsLogging,
      'network': enableNetworkLogging,
    };
  }
}
