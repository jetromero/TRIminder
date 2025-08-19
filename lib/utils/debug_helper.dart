import '../services/database_service.dart';
import '../services/supabase_service.dart';
// Removed: import '../services/sync_service.dart'; - service no longer exists
import '../services/improved_sync_service.dart';
import '../services/user_session_manager.dart';
import '../services/persistent_tracker_service.dart';
import '../models/user_models.dart';

class DebugHelper {
  /// Add a test screen time entry for debugging
  static Future<void> addTestScreenTimeEntry() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        print('❌ No user ID for test entry');
        return;
      }

      final now = DateTime.now();
      final testEntry = ScreenTimeLog(
        id: now.millisecondsSinceEpoch,
        userId: userId,
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now,
        durationMinutes: 30,
        breakTaken: false,
        createdAt: now,
        isSynced: false,
      );

      final db = DatabaseService();
      await db.insertScreenTimeEntry(testEntry);
      print('✅ Test screen time entry added: 30 minutes for user $userId');
      
    } catch (e) {
      print('❌ Failed to add test entry: $e');
    }
  }

  /// Check database content
  static Future<void> checkDatabaseContent() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        print('❌ No user ID for database check');
        return;
      }

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final db = DatabaseService();
      final entries = await db.getScreenTimeEntriesForDateRange(
        userId, 
        startOfDay, 
        endOfDay
      );

      print('📊 Database check results:');
      print('  - User ID: $userId');
      print('  - Date range: $startOfDay to $endOfDay');
      print('  - Found ${entries.length} entries');
      
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        print('    Entry $i: ${entry.durationMinutes}m (${entry.userId}) at ${entry.startTime}');
      }
      
    } catch (e) {
      print('❌ Database check failed: $e');
    }
  }

  /// Check if user is properly authenticated
  static Future<void> checkAuthStatus() async {
    try {
      final supabaseService = SupabaseService();
      print('🔐 Auth Status Check:');
      print('  - Is authenticated: ${supabaseService.isAuthenticated}');
      print('  - Current user ID: ${supabaseService.currentUserId}');
      
      if (supabaseService.isAuthenticated) {
        final userId = supabaseService.currentUserId;
        if (userId != null) {
          final profile = await supabaseService.getUserProfile(userId);
          print('  - Profile loaded: ${profile?.fullName} (${profile?.email})');
        }
      }
      
    } catch (e) {
      print('❌ Auth check failed: $e');
    }
  }

  /// Check sync service status
  static Future<void> checkSyncStatus() async {
    try {
      final syncService = ImprovedSyncService();
      final stats = syncService.getSyncStats();
      
      print('🔄 Sync Status:');
      print('  - Is syncing: ${stats['isSyncing']}');
      print('  - Last sync: ${stats['lastSuccessfulSync']}');
      print('  - Sync attempts: ${stats['syncAttempts']}');
      print('  - Has errors: ${stats['hasErrors']}');
      print('  - Error count: ${stats['errorCount']}');
      
    } catch (e) {
      print('❌ Sync check failed: $e');
    }
  }

  /// Check user session status
  static Future<void> checkSessionStatus() async {
    try {
      print('\n=== USER SESSION DEBUG ===');
      
      final sessionManager = UserSessionManager();
      final sessionInfo = sessionManager.getSessionInfo();
      
      print('Session Info:');
      sessionInfo.forEach((key, value) {
        print('  $key: $value');
      });
      
      print('Session Valid: ${sessionManager.validateSession()}');
      
      print('=== END SESSION DEBUG ===\n');
    } catch (e) {
      print('❌ Error checking session status: $e');
    }
  }

  /// Clear all local data (for testing account switching)
  static Future<void> clearAllLocalData() async {
    try {
      print('\n=== CLEARING LOCAL DATA ===');
      
      await UserSessionManager().clearAllLocalData();
      
      print('✅ All local data cleared');
      print('=== END CLEAR DATA ===\n');
    } catch (e) {
      print('❌ Error clearing local data: $e');
    }
  }

  /// Reset user session (for testing)
  static Future<void> resetUserSession() async {
    try {
      print('\n=== RESETTING USER SESSION ===');
      
      await UserSessionManager().resetSession();
      
      print('✅ User session reset');
      print('=== END SESSION RESET ===\n');
    } catch (e) {
      print('❌ Error resetting session: $e');
    }
  }

  /// Test screen time tracking and database storage
  static Future<void> testScreenTimeTracking() async {
    try {
      print('\n=== SCREEN TIME TRACKING TEST ===');
      
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        print('❌ No authenticated user');
        return;
      }
      
      print('👤 User ID: $userId');
      
      // Check background service status
      final isServiceRunning = await PersistentTrackerService.isRunning();
      print('🔄 Background service running: ${isServiceRunning ? "✅" : "❌"}');
      
      if (!isServiceRunning) {
        print('⚠️ Starting background service...');
        await PersistentTrackerService.startService();
        await Future.delayed(const Duration(seconds: 2));
        final isNowRunning = await PersistentTrackerService.isRunning();
        print('   Service now running: ${isNowRunning ? "✅" : "❌"}');
      }
      
      // Check recent screen time entries
      final db = DatabaseService();
      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));
      
      final recentEntries = await db.getScreenTimeEntriesForDateRange(
        userId,
        lastHour,
        now,
      );
      
      print('📊 Recent entries (last hour): ${recentEntries.length}');
      
      // Always check sync status of ALL entries
      final allTimeEntries = await db.getScreenTimeEntriesForDateRange(
        userId,
        now.subtract(const Duration(days: 1)),
        now,
      );
      print('📅 Entries in last 24 hours: ${allTimeEntries.length}');
      
      if (allTimeEntries.isNotEmpty) {
        int syncedCount = 0;
        int unsyncedCount = 0;
        
        print('📝 Entry sync status:');
        for (final entry in allTimeEntries.take(10)) {
          final timeStr = '${entry.startTime.hour}:${entry.startTime.minute.toString().padLeft(2, '0')}';
          final syncStatus = entry.isSynced ? "✅" : "❌";
          print('   - ${entry.durationMinutes}m at $timeStr (synced: $syncStatus) ID: ${entry.id}');
          
          if (entry.isSynced) {
            syncedCount++;
          } else {
            unsyncedCount++;
          }
        }
        
        print('📊 Sync Summary: $syncedCount synced, $unsyncedCount unsynced');
        
        // Check unsynced specifically
        final unsyncedEntries = await db.getUnsyncedScreenTimeLogs();
        print('🔍 Unsynced entries query result: ${unsyncedEntries.length}');
      } else {
        print('⚠️ No entries found in last 24 hours');
      }
      
      print('=== END TRACKING TEST ===\n');
    } catch (e) {
      print('❌ Screen time tracking test failed: $e');
    }
  }

  /// Save current session manually (workaround for screen_state issues)
  static Future<void> saveCurrentSessionManually() async {
    try {
      print('\n=== MANUAL SESSION SAVE ===');
      
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        print('❌ No authenticated user found');
        return;
      }

      // Create a session for the last few minutes
      final now = DateTime.now();
      final sessionStart = now.subtract(const Duration(minutes: 3)); // Assume 3-minute session
      final uniqueId = now.microsecondsSinceEpoch;
      
      final sessionEntry = ScreenTimeLog(
        id: uniqueId,
        userId: userId,
        startTime: sessionStart,
        endTime: now,
        durationMinutes: 3,
        breakTaken: false,
        createdAt: now,
        isSynced: false,
      );

      final db = DatabaseService();
      await db.insertScreenTimeEntry(sessionEntry);
      
      print('✅ Manual session saved: 3 minutes for user $userId');
      print('💡 This simulates what should happen when screen turns OFF');
      
      // Trigger sync
      final syncService = ImprovedSyncService();
      final synced = await syncService.performSync();
      print('🔄 Sync result: ${synced ? "✅ Success" : "❌ Failed"}');
      
      print('=== END MANUAL SAVE ===\n');
      
    } catch (e) {
      print('❌ Manual session save failed: $e');
    }
  }

  /// Test background service status and screen event detection
  static Future<void> testBackgroundService() async {
    try {
      print('\n=== BACKGROUND SERVICE TEST ===');
      
      // Check if background service is running
      final isRunning = await PersistentTrackerService.isRunning();
      print('🔄 Background service running: ${isRunning ? "✅" : "❌"}');
      
      if (!isRunning) {
        print('⚠️ Starting background service...');
        final started = await PersistentTrackerService.startService();
        print('   Service start result: ${started ? "✅" : "❌"}');
      }
      
      print('');
      print('📱 SCREEN EVENT DETECTION TEST:');
      print('   1. Watch the console for these messages:');
      print('      - "📱 Screen ON at ..."');
      print('      - "📱 Screen OFF - Session: ...m"');
      print('   2. Turn your screen OFF for 10+ seconds');
      print('   3. Turn your screen back ON');
      print('   4. Check console for screen event logs');
      print('');
      print('⚠️ If you DON\'T see screen event messages, the screen_state');
      print('   package may not be working on your device.');
      print('');
      print('💡 Alternative: Use "Add Test" button to create manual entries');
      print('   and "Test Sync" to verify sync works');
      print('=== END BACKGROUND SERVICE TEST ===\n');
      
    } catch (e) {
      print('❌ Background service test failed: $e');
    }
  }

  /// Test bidirectional sync (download + upload)
  static Future<void> testBidirectionalSync() async {
    try {
      print('\n=== BIDIRECTIONAL SYNC TEST (OLD) ===');
      
      // 1. Check authentication
      final supabaseService = SupabaseService();
      print('1. Auth check:');
      print('   - Authenticated: ${supabaseService.isAuthenticated}');
      print('   - User ID: ${supabaseService.currentUserId}');
      
      if (!supabaseService.isAuthenticated) {
        print('❌ Not authenticated - cannot sync');
        return;
      }
      
      // 2. Show local data before sync
      final db = DatabaseService();
      final userId = supabaseService.currentUserId!;
      final localEntries = await db.getScreenTimeEntriesForDateRange(
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now().add(const Duration(days: 1)),
      );
      print('2. Local data (before sync):');
      print('   - Local entries: ${localEntries.length}');
      
      // 3. Show cloud data before sync
      final cloudEntries = await supabaseService.getScreenTimeLogs(userId);
      print('3. Cloud data (before sync):');
      print('   - Cloud entries: ${cloudEntries.length}');
      
      // 4. Perform bidirectional sync (initial login style)
      print('4. Performing bidirectional sync (login sync)...');
      final syncService = ImprovedSyncService();
      final success = await syncService.performSync(showProgress: true, isInitialLogin: true);
      print('   - Sync result: ${success ? "✅ Success" : "❌ Failed"}');
      
      // 5. Show results after sync
      final localEntriesAfter = await db.getScreenTimeEntriesForDateRange(
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now().add(const Duration(days: 1)),
      );
      final cloudEntriesAfter = await supabaseService.getScreenTimeLogs(userId);
      
      print('5. Results after sync:');
      print('   - Local entries: ${localEntriesAfter.length} (was ${localEntries.length})');
      print('   - Cloud entries: ${cloudEntriesAfter.length} (was ${cloudEntries.length})');
      print('   - New local entries: ${localEntriesAfter.length - localEntries.length}');
      print('   - New cloud entries: ${cloudEntriesAfter.length - cloudEntries.length}');
      
      print('=== END OLD BIDIRECTIONAL SYNC TEST ===\n');
      
    } catch (e) {
      print('❌ Bidirectional sync test failed: $e');
    }
  }

  /// Test the new improved sync service
  static Future<void> testImprovedSync() async {
    try {
      print('\n=== IMPROVED SYNC TEST ===');
      
      // 1. Check authentication
      final supabaseService = SupabaseService();
      print('1. Auth check:');
      print('   - Authenticated: ${supabaseService.isAuthenticated}');
      print('   - User ID: ${supabaseService.currentUserId}');
      
      if (!supabaseService.isAuthenticated) {
        print('❌ Not authenticated - cannot sync');
        return;
      }
      
      // 2. Show sync metadata
      final db = DatabaseService();
      final lastSync = await db.getLastSyncTimestamp();
      final lastCloudSync = await db.getLastCloudSyncTimestamp();
      print('2. Sync metadata:');
      print('   - Last sync: ${lastSync?.toIso8601String() ?? "Never"}');
      print('   - Last cloud sync: ${lastCloudSync?.toIso8601String() ?? "Never"}');
      
      // 3. Show local data before sync
      final userId = supabaseService.currentUserId!;
      final localEntries = await db.getScreenTimeEntriesForDateRange(
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now().add(const Duration(days: 1)),
      );
      final unsyncedEntries = await db.getUnsyncedScreenTimeLogs();
      print('3. Local data (before sync):');
      print('   - Total local entries: ${localEntries.length}');
      print('   - Unsynced entries: ${unsyncedEntries.length}');
      
      // 4. Show cloud data before sync
      final cloudEntries = await supabaseService.getScreenTimeLogs(userId);
      print('4. Cloud data (before sync):');
      print('   - Cloud entries: ${cloudEntries.length}');
      
      // 5. Perform improved sync (initial login style)
      print('5. Performing IMPROVED sync (smart initial login)...');
      final improvedSyncService = ImprovedSyncService();
      final success = await improvedSyncService.performSync(showProgress: true, isInitialLogin: true);
      print('   - Sync result: ${success ? "✅ Success" : "❌ Failed"}');
      
      // 6. Show results after sync
      final localEntriesAfter = await db.getScreenTimeEntriesForDateRange(
        userId,
        DateTime.now().subtract(const Duration(days: 7)),
        DateTime.now().add(const Duration(days: 1)),
      );
      final cloudEntriesAfter = await supabaseService.getScreenTimeLogs(userId);
      final unsyncedEntriesAfter = await db.getUnsyncedScreenTimeLogs();
      
      print('6. Results after improved sync:');
      print('   - Local entries: ${localEntriesAfter.length} (was ${localEntries.length})');
      print('   - Cloud entries: ${cloudEntriesAfter.length} (was ${cloudEntries.length})');
      print('   - Unsynced entries: ${unsyncedEntriesAfter.length} (was ${unsyncedEntries.length})');
      print('   - Network efficiency: Only downloaded changes since last sync');
      
      // 7. Show updated sync metadata
      final lastSyncAfter = await db.getLastSyncTimestamp();
      final lastCloudSyncAfter = await db.getLastCloudSyncTimestamp();
      print('7. Updated sync metadata:');
      print('   - Last sync: ${lastSyncAfter?.toIso8601String() ?? "Still null"}');
      print('   - Last cloud sync: ${lastCloudSyncAfter?.toIso8601String() ?? "Still null"}');
      
      // 8. Get sync stats
      final syncStats = improvedSyncService.getSyncStats();
      print('8. Sync statistics:');
      syncStats.forEach((key, value) {
        print('   - $key: $value');
      });
      
      print('=== END IMPROVED SYNC TEST ===\n');
      
    } catch (e) {
      print('❌ Improved sync test failed: $e');
    }
  }

  /// Compare both sync methods side by side
  static Future<void> compareSyncMethods() async {
    try {
      print('\n=== SYNC METHOD COMPARISON ===');
      
      final supabaseService = SupabaseService();
      if (!supabaseService.isAuthenticated) {
        print('❌ Not authenticated - cannot compare');
        return;
      }

      print('🔄 Testing OLD sync method...');
      final startTime1 = DateTime.now();
      final oldSyncService = ImprovedSyncService();
      final oldSuccess = await oldSyncService.performSync(showProgress: false, isInitialLogin: true);
      final oldDuration = DateTime.now().difference(startTime1);
      
      print('⏳ Waiting 2 seconds...');
      await Future.delayed(const Duration(seconds: 2));
      
      print('🚀 Testing IMPROVED sync method...');
      final startTime2 = DateTime.now();
      final improvedSyncService = ImprovedSyncService();
      final improvedSuccess = await improvedSyncService.performSync(showProgress: false, isInitialLogin: true);
      final improvedDuration = DateTime.now().difference(startTime2);
      
      print('\n📊 COMPARISON RESULTS:');
      print('┌─────────────────────┬─────────────┬─────────────────┐');
      print('│ Method              │ Success     │ Duration        │');
      print('├─────────────────────┼─────────────┼─────────────────┤');
      print('│ Old Sync            │ ${oldSuccess ? "✅ Success" : "❌ Failed"} │ ${oldDuration.inMilliseconds}ms       │');
      print('│ Improved Sync       │ ${improvedSuccess ? "✅ Success" : "❌ Failed"} │ ${improvedDuration.inMilliseconds}ms       │');
      print('└─────────────────────┴─────────────┴─────────────────┘');
      
      if (oldDuration.inMilliseconds > 0 && improvedDuration.inMilliseconds > 0) {
        final speedup = oldDuration.inMilliseconds / improvedDuration.inMilliseconds;
        print('🚀 Improved sync is ${speedup.toStringAsFixed(1)}x faster!');
      }
      
      print('=== END COMPARISON ===\n');
      
    } catch (e) {
      print('❌ Sync comparison failed: $e');
    }
  }

  /// Test sync process step by step (legacy test)
  static Future<void> testSyncProcess() async {
    try {
      print('\n=== SYNC PROCESS TEST ===');
      
      // 1. Check authentication
      final supabaseService = SupabaseService();
      print('1. Auth check:');
      print('   - Authenticated: ${supabaseService.isAuthenticated}');
      print('   - User ID: ${supabaseService.currentUserId}');
      
      if (!supabaseService.isAuthenticated) {
        print('❌ Not authenticated - cannot sync');
        return;
      }
      
      // 2. Check local unsynced data
      final db = DatabaseService();
      final unsyncedEntries = await db.getUnsyncedScreenTimeLogs();
      print('2. Local data:');
      print('   - Unsynced entries: ${unsyncedEntries.length}');
      
      if (unsyncedEntries.isEmpty) {
        print('⚠️ No unsynced data found');
        
        // Show recent entries to verify data exists
        final userId = supabaseService.currentUserId!;
        final recentEntries = await db.getScreenTimeEntriesForDateRange(
          userId,
          DateTime.now().subtract(const Duration(hours: 2)),
          DateTime.now(),
        );
        print('   - Recent entries (last 2h): ${recentEntries.length}');
        for (final entry in recentEntries) {
          print('     * ${entry.durationMinutes}m at ${entry.startTime.hour}:${entry.startTime.minute.toString().padLeft(2, '0')} (synced: ${entry.isSynced})');
        }
      } else {
        print('   - Unsynced entries details:');
        for (final entry in unsyncedEntries.take(3)) {
          print('     * ${entry.durationMinutes}m at ${entry.startTime.hour}:${entry.startTime.minute.toString().padLeft(2, '0')} (ID: ${entry.id})');
        }
      }
      
      // 3. Test network connectivity
      print('3. Network test:');
      try {
        final isConnected = await supabaseService.isConnected();
        print('   - Supabase connection: ${isConnected ? "✅" : "❌"}');
      } catch (e) {
        print('   - Connection test failed: $e');
      }
      
      // 4. Attempt sync
      print('4. Sync attempt:');
      final syncService = ImprovedSyncService();
      final syncResult = await syncService.performSync(showProgress: true);
      print('   - Sync result: ${syncResult ? "✅ Success" : "❌ Failed"}');
      
      // 5. Check sync stats
      final syncStats = syncService.getSyncStats();
      print('5. Sync stats:');
      syncStats.forEach((key, value) {
        print('   - $key: $value');
      });
      
      print('=== END SYNC TEST ===\n');
    } catch (e) {
      print('❌ Sync test failed: $e');
    }
  }
}
