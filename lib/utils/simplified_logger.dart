
/// Simplified logging utility for TRIminder
/// Reduces log noise while keeping essential information
class SimplifiedLogger {
  static const bool _enableDebugLogs = false; // Set to true for debugging
  static const bool _enableVerboseLogs = false; // Set to true for verbose debugging
  
  /// Log essential information only
  static void info(String message) {
    print('ℹ️ $message');
  }
  
  /// Log warnings and errors
  static void warning(String message) {
    print('⚠️ $message');
  }
  
  /// Log errors
  static void error(String message) {
    print('❌ $message');
  }
  
  /// Log success messages
  static void success(String message) {
    print('✅ $message');
  }
  
  /// Log debug information (only when debug is enabled)
  static void debug(String message) {
    if (_enableDebugLogs) {
      print('🔍 $message');
    }
  }
  
  /// Log verbose debug information (only when verbose is enabled)
  static void verbose(String message) {
    if (_enableVerboseLogs) {
      print('🔍 $message');
    }
  }
  
  /// Log screen time updates (essential for tracking)
  static void screenTime(String message) {
    print('📱 $message');
  }
  
  /// Log sync operations (essential for data integrity)
  static void sync(String message) {
    print('🔄 $message');
  }
  
  /// Log session information (essential for tracking)
  static void session(String message) {
    print('⏰ $message');
  }
  
  /// Log user operations (essential for user management)
  static void user(String message) {
    print('👤 $message');
  }
  
  /// Log database operations (essential for data persistence)
  static void database(String message) {
    print('💾 $message');
  }
  
  /// Log service operations (essential for background services)
  static void service(String message) {
    print('🚀 $message');
  }
  
  /// Log XP and level operations (essential for gamification)
  static void xp(String message) {
    print('⭐ $message');
  }
  
  /// Log only the most critical information
  static void critical(String message) {
    print('🚨 $message');
  }
  
  /// Enable/disable debug logging at runtime
  static void setDebugEnabled(bool enabled) {
    // This would require making _enableDebugLogs non-const
    // For now, just use the static const value
  }
  
  /// Enable/disable verbose logging at runtime
  static void setVerboseEnabled(bool enabled) {
    // This would require making _enableVerboseLogs non-const
    // For now, just use the static const value
  }
}
