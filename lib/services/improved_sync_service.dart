import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../models/user_models.dart';
import '../utils/app_logger.dart';
import 'background_supabase_client.dart';

/// Improved sync service with incremental timestamp-based synchronization
/// Much more efficient than downloading all data on every login
class ImprovedSyncService extends ChangeNotifier {
  static final ImprovedSyncService _instance = ImprovedSyncService._internal();
  factory ImprovedSyncService() => _instance;
  ImprovedSyncService._internal();

  // Sync state
  bool _isSyncing = false;
  Timer? _periodicSyncTimer;
  DateTime? _lastSuccessfulSync;
  DateTime? _lastCloudSync; // Tracks when we last downloaded from cloud
  int _syncAttempts = 0;
  List<String> _syncErrors = [];

  // Sync completion callback
  Function()? _onSyncComplete;

  // Sync configuration
  static Duration _syncInterval = Duration(minutes: 2);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(seconds: 5);
  static const Duration _initialSyncRange = Duration(days: 7); // Only download last week on first login
  
  /// Set custom sync interval (for runtime configuration)
  static void setSyncInterval(Duration interval) {
    _syncInterval = interval;
  }

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSuccessfulSync => _lastSuccessfulSync;
  DateTime? get lastCloudSync => _lastCloudSync;
  int get syncAttempts => _syncAttempts;
  List<String> get syncErrors => List.unmodifiable(_syncErrors);

  /// Set callback for sync completion
  void setSyncCompleteCallback(Function() callback) {
    _onSyncComplete = callback;
  }

  /// Clear sync completion callback
  void clearSyncCompleteCallback() {
    _onSyncComplete = null;
  }

  /// Initialize the sync service
  Future<void> initialize() async {
    AppLogger.sync('Initializing improved sync service', 'init');
    
    // Load last sync timestamps from local storage
    await _loadSyncMetadata();
    
    // Start periodic sync
    _startPeriodicSync();
    
    AppLogger.success('Improved sync service initialized', 'init');
    AppLogger.debug('Last successful sync: $_lastSuccessfulSync', 'init');
    AppLogger.debug('Last cloud sync: $_lastCloudSync', 'init');
  }

  /// Load sync metadata from local storage
  Future<void> _loadSyncMetadata() async {
    try {
      final db = DatabaseService();
      _lastSuccessfulSync = await db.getLastSyncTimestamp();
      _lastCloudSync = await db.getLastCloudSyncTimestamp();
      
    } catch (e) {
      AppLogger.warning('Could not load sync metadata', 'metadata', e);
    }
  }

  /// Save sync metadata to local storage
  Future<void> _saveSyncMetadata() async {
    try {
      final db = DatabaseService();
      if (_lastSuccessfulSync != null) {
        await db.saveLastSyncTimestamp(_lastSuccessfulSync!);
      }
      if (_lastCloudSync != null) {
        await db.saveLastCloudSyncTimestamp(_lastCloudSync!);
      }
      
    } catch (e) {
      AppLogger.warning('Could not save sync metadata', 'metadata', e);
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (!_isSyncing) {
        await performSync();
      }
    });
    
