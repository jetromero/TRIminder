import 'database_service.dart';
import 'supabase_service.dart';
import 'automatic_screen_tracker.dart';
import 'persistent_tracker_service.dart';
import 'improved_sync_service.dart';

/// Manages user sessions and ensures proper data isolation between different users
class UserSessionManager {
  static final UserSessionManager _instance = UserSessionManager._internal();
  factory UserSessionManager() => _instance;
  UserSessionManager._internal();

  String? _currentUserId;
  String? _previousUserId;

  /// Get the current user ID
  String? get currentUserId => _currentUserId;

  /// Get the previous user ID (for cleanup purposes)
  String? get previousUserId => _previousUserId;

  /// Initialize session for a new user login
  Future<void> initializeUserSession(String newUserId) async {
    print('🔄 Initializing session for user: $newUserId');

    // Check if switching between different users
    if (_currentUserId != null && _currentUserId != newUserId) {
      print('👤 User switching detected: $_currentUserId → $newUserId');
      await _handleUserSwitch(_currentUserId!, newUserId);
    } else {
      print('👤 Same user login or first login');
    }

    // Update current user
    _previousUserId = _currentUserId;
    _currentUserId = newUserId;

    // Persist current user id for background isolate fallback
    try {
      await DatabaseService().setSyncMetadata('current_user_id', newUserId);
    } catch (_) {}

    // Initialize services for new user
    await _initializeUserServices(newUserId);
    
    print('✅ User session initialized for: $newUserId');
  }

  /// Handle user switching (cleanup old user, prepare for new user)
  Future<void> _handleUserSwitch(String oldUserId, String newUserId) async {
    print('🔄 Handling user switch: $oldUserId → $newUserId');

    try {
      // 1. Stop all tracking services
      await _stopUserServices();

      // 2. Sync any pending data for old user
      await _syncPendingData(oldUserId);

      // 3. Clear UI state and caches
      await _clearUIState();

      // 4. Optionally clear local data (based on privacy settings)
      // Note: We keep local data for faster access, but ensure proper isolation
      
      print('✅ User switch handled successfully');
    } catch (e) {
      print('❌ Error during user switch: $e');
      // Continue anyway to prevent blocking the new user login
    }
  }

  /// Initialize services for the current user
  Future<void> _initializeUserServices(String userId) async {
    try {
      // Restart automatic screen tracker for new user
      final tracker = AutomaticScreenTracker();
      await tracker.startMonitoring();

      // Ensure background service is tracking for correct user
      // The PersistentTrackerService will pick up the new user ID from SupabaseService
      await PersistentTrackerService.startService();

      // Initialize improved sync service and perform initial login sync
      await ImprovedSyncService().initialize();
      
      // Perform smart initial bidirectional sync to merge local and cloud data
      print('🔄 Performing smart initial login sync...');
      final syncSuccess = await ImprovedSyncService().performSync(showProgress: false, isInitialLogin: true);
      if (syncSuccess) {
        print('✅ Smart initial login sync completed');
      } else {
        print('⚠️ Smart initial login sync failed - will retry later');
      }

      print('✅ User services initialized for: $userId');
    } catch (e) {
      print('❌ Error initializing user services: $e');
    }
  }

  /// Stop all user-related services
  Future<void> _stopUserServices() async {
    try {
      // Stop automatic screen tracker
      AutomaticScreenTracker().stopMonitoring();

      // Note: We don't stop PersistentTrackerService completely as it should
      // continue running for the new user. It will automatically use the new user ID.

      print('✅ User services stopped');
    } catch (e) {
      print('❌ Error stopping user services: $e');
    }
  }

  /// Sync any pending data for the outgoing user
  Future<void> _syncPendingData(String userId) async {
    try {
      print('📤 Syncing pending data for user: $userId');
      
      // Temporarily set the user context for sync
      final syncService = ImprovedSyncService();
      await syncService.performSync(showProgress: false);
      
      print('✅ Pending data synced for user: $userId');
    } catch (e) {
      print('❌ Error syncing pending data: $e');
      // Don't block user switch for sync errors
    }
  }

  /// Clear UI state and caches
  Future<void> _clearUIState() async {
    try {
      // Clear automatic tracker state
      AutomaticScreenTracker().resetCurrentSession();
      
      print('✅ UI state cleared');
    } catch (e) {
      print('❌ Error clearing UI state: $e');
    }
  }

  /// Logout current user and cleanup
  Future<void> logoutCurrentUser() async {
    if (_currentUserId == null) {
      print('⚠️ No user to logout');
      return;
    }

    print('👋 Logging out user: $_currentUserId');

    try {
      // 1. Sync any pending data
      await _syncPendingData(_currentUserId!);

      // 2. Stop services
      await _stopUserServices();

      // 3. Clear UI state
      await _clearUIState();

      // 4. Sign out from Supabase
      await SupabaseService().signOut();

      // 5. Clear user session
      _previousUserId = _currentUserId;
      _currentUserId = null;

      // Clear persisted user id
      try {
        await DatabaseService().setSyncMetadata('current_user_id', '');
      } catch (_) {}

      print('✅ User logout completed');
    } catch (e) {
      print('❌ Error during logout: $e');
      // Clear session anyway
      _currentUserId = null;
    }
  }

  /// Clear all local data (for privacy or troubleshooting)
  Future<void> clearAllLocalData() async {
    try {
      print('🗑️ Clearing all local data');
      
      // Stop all services first
      await _stopUserServices();
      
      // Clear database
      await DatabaseService().clearAllData();
      
      // Clear user session
      _currentUserId = null;
      _previousUserId = null;
      
      print('✅ All local data cleared');
    } catch (e) {
      print('❌ Error clearing local data: $e');
    }
  }

  /// Get current user context info (for debugging)
  Map<String, dynamic> getSessionInfo() {
    return {
      'currentUserId': _currentUserId,
      'previousUserId': _previousUserId,
      'isLoggedIn': _currentUserId != null,
      'supabaseUserId': SupabaseService().currentUserId,
      'supabaseEmail': SupabaseService().currentUserEmail,
    };
  }

  /// Validate that current session is consistent
  bool validateSession() {
    final supabaseUserId = SupabaseService().currentUserId;
    final sessionValid = _currentUserId == supabaseUserId;
    
    if (!sessionValid) {
      print('⚠️ Session validation failed:');
      print('  Session UserId: $_currentUserId');
      print('  Supabase UserId: $supabaseUserId');
    }
    
    return sessionValid;
  }

  /// Force session cleanup and restart (for troubleshooting)
  Future<void> resetSession() async {
    print('🔄 Resetting user session');
    
    final currentSupabaseUserId = SupabaseService().currentUserId;
    
    if (currentSupabaseUserId != null) {
      // Re-initialize with current Supabase user
      await initializeUserSession(currentSupabaseUserId);
    } else {
      // No user logged in, clear everything
      await logoutCurrentUser();
    }
    
    print('✅ Session reset completed');
  }
}
