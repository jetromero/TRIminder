import 'simplified_logger.dart';

/// Test script to demonstrate the new simplified logging
/// Run this to see the difference in log output
void testSimplifiedLogging() {
  print('=== Testing Simplified Logging ===\n');
  
  // Test all log categories
  SimplifiedLogger.info('This is essential information');
  SimplifiedLogger.warning('This is a warning message');
  SimplifiedLogger.error('This is an error message');
  SimplifiedLogger.success('This is a success message');
  SimplifiedLogger.debug('This is debug information (only shown when debug enabled)');
  SimplifiedLogger.verbose('This is verbose debug information (only shown when verbose enabled)');
  SimplifiedLogger.screenTime('Screen time update: 2h 15m');
  SimplifiedLogger.sync('Sync operation completed');
  SimplifiedLogger.session('Active session: 45m');
  SimplifiedLogger.user('User authenticated successfully');
  SimplifiedLogger.database('Database operation completed');
  SimplifiedLogger.service('Background service started');
  SimplifiedLogger.xp('XP awarded: +50 points');
  SimplifiedLogger.critical('Critical system error occurred');
  
  print('\n=== End of Test ===');
  print('Notice how each log has a clear category and icon!');
  print('Debug and verbose logs are controlled by the flags in SimplifiedLogger.');
}

/// Example of how to use the logger in your services
void exampleUsage() {
  // Instead of: print('🔄 AutomaticScreenTracker: refreshTodayData() called');
  SimplifiedLogger.verbose('refreshTodayData() called');
  
  // Instead of: print('📱 Found active session via background service: 1m');
  SimplifiedLogger.session('Active session: 1m');
  
  // Instead of: print('❌ Error syncing session from background service: $e');
  SimplifiedLogger.error('Error syncing session from background service: example error');
  
  // Instead of: print('✅ User XP updated online: +50 (Total: 150)');
  SimplifiedLogger.xp('User XP updated online: +50 (Total: 150)');
}