    AppLogger.timer('Periodic sync started (every ${_syncInterval.inMinutes} minutes)', 'periodic');
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    AppLogger.timer('Periodic sync stopped', 'periodic');
  }

  /// Perform optimized sync based on context
  Future<bool> performSync({bool showProgress = false, bool isInitialLogin = false, bool isBackground = false}) async {
    if (_isSyncing) {
      AppLogger.warning('Sync already in progress, skipping', 'perform');
      return false;
    }

    // Rate limiting: Don't sync too frequently
    if (_lastSuccessfulSync != null && !isInitialLogin) {
      final timeSinceLastSync = DateTime.now().difference(_lastSuccessfulSync!);
      final minSyncInterval = Duration(minutes: 2); // Minimum 2 minutes between syncs
      
      if (timeSinceLastSync < minSyncInterval) {
        AppLogger.timer('Rate limiting sync - only ${timeSinceLastSync.inMinutes}m since last sync (min: ${minSyncInterval.inMinutes}m)', 'rate_limit');
        return false;
      }
    }

    _isSyncing = true;
    _syncAttempts++;
    
    if (showProgress) notifyListeners();

    try {
      if (isInitialLogin) {
        AppLogger.sync('Starting SMART INITIAL LOGIN SYNC #$_syncAttempts', 'login');
      } else {
        AppLogger.sync('Starting incremental sync attempt #$_syncAttempts', 'incremental');
      }

      // Ensure Supabase is ready in background
      if (isBackground) {
        await BackgroundSupabaseClient.ensureInitializedAndRecovered();
      }

      // Check authentication and connectivity
      final supabaseService = SupabaseService();
      if (!supabaseService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final isConnected = await supabaseService.isConnected();
      if (!isConnected) {
        throw Exception('No network connectivity');
      }

      bool syncSuccess;
      if (isInitialLogin) {
        // Smart initial sync: Only recent data + unsynced local
        syncSuccess = await _performSmartInitialSync();
      } else {
        // Regular sync: Upload only (same as before)
        syncSuccess = await _performIncrementalSync();
      }

      if (syncSuccess) {
        _lastSuccessfulSync = DateTime.now();
        _syncAttempts = 0;
        _syncErrors.clear();
        await _saveSyncMetadata();
        
        // Trigger sync completion callback
        if (_onSyncComplete != null) {
          try {
            _onSyncComplete!();
            AppLogger.debug('Sync completion callback triggered', 'callback');
          } catch (e) {
            AppLogger.warning('Error in sync completion callback: $e', 'callback');
          }
        }
        
        if (isInitialLogin) {
          AppLogger.success('Smart initial sync completed at $_lastSuccessfulSync', 'login');
        } else {
          AppLogger.success('Incremental sync completed at $_lastSuccessfulSync', 'incremental');
        }
        return true;
      } else {
        throw Exception('Sync operation failed');
      }

    } catch (e) {
      final errorMsg = 'Sync failed: $e';
      AppLogger.error(errorMsg, 'perform', e);
      
      _syncErrors.add('${DateTime.now()}: $errorMsg');
      if (_syncErrors.length > 10) {
        _syncErrors.removeAt(0);
      }

      if (_syncAttempts < _maxRetryAttempts && !isInitialLogin) {
        _scheduleRetry();
      }

      return false;
    } finally {
      _isSyncing = false;
      if (showProgress) notifyListeners();
    }
  }

  /// Smart initial sync: Only download recent data, not everything
  Future<bool> _performSmartInitialSync() async {
    try {
      final db = DatabaseService();
      final supabaseService = SupabaseService();
      final userId = supabaseService.currentUserId!;

      print('📊 Starting smart initial sync...');

      // Step 1: Determine sync window
      final now = DateTime.now();
      final syncFromDate = _lastCloudSync ?? now.subtract(_initialSyncRange);
      
      print('📅 Sync window: ${syncFromDate.toString()} to ${now.toString()}');
      print('   - Range: ${now.difference(syncFromDate).inDays} days');

      // Step 2: Download only new/changed data from cloud
      print('📥 Downloading incremental data from cloud...');
      final cloudLogs = await supabaseService.getScreenTimeLogsSince(userId, syncFromDate);
      print('   - Found ${cloudLogs.length} cloud entries since last sync');

      // Step 3: Get local unsynced data
      final unsyncedLocal = await db.getUnsyncedScreenTimeLogs();
      print('   - Found ${unsyncedLocal.length} unsynced local entries');

      // Step 4: Intelligent merge (only process what we downloaded)
      final mergeResult = await _mergeIncrementalData(cloudLogs, unsyncedLocal, db);
      
      // Step 5: Upload unsynced local data
      if (unsyncedLocal.isNotEmpty) {
        print('📤 Uploading ${unsyncedLocal.length} local entries...');
        final uploadSuccess = await _uploadLocalLogs(unsyncedLocal, db);
        if (!uploadSuccess) {
          throw Exception('Failed to upload local data');
        }
      }

      // Step 7: Sync XP updates
      print('⭐ Syncing XP updates...');
      final xpSyncSuccess = await _syncXPUpdates();
      if (!xpSyncSuccess) {
        print('⚠️ XP sync failed, but continuing with other sync operations');
      }

      // Step 7b: Sync XP award history
      print('📜 Syncing XP award history...');
      final historySyncSuccess = await _syncXPAwardHistory();
      if (!historySyncSuccess) {
        print('⚠️ XP award history sync failed, but continuing with other sync operations');
      }

      // Step 7c: Sync profile updates (bio, user tag)
      print('👤 Syncing profile updates...');
      final profileSyncSuccess = await _syncProfileUpdates();
      if (!profileSyncSuccess) {
        print('⚠️ Profile sync failed, but continuing with other sync operations');
      }

      // Step 8: Download and store user profile from Supabase
      print('👤 Downloading user profile from Supabase...');
      try {
        final userProfile = await supabaseService.getUserProfile(userId);
        if (userProfile != null) {
          await db.insertUserProfile(userProfile);
          print('✅ User profile downloaded and stored locally:');
          print('   - Full Name: ${userProfile.fullName}');
          print('   - XP: ${userProfile.xp}');
          print('   - Email: ${userProfile.email}');
          if (userProfile.avatarUrl != null) {
            print('   - Avatar: ${userProfile.avatarUrl}');
          }
          if (userProfile.coverPhotoUrl != null) {
            print('   - Cover Photo: ${userProfile.coverPhotoUrl}');
          }
        } else {
          print('⚠️ No user profile found in Supabase');
        }
      } catch (e) {
        print('❌ Error downloading user profile: $e');
        // Don't fail the entire sync for profile download errors
      }

      // Step 6: Update sync timestamps
      _lastCloudSync = now;

      print('✅ Smart initial sync completed');
      print('   - Downloaded: ${mergeResult['downloaded']} entries');
      print('   - Uploaded: ${unsyncedLocal.length} entries');
      print('   - Conflicts resolved: ${mergeResult['conflicts']}');
      print('   - Network usage: ~${(cloudLogs.length * 0.1).toStringAsFixed(1)}KB (estimated)');
      
      return true;

    } catch (e) {
      print('❌ Error in smart initial sync: $e');
      return false;
    }
  }

  /// Incremental sync: Only upload unsynced data (no download)
  Future<bool> _performIncrementalSync() async {
    try {
      final db = DatabaseService();
      final supabaseService = SupabaseService();
      final userId = supabaseService.currentUserId!;

      // 1) Pull cloud changes since last cloud sync and merge
      final now = DateTime.now();
      final since = _lastCloudSync ?? now.subtract(_initialSyncRange);
      print('📥 Incremental: fetching cloud logs since ${since.toIso8601String()}');
      final cloudLogs = await supabaseService.getScreenTimeLogsSince(userId, since);
      if (cloudLogs.isNotEmpty) {
        print('   - Received ${cloudLogs.length} cloud entries');
        final unsyncedLocal = await db.getUnsyncedScreenTimeLogs();
        await _mergeIncrementalData(cloudLogs, unsyncedLocal, db);
      } else {
        print('   - No new cloud entries');
      }
      _lastCloudSync = now;

      // 2) Push local unsynced entries
      final unsyncedLogs = await db.getUnsyncedScreenTimeLogs();
      if (unsyncedLogs.isEmpty) {
        print('📊 No unsynced local data - incremental sync complete');
        return true;
      }

      print('📤 Uploading ${unsyncedLogs.length} local entries...');
      final success = await _uploadLocalLogs(unsyncedLogs, db);
      if (success) {
        print('✅ Incremental sync: uploaded ${unsyncedLogs.length} entries');
      }

      // 3) Sync XP updates
      print('⭐ Syncing XP updates...');
      final xpSyncSuccess = await _syncXPUpdates();
      if (!xpSyncSuccess) {
        print('⚠️ XP sync failed, but continuing with other sync operations');
      }

      // 4) Sync profile updates (bio, user tag) from local to Supabase
      print('👤 Syncing profile updates...');
      final profileSyncSuccess = await _syncProfileUpdates();
      if (!profileSyncSuccess) {
        print('⚠️ Profile sync failed, but continuing with other sync operations');
      }

      // 5) Update user profile from Supabase (download latest changes)
      print('👤 Updating user profile from Supabase...');
      try {
        final userProfile = await supabaseService.getUserProfile(userId);
        if (userProfile != null) {
          await db.insertUserProfile(userProfile); // Uses replace, so updates existing
          print('✅ User profile updated locally');
        }
      } catch (e) {
        print('⚠️ Profile update failed: $e');
        // Don't fail the entire sync for profile update errors
      }

      return success;
    } catch (e) {
      print('❌ Error in incremental sync: $e');
      return false;
    }
  }

  /// Merge incremental cloud data with local data
  Future<Map<String, int>> _mergeIncrementalData(
    List<ScreenTimeLog> cloudLogs,
    List<ScreenTimeLog> localLogs,
    DatabaseService db,
  ) async {
    int downloadedCount = 0;
    int conflictCount = 0;

    // Create map of local logs for conflict detection
    final localLogMap = <String, ScreenTimeLog>{};
    for (final log in localLogs) {
      final key = '${log.userId}_${log.startTime.millisecondsSinceEpoch}';
      localLogMap[key] = log;
    }

    // Process only the cloud logs we downloaded (much smaller dataset)
    for (final cloudLog in cloudLogs) {
      final key = '${cloudLog.userId}_${cloudLog.startTime.millisecondsSinceEpoch}';
      
      if (localLogMap.containsKey(key)) {
        // Conflict: Resolve by timestamp
        final localLog = localLogMap[key]!;
        if (cloudLog.createdAt.isAfter(localLog.createdAt)) {
          await _updateLocalFromCloud(cloudLog, db);
          conflictCount++;
        }
      } else {
        // New cloud data: Save locally
        await _saveCloudToLocal(cloudLog, db);
        downloadedCount++;
      }
    }

    return {
      'downloaded': downloadedCount,
      'conflicts': conflictCount,
    };
  }

  /// Save cloud log to local database
  Future<void> _saveCloudToLocal(ScreenTimeLog cloudLog, DatabaseService db) async {
    try {
      // Check if already exists
      final existing = await db.getScreenTimeLogByUserAndTime(
        cloudLog.userId, 
        cloudLog.startTime
      );
      
      if (existing != null && existing.isSynced) {
        // Already have this synced data, skip to prevent duplicate
        return;
      }
      
      if (existing == null) {
        // Truly new data, insert it
        final localLog = cloudLog.copyWith(
          id: DateTime.now().microsecondsSinceEpoch,
          isSynced: true,
        );
        await db.insertScreenTimeEntry(localLog);
      }
    } catch (e) {
      print('❌ Error saving cloud log locally: $e');
    }
  }

  /// Update local log with cloud version
  Future<void> _updateLocalFromCloud(ScreenTimeLog cloudLog, DatabaseService db) async {
    try {
      // Find existing record
      final existing = await db.getScreenTimeLogByUserAndTime(
        cloudLog.userId,
        cloudLog.startTime
      );
      
      if (existing != null) {
        // UPDATE existing record instead of inserting new one
        final updated = cloudLog.copyWith(
          id: existing.id,  // Keep original ID
          isSynced: true,
        );
        await db.updateScreenTimeLog(updated);
      } else {
        // Doesn't exist locally, insert it
        final localLog = cloudLog.copyWith(
          id: DateTime.now().microsecondsSinceEpoch,
          isSynced: true,
        );
        await db.insertScreenTimeEntry(localLog);
      }
    } catch (e) {
      print('❌ Error updating local from cloud: $e');
    }
  }

  /// Upload local logs to cloud
  Future<bool> _uploadLocalLogs(List<ScreenTimeLog> logs, DatabaseService db) async {
    try {
      final supabaseService = SupabaseService();
      const batchSize = 50;
      int successCount = 0;

      for (int i = 0; i < logs.length; i += batchSize) {
        final batch = logs.skip(i).take(batchSize).toList();
        
        try {
          await supabaseService.uploadScreenTimeLogs(batch);
          
          // Mark as synced
          for (final log in batch) {
            await db.markScreenTimeEntrySynced(log.id);
          }
          
          successCount += batch.length;
          print('📤 Uploaded batch: ${batch.length} entries');
          
        } catch (e) {
          print('❌ Failed to upload batch: $e');
          return false;
        }
      }

      print('✅ Upload complete: $successCount/${logs.length} entries');
      return successCount == logs.length;
      
    } catch (e) {
      print('❌ Error uploading logs: $e');
      return false;
    }
  }

  /// Schedule retry with exponential backoff
  void _scheduleRetry() {
    final delay = Duration(
      seconds: (_retryBaseDelay.inSeconds * math.pow(2, _syncAttempts - 1)).toInt(),
    );
    
    print('⏰ Scheduling retry #$_syncAttempts in ${delay.inSeconds}s');
    
    Timer(delay, () async {
      if (!_isSyncing) {
        await performSync();
      }
    });
  }

  /// Get sync statistics for debugging and UI display
  Map<String, dynamic> getSyncStats() {
    return {
      'isSyncing': _isSyncing,
      'lastSuccessfulSync': _lastSuccessfulSync?.toIso8601String(),
      'lastCloudSync': _lastCloudSync?.toIso8601String(),
      'syncAttempts': _syncAttempts,
      'hasErrors': _syncErrors.isNotEmpty,
      'errorCount': _syncErrors.length,
      'isPeriodicSyncActive': _periodicSyncTimer?.isActive ?? false,
    };
  }

  /// Force immediate sync (for manual triggers)
  Future<bool> forceSync() async {
    print('🔄 Force sync requested');
    _syncAttempts = 0; // Reset retry counter for manual sync
    return await performSync(showProgress: true);
  }

  /// Clear sync errors
  void clearErrors() {
    _syncErrors.clear();
    notifyListeners();
  }

  /// Sync XP updates from local storage to Supabase
  Future<bool> _syncXPUpdates() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return false;

      final db = DatabaseService();
      final unsyncedXPUpdates = await db.getUnsyncedXPUpdates(userId);
      
      if (unsyncedXPUpdates.isEmpty) {
        print('📊 No unsynced XP updates');
        return true;
      }

      // Get current user profile
      final userProfile = await SupabaseService().getUserProfile(userId);
      if (userProfile == null) return false;

      // Calculate total XP to add
      int totalXPToAdd = unsyncedXPUpdates.fold(0, (sum, update) => sum + update.xpToAdd);
      
      // Update profile with total XP
      final updatedProfile = userProfile.copyWith(
        xp: userProfile.xp + totalXPToAdd,
      );
      
      final success = await SupabaseService().updateUserProfile(updatedProfile);

      if (success != null) {
        // ✅ Update local database with new XP
        await db.updateUserProfile(updatedProfile);
        
        // Mark all XP updates as synced
        for (final xpUpdate in unsyncedXPUpdates) {
          await db.markXPUpdateAsSynced(xpUpdate.id);
        }
        print('✅ Synced ${unsyncedXPUpdates.length} XP updates: +$totalXPToAdd XP');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error syncing XP updates: $e');
      return false;
    }
  }

  /// Sync profile updates (bio, user tag) from local DB to Supabase
  Future<bool> _syncProfileUpdates() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return false;

      final db = DatabaseService();
      final localProfile = await db.getUserProfile(userId);
      
      if (localProfile == null) {
        print('📊 No local profile found for sync');
        return true;
      }

      // Only sync if profile was modified offline (isSynced = false)
      if (localProfile.isSynced) {
        print('📊 Profile already synced, skipping');
        return true;
      }

      final supabaseService = SupabaseService();
      
      // Update bio if changed
      if (localProfile.bio != null) {
        try {
          await supabaseService.updateUserProfileFields(
            bio: localProfile.bio,
          );
          print('✅ Bio synced to Supabase');
        } catch (e) {
          print('⚠️ Bio sync failed: $e');
        }
      }

      // Update user tag if changed (only if different from what's in Supabase)
      if (localProfile.userTag != null && localProfile.userTag!.isNotEmpty) {
        try {
          final cloudProfile = await supabaseService.getUserProfile(userId);
          if (cloudProfile != null && cloudProfile.userTag != localProfile.userTag) {
            final tagUpdated = await supabaseService.updateCurrentUserTag(localProfile.userTag!);
            if (tagUpdated) {
              print('✅ User tag synced to Supabase');
            } else {
              print('⚠️ User tag sync failed (may be unavailable)');
            }
          }
        } catch (e) {
          print('⚠️ User tag sync failed: $e');
        }
      }

      // Mark profile as synced
      final syncedProfile = localProfile.copyWith(isSynced: true);
      await db.updateUserProfile(syncedProfile);
      
      print('✅ Profile updates synced');
      return true;
    } catch (e) {
      print('❌ Error syncing profile updates: $e');
      return false;
    }
  }

  /// Sync XP award history from local storage to Supabase
  Future<bool> _syncXPAwardHistory() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return false;

      final db = DatabaseService();
      final unsyncedHistory = await db.getUnsyncedXPAwardHistory(userId);
      
      if (unsyncedHistory.isEmpty) {
        print('📜 No unsynced XP award history');
        return true;
      }

      final supabaseService = SupabaseService();
      int syncedCount = 0;

      // Sync each history record individually
      for (final history in unsyncedHistory) {
        try {
          // Check if already exists in Supabase (duplicate prevention)
          final alreadyExists = await supabaseService.checkXPAwardedForDate(userId, history.awardDate);
          
          if (!alreadyExists) {
            // Insert to Supabase
            final supabaseHistory = await supabaseService.insertXPAwardHistory(history);
            
            if (supabaseHistory != null) {
              // Mark as synced
              await db.markXPAwardHistoryAsSynced(history.id);
              syncedCount++;
              print('✅ Synced XP award history for ${history.awardDate.toString().split(' ')[0]}: +${history.xpAwarded} XP');
            } else {
              print('⚠️ Failed to sync XP award history for ${history.awardDate.toString().split(' ')[0]}');
            }
          } else {
            // Already exists in Supabase, mark as synced locally
            await db.markXPAwardHistoryAsSynced(history.id);
            syncedCount++;
            print('✅ XP award history already exists in Supabase for ${history.awardDate.toString().split(' ')[0]}, marked as synced');
          }
        } catch (e) {
          print('❌ Error syncing individual XP award history: $e');
          // Continue with next record
        }
      }

      if (syncedCount > 0) {
        print('✅ Synced $syncedCount/${unsyncedHistory.length} XP award history records');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error syncing XP award history: $e');
      return false;
    }
  }
  
}
