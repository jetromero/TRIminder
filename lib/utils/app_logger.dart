import 'package:flutter/foundation.dart';
import 'logging_config.dart';

/// Smart logging system for TRIminder app
/// Provides different log levels and can be controlled for production vs debug
class AppLogger {
  static const bool _enableDebugLogs = kDebugMode; // Only in debug mode
  static const bool _enableInfoLogs = true; // Always enabled
  static const bool _enableWarningLogs = true; // Always enabled
  static const bool _enableErrorLogs = true; // Always enabled

  // Log level emojis for better visual scanning
  static const String _debugEmoji = '🔍';
  static const String _infoEmoji = 'ℹ️';
  static const String _successEmoji = '✅';
  static const String _warningEmoji = '⚠️';
  static const String _errorEmoji = '❌';
  static const String _syncEmoji = '🔄';
  static const String _dbEmoji = '💾';
  static const String _authEmoji = '🔐';
  static const String _timerEmoji = '⏰';

  /// Debug logs - only shown in debug mode
  static void debug(String message, [String? context]) {
    if (_enableDebugLogs) {
      final contextStr = context != null ? '[$context] ' : '';
      print('$_debugEmoji DEBUG: $contextStr$message');
    }
  }

  /// Info logs - general information
  static void info(String message, [String? context]) {
    if (_enableInfoLogs) {
      final contextStr = context != null ? '[$context] ' : '';
      print('$_infoEmoji INFO: $contextStr$message');
    }
  }

  /// Success logs - positive outcomes
  static void success(String message, [String? context]) {
    if (_enableInfoLogs) {
      final contextStr = context != null ? '[$context] ' : '';
      print('$_successEmoji SUCCESS: $contextStr$message');
    }
  }

  /// Warning logs - potential issues
  static void warning(String message, [String? context, Object? error]) {
    if (_enableWarningLogs) {
      final contextStr = context != null ? '[$context] ' : '';
      final errorStr = error != null ? ' - Error: $error' : '';
      print('$_warningEmoji WARNING: $contextStr$message$errorStr');
    }
  }

  /// Error logs - critical issues
  static void error(String message, [String? context, Object? error]) {
    if (_enableErrorLogs) {
      final contextStr = context != null ? '[$context] ' : '';
      final errorStr = error != null ? ' - Error: $error' : '';
      print('$_errorEmoji ERROR: $contextStr$message$errorStr');
    }
  }

  /// Sync-specific logs
  static void sync(String message, [String? operation]) {
    if (LoggingConfig.isEnabled('sync')) {
      final opStr = operation != null ? '[$operation] ' : '';
      print('$_syncEmoji SYNC: $opStr$message');
    }
  }

  /// Database-specific logs
  static void database(String message, [String? operation]) {
    if (LoggingConfig.isEnabled('database')) {
      final opStr = operation != null ? '[$operation] ' : '';
      print('$_dbEmoji DB: $opStr$message');
    }
  }

  /// Authentication-specific logs
  static void auth(String message, [String? operation]) {
    if (LoggingConfig.isEnabled('auth')) {
      final opStr = operation != null ? '[$operation] ' : '';
      print('$_authEmoji AUTH: $opStr$message');
    }
  }

  /// Timer-specific logs
  static void timer(String message, [String? operation]) {
    if (LoggingConfig.isEnabled('timer')) {
      final opStr = operation != null ? '[$operation] ' : '';
      print('$_timerEmoji TIMER: $opStr$message');
    }
  }

  /// Performance measurement
  static void performance(String operation, Duration duration) {
    if (_enableDebugLogs) {
      print('⚡ PERF: $operation took ${duration.inMilliseconds}ms');
    }
  }

  /// Log method calls (for debugging complex flows)
  static void method(String className, String methodName, [String? params]) {
    if (_enableDebugLogs) {
      final paramStr = params != null ? '($params)' : '()';
      print('🔧 METHOD: $className.$methodName$paramStr');
    }
  }

  /// Conditional logging based on condition
  static void conditional(bool condition, String message, [String? context]) {
    if (condition && _enableDebugLogs) {
      debug(message, context);
    }
  }

  /// Log statistics and metrics
  static void metric(String name, dynamic value, [String? unit]) {
    if (_enableDebugLogs) {
      final unitStr = unit != null ? ' $unit' : '';
      print('📊 METRIC: $name = $value$unitStr');
    }
  }

  /// Batch logging for related operations
  static void batch(String operation, List<String> messages) {
    if (_enableDebugLogs && messages.isNotEmpty) {
      print('📦 BATCH [$operation]:');
      for (int i = 0; i < messages.length; i++) {
        print('   ${i + 1}. ${messages[i]}');
      }
    }
  }

  /// Log app lifecycle events
  static void lifecycle(String event, [String? details]) {
    if (_enableInfoLogs) {
      final detailStr = details != null ? ' - $details' : '';
      print('🔄 LIFECYCLE: $event$detailStr');
    }
  }

  /// Enable/disable logging dynamically (for testing)
  static const Map<String, bool> _logLevels = {
    'debug': _enableDebugLogs,
    'info': _enableInfoLogs,
    'warning': _enableWarningLogs,
    'error': _enableErrorLogs,
  };

  static Map<String, bool> get logLevels => _logLevels;
}
