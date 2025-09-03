import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';
import '../models/user_models.dart';
import '../utils/app_logger.dart';

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
  static const Duration _syncInterval = Duration(minutes: 5);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(seconds: 10);
  static const Duration _initialSyncRange = Duration(days: 7); // Only download last week on first login

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
  Future<bool> performSync({bool showProgress = false, bool isInitialLogin = false}) async {
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
      final localLog = cloudLog.copyWith(
        id: DateTime.now().microsecondsSinceEpoch,
        isSynced: true,
      );
      
      await db.insertScreenTimeEntry(localLog);
    } catch (e) {
      print('❌ Error saving cloud log locally: $e');
    }
  }

  /// Update local log with cloud version
  Future<void> _updateLocalFromCloud(ScreenTimeLog cloudLog, DatabaseService db) async {
    try {
      final localLog = cloudLog.copyWith(
        id: DateTime.now().microsecondsSinceEpoch,
        isSynced: true,
      );
      
      await db.insertScreenTimeEntry(localLog);
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
}
