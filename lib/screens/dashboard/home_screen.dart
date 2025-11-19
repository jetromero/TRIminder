import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/automatic_screen_tracker.dart';
import '../../services/improved_sync_service.dart';
import '../../services/sync_coordinator.dart';
import '../../services/user_session_manager.dart';
import '../../models/user_models.dart';
import '../../utils/level_calculator.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/automatic_tracker_display.dart';
import '../../widgets/sync_status_widget.dart';
import '../../utils/debug_helper.dart';
import '../../services/persistent_tracker_service.dart';
import '../../services/first_time_setup_service.dart';
import '../../services/database_service.dart';
import '../../utils/simplified_logger.dart';
import '../../widgets/app_scaffold.dart';
import '../../utils/app_hibernation_helper.dart';
import '../../utils/battery_optimization_helper.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../profile/student_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isNewUser;
  const HomeScreen({super.key, this.isNewUser = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isNewUser = false;
  bool _showFriends = false;
  bool _showSettings = false;

  List<Widget> get _screens => [
    DashboardTab(
      isNewUser: _isNewUser,
      onSelectTab: _handleSelectTab,
      currentIndex: _currentIndex,
    ),
    RankingsTab(
      onSelectTab: _handleSelectTab,
    ),
    ChallengesTab(
      onSelectTab: _handleSelectTab,
    ),
  ];

  void _handleSelectTab(int index) {
    setState(() {
      if (index == 100) {
        _showFriends = true;
        _showSettings = false;
      } else if (index == 200) {
        _showSettings = true;
        _showFriends = false;
      } else {
        _currentIndex = index;
        _showFriends = false;
        _showSettings = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _isNewUser = widget.isNewUser;
    // Check for pending dialogs after screen loads (app hibernation first, then battery optimization)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPendingDialogs();
    });
  }

  /// Check and show pending dialogs (app hibernation first, then battery optimization)
  /// This ensures new users see the important setup dialogs immediately after login
  Future<void> _checkAndShowPendingDialogs() async {
    try {
      if (mounted && Platform.isAndroid) {
        // Wait a bit for the screen to fully render
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Check app hibernation first (Android 12+)
          final hibernationPending = await AppHibernationHelper.isPromptPending();
          if (hibernationPending) {
            // showAppHibernationDialog already clears the pending flag internally
            await AppHibernationHelper.showAppHibernationDialog(context);
            // Wait a bit before showing next dialog
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          if (mounted) {
            // Then check battery optimization
            final batteryPending = await BatteryOptimizationHelper.isPromptPending();
            if (batteryPending) {
              // showBatteryOptimizationDialog already clears the pending flag internally
              await BatteryOptimizationHelper.showBatteryOptimizationDialog(context);
            }
          }
        }
      }
    } catch (e) {
      print('Error showing pending dialogs: $e');
      // Don't block the UI if dialog fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showFriends
          ? FriendsTab(onSelectTab: _handleSelectTab)
          : _showSettings
              ? SettingsScreen(onSelectTab: _handleSelectTab)
          : _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _showFriends = false;
            _showSettings = false;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Rankings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Challenges',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  final bool isNewUser;
  final ValueChanged<int> onSelectTab;
  final int currentIndex;
  const DashboardTab({
    super.key, 
    this.isNewUser = false, 
    required this.onSelectTab,
    this.currentIndex = 0,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with WidgetsBindingObserver {
  UserProfile? userProfile;
  bool isLoading = true;
  bool _isOffline = false;
  late AutomaticScreenTracker _automaticTracker;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _automaticTracker = AutomaticScreenTracker();
    _checkConnectivity();
    _loadUserData();
    _startAutomaticTracking();
    // _startRefreshTimer();
    _ensureBackgroundServiceRunning();
    _setupSyncCallback();
  }

  /// Set up sync completion callback
  void _setupSyncCallback() {
    ImprovedSyncService().setSyncCompleteCallback(() {
      SimplifiedLogger.sync('Sync completed - triggering UI update only');
      // Just update UI state, don't trigger another full refresh
      if (mounted) {
        setState(() {});
        SimplifiedLogger.verbose('UI updated after sync completion');
      }
    });
  }

    /// Check connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final isConnected = await SupabaseService().isConnected();
      setState(() {
        _isOffline = !isConnected;
      });
      print('�� Connectivity check: ${_isOffline ? 'Offline' : 'Online'}');
    } catch (e) {
      setState(() {
        _isOffline = true;
      });
      print('�� Connectivity check failed, assuming offline: $e');
    }
  }

  /// Ensure background service is running
  Future<void> _ensureBackgroundServiceRunning() async {
    try {
      final isRunning = await PersistentTrackerService.isRunning();
      if (!isRunning) {
        print('⚠️ Background service not running - restarting...');
        await PersistentTrackerService.startService();
        print('✅ Background service restarted');
      } else {
        print('✅ Background service is running');
      }
    } catch (e) {
      print('❌ Error checking/restarting background service: $e');
    }
  }

  Future<void> _startAutomaticTracking() async {
    // Start the automatic screen tracker for UI display
    final started = await _automaticTracker.startMonitoring();
    if (!started) {
      print('Failed to start automatic screen tracking');
    }
  }

  // void _startRefreshTimer() {
  //   // Adjust interval based on connectivity
  //   final interval = Duration(seconds: 5);  // 5 seconds
  //   SimplifiedLogger.info('Starting ${interval.inSeconds}-second refresh timer (offline: $_isOffline)');
  //   _refreshTimer = Timer.periodic(interval, (_) {
  //     SimplifiedLogger.verbose('${interval.inSeconds}-second refresh tick triggered');
  //     _onRefreshTick();
  //   });
  // }

  // Future<void> _onRefreshTick() async {
  // try {
  //     print('⏰ Dashboard refresh - updating data (offline: $_isOffline)');
      
  //     // Add timeout to prevent hanging
  //     // Check for end of day first
  //     await _automaticTracker.checkForEndOfDay();
      
  //     // Refresh tracker data
  //     await _automaticTracker.refreshTodayData();
      
  //     // Reload background service data
  //     await PersistentTrackerService.reloadTodayData();
      
  //     // Only perform sync if online
  //     if (!_isOffline) {
  //       await ImprovedSyncService().performSync();
  //     } else {
  //       print('📱 Skipping sync - offline mode');
  //     }
      
  //     if (mounted) {
  //       setState(() {});
  //       print('🔄 Dashboard UI updated');
  //     }
  //   } catch (e) {
  //     print('❌ Error in refresh (timeout or other): $e');
  //     // Still update UI even if refresh fails
  //     if (mounted) {
  //       setState(() {});
  //     }
  //   }
  // }

  // Manual refresh method for debugging
  Future<void> _manualRefresh() async {
    print('🔄 Manual refresh triggered');
    await _automaticTracker.refreshTodayData();
    if (mounted) {
      setState(() {});
      print('🔄 Manual refresh completed');
    }
  }

  // Debug method to check and restart background service
  Future<void> _checkAndRestartService() async {
    print('🔧 Checking background service status...');
    final status = await PersistentTrackerService.getServiceStatus();
    print('📊 Service status: $status');
    
    if (status['running'] == false) {
      print('⚠️ Service not running - attempting restart...');
      await PersistentTrackerService.startService();
      print('✅ Service restart attempted');
    } else {
      print('✅ Service is running');
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service: ${status['running'] ? 'Running' : 'Stopped'}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    ImprovedSyncService().clearSyncCompleteCallback();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('App resumed - checking connectivity and refreshing data');
        
        // Check connectivity first
        await _checkConnectivity();
        
        // Ensure background service is running
        await _ensureBackgroundServiceRunning();
        
        // Single comprehensive refresh that includes sync
        await _comprehensiveRefresh();
        
        if (mounted) setState(() {});
        break;
        
      case AppLifecycleState.paused:
        print('App paused - ensuring background service continues');
        // Background service should continue running
        break;
        
      case AppLifecycleState.detached:
        print('App detached - background service should continue');
        // Background service should continue running
        break;
        
      default:
        break;
    }
  }

  /// Single comprehensive refresh method to avoid multiple calls
  Future<void> _comprehensiveRefresh() async {
    try {
      print('🔄 Starting comprehensive refresh');
      
      final coordinator = SyncCoordinator();
      await coordinator.requestSync(() => ImprovedSyncService().performSync());
      
      // Refresh tracker data
      await _automaticTracker.refreshTodayData();
      
      // Reload background service data
      await PersistentTrackerService.reloadTodayData();
      
      print('🔄 Comprehensive refresh completed');
    } catch (e) {
      print('❌ Error in comprehensive refresh: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        UserProfile? profile;
        
        // Try Supabase first (when online)
        if (!_isOffline) {
          profile = await SupabaseService().getUserProfile(userId);
        }
        
        // Fallback to local database (when offline or Supabase fails)
        if (profile == null) {
          final db = DatabaseService();
          profile = await db.getUserProfile(userId);
          print('📱 Loaded user profile from local database (offline mode)');
        }
        
        setState(() {
          userProfile = profile;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Widget> _getDashboardWidgets() {
    return [
      
      // Welcome Section
      WelcomeCard(
        userProfile: userProfile,
        isNewUser: widget.isNewUser,
      ),
      
      // Automatic Screen Time Tracker  
      const AutomaticTrackerDisplay(),
      
      // XP Progress
      XPProgressCard(userProfile: userProfile),
      
      // Recent Badges
      const RecentBadgesCard(),
      
      // Sync Status (for monitoring data sync)
      const SyncStatusWidget(),
      
      // Debug Panel (temporary for testing)
      Card(
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Panel', 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
              
              // Responsive button grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 600;
                  final isMediumScreen = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
                  
                  // Determine buttons per row based on screen size
                  int buttonsPerRow;
                  if (isSmallScreen) {
                    buttonsPerRow = 2; // 2 buttons per row on mobile
                  } else if (isMediumScreen) {
                    buttonsPerRow = 3; // 3 buttons per row on tablet
                  } else {
                    buttonsPerRow = 4; // 4 buttons per row on desktop
                  }
                  
                  // Define all debug buttons
                  final debugButtons = [
                    _DebugButton(
                      label: 'Auth',
                      onPressed: () async => await DebugHelper.checkAuthStatus(),
                      icon: Icons.security,
                    ),
                    _DebugButton(
                      label: 'Check DB',
                      onPressed: () async => await DebugHelper.checkDatabaseContent(),
                      icon: Icons.storage,
                    ),
                    _DebugButton(
                      label: 'Test Track',
                      onPressed: () async => await DebugHelper.testScreenTimeTracking(),
                      icon: Icons.track_changes,
                    ),
                    _DebugButton(
                      label: 'Add Test',
                    onPressed: () async {
                      await DebugHelper.addTestScreenTimeEntry();
                      await _automaticTracker.refreshTodayData();
                        setState(() {});
                    },
                      icon: Icons.add,
                  ),
                    _DebugButton(
                      label: 'Check Service',
                      onPressed: () async {
                        await _checkAndRestartService();
                      },
                      icon: Icons.engineering,
                    ),
                                                    _DebugButton(
                                  label: 'Check Setup',
              onPressed: () async {
                                    final setupStatus = await FirstTimeSetupService.checkSetupStatus();
                                    print('🔧 Setup Status: $setupStatus');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Setup: ${setupStatus['backgroundConfigured'] ? 'Configured' : 'Needs Setup'}'),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  icon: Icons.settings,
                                ),
                                _DebugButton(
                                  label: 'Manual Refresh',
                    onPressed: () async {
                                    await _manualRefresh();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Manual refresh completed'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: Icons.refresh,
                                ),
                    _DebugButton(
                      label: 'Old Sync',
                      onPressed: () async => await DebugHelper.testBidirectionalSync(),
                      icon: Icons.sync,
                    ),
                                         _DebugButton(
                       label: 'Session',
                       onPressed: () async => await DebugHelper.checkSessionStatus(),
                       icon: Icons.access_time,
                     ),
                    _DebugButton(
                      label: 'Save Session',
              onPressed: () async {
                await DebugHelper.saveCurrentSessionManually();
                await _automaticTracker.refreshTodayData();
                        setState(() {});
              },
                      icon: Icons.save,
            ),
                    _DebugButton(
                      label: 'Clear Data',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Data'),
                    content: const Text('This will delete all local data. Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await DebugHelper.clearAllLocalData();
                          setState(() {});
                        }
                      },
                      icon: Icons.delete_forever,
                      isDestructive: true,
                    ),
                    _DebugButton(
                      label: 'New Sync',
                      onPressed: () async => await DebugHelper.testImprovedSync(),
                      icon: Icons.cloud_sync,
                    ),
                    _DebugButton(
                      label: 'Compare',
                      onPressed: () async => await DebugHelper.compareSyncMethods(),
                      icon: Icons.compare_arrows,
                    ),
                  ];
                  
                  // Create responsive grid
                  return Column(
                    children: [
                      for (int i = 0; i < debugButtons.length; i += buttonsPerRow)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i + buttonsPerRow < debugButtons.length 
                              ? ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)
                              : 0,
                          ),
                          child: Row(
          children: [
                              for (int j = 0; j < buttonsPerRow && i + j < debugButtons.length; j++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: j < buttonsPerRow - 1 && i + j + 1 < debugButtons.length
                                        ? ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)
                                        : 0,
                                    ),
                                    child: debugButtons[i + j],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
        ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: _AppDrawer(
        onSelectTab: widget.onSelectTab,
        currentScreenIndex: widget.currentIndex,
      ),
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20 * ResponsiveUtils.getFontScale(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications,
              size: ResponsiveUtils.getIconSize(context),
            ),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              final coordinator = SyncCoordinator();
              coordinator.requestSync(() => ImprovedSyncService().performSync());
              await _automaticTracker.refreshTodayData();
              if (mounted) setState(() {});
            },
            child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.getMaxContentWidth(context),
              ),
              child: ListView.separated(
                  physics: const ClampingScrollPhysics(),
                padding: ResponsiveUtils.getScreenPadding(context),
                itemCount: _getDashboardWidgets().length,
                separatorBuilder: (context, index) => SizedBox(
                  height: ResponsiveUtils.getSpacing(context),
                ),
                itemBuilder: (context, index) => _getDashboardWidgets()[index],
                ),
              ),
            ),
          ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  final UserProfile? userProfile;
  final bool isNewUser;
  
  const WelcomeCard({super.key, this.userProfile, this.isNewUser = false});

  @override
  Widget build(BuildContext context) {
    final fontScale = ResponsiveUtils.getFontScale(context);
    
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isNewUser 
              ? 'Welcome to TRIminder, ${userProfile?.fullName ?? 'Student'}!'
              : 'Welcome back, ${userProfile?.fullName ?? 'Student'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * fontScale,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              isNewUser
              ? 'Let\'s start your digital wellness journey!'
              : 'Ready to continue your digital wellness journey?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * fontScale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScreenTimeCard extends StatelessWidget {
  final int screenTimeMinutes;
  
  const ScreenTimeCard({super.key, required this.screenTimeMinutes});

  String _formatScreenTime(int minutes) {
    if (minutes == 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Screen Time Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatScreenTime(screenTimeMinutes),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Total usage',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      screenTimeMinutes == 0 ? 'No data' : 'Great start!',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: screenTimeMinutes == 0 ? Colors.grey : Colors.green,
                      ),
                    ),
                    Text(
                      screenTimeMinutes == 0 ? 'Start tracking' : 'Keep it up',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class XPProgressCard extends StatefulWidget {
  final UserProfile? userProfile;
  
  const XPProgressCard({super.key, this.userProfile});

  @override
  State<XPProgressCard> createState() => _XPProgressCardState();
}

class _XPProgressCardState extends State<XPProgressCard> {
  int? totalXP;
  int? level;
  double? progress;
  Map<String, int>? levelProgress;

  @override
  void initState() {
    super.initState();
    _updateXPData();
  }

  @override
  void didUpdateWidget(XPProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _updateXPData();
    }
  }

  Future<void> _updateXPData() async {
    if (widget.userProfile == null) return;
    
    try {
      final totalXPWithPending = await widget.userProfile!.getTotalXPWithPending();
      final levelWithPending = await widget.userProfile!.getLevelWithPending();
      final progressWithPending = await widget.userProfile!.getProgressToNextLevelWithPending();
      final levelProgressWithPending = LevelCalculator.getCurrentLevelProgress(totalXPWithPending);
      
      if (mounted) {
        setState(() {
          totalXP = totalXPWithPending;
          level = levelWithPending;
          progress = progressWithPending;
          levelProgress = levelProgressWithPending;
        });
      }
    } catch (e) {
      print('Error updating XP data: $e');
    }
  }

  void _showXPLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.amber,
              size: ResponsiveUtils.getIconSize(context),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context)),
            Text('XP Legend'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Daily XP based on screen time:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            _buildLegendItem(context, '≤2 hours', '100 XP', 'Excellent 🏆', Colors.green),
            _buildLegendItem(context, '2-4 hours', '75 XP', 'Great 🥇', Colors.lightGreen),
            _buildLegendItem(context, '4-6 hours', '50 XP', 'Good 🥈', Colors.orange),
            _buildLegendItem(context, '6-8 hours', '25 XP', 'Fair 🥉', Colors.deepOrange),
            _buildLegendItem(context, '8-10 hours', '10 XP', 'High ⚠️', Colors.red),
            _buildLegendItem(context, '10+ hours', '0 XP', 'Excessive ⚠️', Colors.red.shade800),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String timeRange, String xp, String rating, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
          Expanded(
            child: Text(
              timeRange,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            xp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
          Text(
            rating,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xp = totalXP ?? widget.userProfile?.xp ?? 0;
    final currentLevel = level ?? widget.userProfile?.level ?? 1;
    final currentProgress = progress ?? widget.userProfile?.progressToNextLevel ?? 0.0;
    final currentLevelProgress = levelProgress ?? widget.userProfile?.currentLevelProgress ?? {'currentLevelXP': 0, 'requiredForNextLevel': 100, 'remaining': 100};
    final xpInCurrentLevel = currentLevelProgress['currentLevelXP']!;
    final xpNeededForNextLevel = currentLevelProgress['requiredForNextLevel']!;
    final xpRemaining = currentLevelProgress['remaining']!;
    final fontScale = ResponsiveUtils.getFontScale(context);

    return Card(
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: ResponsiveUtils.getIconSize(context),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Text(
                  'XP Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * fontScale,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: ResponsiveUtils.getIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => _showXPLegend(context),
                ),
                Text(
                  'Level $currentLevel',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            context.isMobile 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                      style: TextStyle(fontSize: 14 * fontScale),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                    Text(
                      'Level ${currentLevel + 1}',
                      style: TextStyle(fontSize: 14 * fontScale),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Text(
                      '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                      style: TextStyle(fontSize: 14 * fontScale),
                    ),
                    const Spacer(),
                  ],
                ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            LinearProgressIndicator(
              value: currentProgress.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: context.isMobile ? 6 : 8,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              xp == 0 
                ? 'Start tracking to earn XP! Need ${LevelCalculator.getXPRequiredForLevel(1)} XP for Level 2' 
                : xpRemaining > 0 
                    ? '$xpRemaining XP to Level ${currentLevel + 1}'
                    : 'Ready to level up!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class RecentBadgesCard extends StatelessWidget {
  const RecentBadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fontScale = ResponsiveUtils.getFontScale(context);
    final iconSize = ResponsiveUtils.getIconSize(context, mobile: 48, tablet: 56, desktop: 64);
    
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Badges',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * fontScale,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            // Show "no badges yet" for new users
            Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(iconSize / 2),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.grey,
                    size: iconSize * 0.5,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No badges earned yet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                      Text(
                        'Start tracking your screen time to earn badges!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RankingsTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  const RankingsTab({super.key, required this.onSelectTab});

  @override
  State<RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<RankingsTab> with SingleTickerProviderStateMixin {
  String _scope = 'evsu'; // 'evsu' | 'department' | 'friends'
  String _period = 'daily'; // 'daily' | 'weekly' | 'monthly'
  bool _ascending = true; // ascending minutes (less is better)
  bool _loading = false;
  List<RankingEntry> _entries = [];
  int? _myDepartmentId;
  int _limit = 50;
  int _offset = 0;
  bool _hasMore = true;
  late TabController _tabController;
  int _friendCount = -1; // -1 means not loaded, 0 means no friends, >0 means has friends

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final idx = _tabController.index;
      final nextScope = idx == 0 ? 'evsu' : idx == 1 ? 'department' : 'friends';
      if (_scope != nextScope) {
        setState(() {
          _scope = nextScope;
          // Reset friend count when switching to friends tab to reload it
          if (nextScope == 'friends') {
            _friendCount = -1;
          }
        });
        // Preserve current period when switching tabs
        _fetchRankings(reset: true, forceCurrentPeriod: true);
      }
    });
    _loadMyDepartment();
    _fetchRankings(reset: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyDepartment() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;
      final profile = await SupabaseService().getUserProfile(userId);
      setState(() { _myDepartmentId = profile?.departmentId; });
    } catch (_) {}
  }

  /// Calculate rank with ties handling
  /// If multiple users have the same valueMinutes, they get the same rank
  /// Example: [100, 100, 90, 90, 80] -> ranks: [1, 1, 3, 3, 5]
  int _calculateRank(int index) {
    if (index == 0) return 1;
    
    // Find the first entry with a different value
    final currentValue = _entries[index].valueMinutes;
    for (int i = index - 1; i >= 0; i--) {
      if (_entries[i].valueMinutes != currentValue) {
        // Found first different value, rank is i + 2 (since i is 0-indexed)
        return i + 2;
      }
    }
    // All previous entries have the same value, so rank is 1
    return 1;
  }

  Future<void> _fetchRankings({bool reset = false, bool forceCurrentPeriod = false}) async {
    if (_loading) return;
    setState(() { _loading = true; if (reset) { _offset = 0; _hasMore = true; _entries = []; } });

    try {
      // Department scope requires user's department
      if (_scope == 'department' && _myDepartmentId == null) {
            setState(() {
          _entries = [];
          _hasMore = false;
        });
        return;
      }

      final svc = SupabaseService();
      final depId = _scope == 'department' ? _myDepartmentId : null;
      List<RankingEntry> page = [];

      // Handle friends scope separately
      if (_scope == 'friends') {
        // Load friend count if not loaded yet
        if (_friendCount == -1) {
          try {
            final friends = await svc.getFriends();
            setState(() {
              _friendCount = friends.length;
            });
          } catch (e) {
            print('Error loading friend count: $e');
            setState(() {
              _friendCount = 0;
            });
          }
        }

        // Automatic period selection on reset (or when no period chosen) unless forcing current period
        if ((reset || _entries.isEmpty) && !forceCurrentPeriod) {
          final attemptOrder = ['daily', 'weekly', 'monthly'];
          for (final p in attemptOrder) {
            List<RankingEntry> tmp;
            if (p == 'daily') {
              tmp = await svc.getFriendsDailyRankings(limit: _limit, offset: 0, ascending: _ascending);
            } else if (p == 'weekly') {
              tmp = await svc.getFriendsWeeklyRankings(limit: _limit, offset: 0, ascending: _ascending);
            } else {
              tmp = await svc.getFriendsMonthlyRankings(limit: _limit, offset: 0, ascending: _ascending);
            }
            if (tmp.isNotEmpty) {
              _period = p;
              page = tmp;
              _offset = tmp.length; // start after first page
              break;
            }
          }
          // If still empty (no data anywhere), keep period at daily
          if (page.isEmpty) {
            _period = 'daily';
          }
        } else if ((reset || _entries.isEmpty) && forceCurrentPeriod) {
          // Respect user-selected current period when forced
          if (_period == 'daily') {
            page = await svc.getFriendsDailyRankings(limit: _limit, offset: 0, ascending: _ascending);
          } else if (_period == 'weekly') {
            page = await svc.getFriendsWeeklyRankings(limit: _limit, offset: 0, ascending: _ascending);
          } else {
            page = await svc.getFriendsMonthlyRankings(limit: _limit, offset: 0, ascending: _ascending);
          }
        } else {
          // Keep using the chosen period for pagination
          if (_period == 'daily') {
            page = await svc.getFriendsDailyRankings(limit: _limit, offset: _offset, ascending: _ascending);
          } else if (_period == 'weekly') {
            page = await svc.getFriendsWeeklyRankings(limit: _limit, offset: _offset, ascending: _ascending);
          } else {
            page = await svc.getFriendsMonthlyRankings(limit: _limit, offset: _offset, ascending: _ascending);
          }
        }
      } else {
        // Automatic period selection on reset (or when no period chosen) unless forcing current period
        if ((reset || _entries.isEmpty) && !forceCurrentPeriod) {
          final attemptOrder = ['daily', 'weekly', 'monthly'];
          for (final p in attemptOrder) {
            List<RankingEntry> tmp;
            if (p == 'daily') {
              tmp = await svc.getDailyRankings(departmentId: depId, limit: _limit, offset: 0, ascending: _ascending);
            } else if (p == 'weekly') {
              tmp = await svc.getWeeklyRankings(departmentId: depId, limit: _limit, offset: 0, ascending: _ascending);
            } else {
              tmp = await svc.getMonthlyRankings(departmentId: depId, limit: _limit, offset: 0, ascending: _ascending);
            }
            // Enforce department on client side just in case
            if (_scope == 'department') {
              tmp = tmp.where((e) => e.departmentId == _myDepartmentId).toList();
            }
            if (tmp.isNotEmpty) {
              _period = p;
              page = tmp;
              _offset = tmp.length; // start after first page
              break;
            }
          }
          // If still empty (no data anywhere), keep period at daily
          if (page.isEmpty) {
            _period = 'daily';
          }
        } else if ((reset || _entries.isEmpty) && forceCurrentPeriod) {
          // Respect user-selected current period when forced
          if (_period == 'daily') {
            page = await svc.getDailyRankings(departmentId: depId, limit: _limit, offset: 0);
          } else if (_period == 'weekly') {
            page = await svc.getWeeklyRankings(departmentId: depId, limit: _limit, offset: 0);
          } else {
            page = await svc.getMonthlyRankings(departmentId: depId, limit: _limit, offset: 0);
          }
        } else {
          // Keep using the chosen period for pagination
          if (_period == 'daily') {
            page = await svc.getDailyRankings(departmentId: depId, limit: _limit, offset: _offset, ascending: _ascending);
          } else if (_period == 'weekly') {
            page = await svc.getWeeklyRankings(departmentId: depId, limit: _limit, offset: _offset, ascending: _ascending);
          } else {
            page = await svc.getMonthlyRankings(departmentId: depId, limit: _limit, offset: _offset, ascending: _ascending);
          }
        }

        // Client-side filter to enforce department in all periods (weekly/monthly views may lack FK joins)
        if (_scope == 'department') {
          page = page.where((e) => e.departmentId == _myDepartmentId).toList();
        }
      }

      // Client-side sort by minutes to guarantee visual order regardless of backend
      page.sort((a, b) => _ascending
          ? a.valueMinutes.compareTo(b.valueMinutes)
          : b.valueMinutes.compareTo(a.valueMinutes));

      setState(() {
        _entries.addAll(page);
        _offset += page.length;
        _hasMore = page.length == _limit;
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // Scope/period change handled by TabController and automatic period selection


  @override
  Widget build(BuildContext context) {
    return AppScaffold(
        drawer: _AppDrawer(
          onSelectTab: widget.onSelectTab,
          currentScreenIndex: 1, // Rankings tab
        ),
      drawerEdgeDragWidthOverride: MediaQuery.of(context).size.width * 0.2,
      drawerGestureEnabled: true,
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: Column(
            children: [
          // Centered, swipable tabs: EVSU | Department | Friends
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TabBar(
              controller: _tabController,
            tabs: const [
              Tab(text: 'EVSU'),
              Tab(text: 'Department'),
              Tab(text: 'Friends'),
            ],
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
            ),
          ),
          // Second row: participants count (left) and period pill (right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                Text('${_entries.length} participants'),
                  const Spacer(),
                Row(children: [
                  _CurrentPeriodButton(
                    period: _period,
                    onCycle: () {
                      setState(() {
                        _period = _period == 'daily'
                            ? 'weekly'
                            : _period == 'weekly' ? 'monthly' : 'daily';
                      });
                      _fetchRankings(reset: true, forceCurrentPeriod: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  _SortToggleButton(
                    ascending: _ascending,
                    onToggle: () {
                      setState(() { _ascending = !_ascending; });
                      _fetchRankings(reset: true, forceCurrentPeriod: true);
                    },
                  ),
                ]),
                ],
              ),
            ),
          const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
                children: [
                _buildRankingList(),
                _buildRankingList(),
                _buildRankingList(),
                ],
              ),
            ),
            ],
          ),
    );
  }

  Widget _buildRankingList() {
    if (_scope == 'department' && _myDepartmentId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No department assigned to your profile. Rankings unavailable.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
    }

    // Handle empty state for friends scope
    if (_scope == 'friends' && !_loading && _entries.isEmpty) {
      // Show different message based on whether user has friends or not
      final hasFriends = _friendCount > 0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFriends ? Icons.analytics_outlined : Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                hasFriends ? 'No rankings data' : 'No friends yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                hasFriends
                    ? 'Your friends haven\'t tracked any screen time for this period yet.'
                    : 'Add friends to see rankings!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async { await _fetchRankings(reset: true); },
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _entries.length) {
            _fetchRankings();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final entry = _entries[index];
          // Calculate rank with ties handling
          int rank = _calculateRank(index);
          return _RankingTile(
            rank: rank,
            entry: entry,
            you: entry.userId == SupabaseService().currentUserId,
          );
        },
      ),
    );
  }
}

// (old custom scope tab removed; now using TabBar)

class _CurrentPeriodButton extends StatelessWidget {
  final String period;
  final VoidCallback onCycle;
  const _CurrentPeriodButton({required this.period, required this.onCycle});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    if (period == 'daily') { label = 'Today'; icon = Icons.schedule; }
    else if (period == 'weekly') { label = 'Weekly'; icon = Icons.calendar_view_week; }
    else { label = 'Monthly'; icon = Icons.calendar_month; }

    return InkWell(
      onTap: onCycle,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SortToggleButton extends StatelessWidget {
  final bool ascending;
  final VoidCallback onToggle;
  const _SortToggleButton({required this.ascending, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
      ),
    );
  }
}

// (removed old _PeriodToggle, now using automatic period badge)

class _RankingTile extends StatelessWidget {
  final int rank;
  final RankingEntry entry;
  final bool you;

  const _RankingTile({
    required this.rank,
    required this.entry,
    required this.you,
  });

  /// Format rank number (#1, #2, #3, etc.)
  String _formatRank(int rank) {
    return '#$rank';
  }

  /// Get rank badge color (gold for 1st, silver for 2nd, bronze for 3rd, default for others)
  Color _getRankColor(BuildContext context, int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return Theme.of(context).colorScheme.primaryContainer;
  }

  /// Get rank text color (dark for top 3, theme color for others)
  Color _getRankTextColor(BuildContext context, int rank) {
    if (rank <= 3) return Colors.black87;
    return Theme.of(context).colorScheme.onPrimaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final hours = entry.valueMinutes ~/ 60;
    final mins = entry.valueMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final name = entry.fullName ?? entry.userTag ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentProfileScreen(userId: entry.userId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with rank badge overlay
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarWidget.small(
                    avatarUrl: entry.avatarUrl,
                    fullName: name,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentProfileScreen(userId: entry.userId),
                        ),
                      );
                    },
                  ),
                  // Rank badge positioned in upper left corner
                  Positioned(
                    left: -4,
                    top: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getRankColor(context, rank),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _formatRank(rank),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: rank <= 3 ? 12 : 10,
                            color: _getRankTextColor(context, rank),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (you)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('You', style: TextStyle(fontSize: 12)),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      entry.departmentName ?? '—',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Screen time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('screen time', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendsTab extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  const FriendsTab({super.key, required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: _AppDrawer(
        onSelectTab: onSelectTab,
        currentScreenIndex: 100, // Friends tab
      ),
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _FriendsSearchCard(),
          const SizedBox(height: 16),
          _FriendsListCard(),
          const SizedBox(height: 16),
          _FriendRequestsCard(),
        ],
      ),
    );
  }
}

class _FriendsSearchCard extends StatefulWidget {
  @override
  State<_FriendsSearchCard> createState() => _FriendsSearchCardState();
}

class _FriendsSearchCardState extends State<_FriendsSearchCard> {
  final _controller = TextEditingController();
  bool _loading = false;
  UserProfile? _result;
  bool _sending = false;
  Timer? _debounce;
  String? _statusHint; // self | already_friends | pending_in | pending_out | blocked | none

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() { _loading = true; _result = null; });
    try {
      final profile = await SupabaseService().getProfileByUserTag(query);
      String? statusHint;
      if (profile != null) {
        final me = SupabaseService().currentUserId;
        if (me != null && profile.id == me) {
          statusHint = 'self';
        } else {
          // Check relationship status by querying the pair if exists
          try {
            final a = SupabaseService().currentUserId;
            if (a != null) {
              final least = a.compareTo(profile.id) <= 0 ? a : profile.id;
              final greatest = a.compareTo(profile.id) > 0 ? a : profile.id;
              final row = await SupabaseService().client
                  .from('friendships')
                  .select('requester_id,status')
                  .eq('user_a_id', least)
                  .eq('user_b_id', greatest)
                  .maybeSingle();
              if (row != null) {
                final s = (row['status'] as String?) ?? 'pending';
                if (s == 'accepted') statusHint = 'already_friends';
                else if (s == 'blocked') statusHint = 'blocked';
                else if (s == 'pending') {
                  final requester = row['requester_id'] as String?;
                  statusHint = requester == a ? 'pending_out' : 'pending_in';
                } else { statusHint = 'none'; }
              } else {
                statusHint = 'none';
              }
            }
          } catch (_) { statusHint = 'none'; }
        }
      }
      setState(() { _result = profile; _statusHint = statusHint; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _sendRequest(UserProfile target) async {
    setState(() { _sending = true; });
    try {
      final ok = await SupabaseService().sendFriendRequest(target.id);
      final msg = ok ? 'Friend request sent' : 'Could not send request';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() { _sending = false; });
    }
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_controller.text.trim().isNotEmpty) {
        _search();
      } else {
        setState(() { _result = null; _statusHint = null; });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find friends by tag', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter user tag (e.g., Alice7)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_result != null)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_result!.fullName),
                subtitle: Text('@${_result!.userTag ?? 'no-tag'}'),
                trailing: FilledButton(
                  onPressed: (_sending || _statusHint == 'self' || _statusHint == 'already_friends' || _statusHint == 'pending_out' || _statusHint == 'blocked')
                      ? null
                      : () => _sendRequest(_result!),
                  child: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          _statusHint == 'self' ? 'It\'s you'
                          : _statusHint == 'already_friends' ? 'Friends'
                          : _statusHint == 'pending_in' ? 'Respond in Requests'
                          : _statusHint == 'pending_out' ? 'Pending'
                          : _statusHint == 'blocked' ? 'Blocked'
                          : 'Add',
                        ),
                ),
              )
            else if (!_loading && _controller.text.trim().isNotEmpty)
              const Text('No user found'),
          ],
        ),
      ),
    );
  }
}

class _FriendsListCard extends StatefulWidget {
  @override
  State<_FriendsListCard> createState() => _FriendsListCardState();
}

class _FriendsListCardState extends State<_FriendsListCard> with WidgetsBindingObserver {
  bool _loading = true;
  List<UserProfile> _friends = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app resumes
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final data = await SupabaseService().getFriends();
      if (mounted) {
        setState(() { _friends = data; });
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Your friends', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()))
            else if (_friends.isEmpty)
              const Text('No friends yet')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _friends.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = _friends[i];
                  return ListTile(
                    leading: AvatarWidget.small(
                      avatarUrl: p.avatarUrl,
                      fullName: p.fullName,
                    ),
                    title: Text(p.fullName),
                    subtitle: Text('@${p.userTag ?? 'no-tag'}'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentProfileScreen(userId: p.id),
                        ),
                      );
                      // Refresh friends list when returning from profile
                      if (mounted) {
                        _load();
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestsCard extends StatefulWidget {
  @override
  State<_FriendRequestsCard> createState() => _FriendRequestsCardState();
}

class _FriendRequestsCardState extends State<_FriendRequestsCard> {
  bool _loading = true;
  bool _busy = false;
  List<Map<String, dynamic>> _incoming = const [];
  List<Map<String, dynamic>> _outgoing = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final incoming = await SupabaseService().getIncomingPendingRequests();
      final outgoing = await SupabaseService().getOutgoingPendingRequests();
      setState(() {
        _incoming = incoming;
        _outgoing = outgoing;
      });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _accept(int id) async {
    setState(() { _busy = true; });
    try {
      await SupabaseService().acceptFriendRequest(id);
      await _load();
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _reject(int id) async {
    setState(() { _busy = true; });
    try {
      await SupabaseService().rejectFriendRequest(id);
      await _load();
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  Future<void> _cancel(int id) async {
    setState(() { _busy = true; });
    try {
      await SupabaseService().cancelMyPendingRequest(id);
      await _load();
    } finally {
      if (mounted) setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Friend requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()))
            else ...[
              Text('Incoming', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_incoming.isEmpty) const Text('No incoming pending requests')
              else ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _incoming.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _incoming[i];
                  final UserProfile? cp = r['counterpart'] as UserProfile?;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(cp?.fullName ?? 'User'),
                    subtitle: Text('@${cp?.userTag ?? 'no-tag'}'),
                    trailing: Wrap(spacing: 8, children: [
                      FilledButton(
                        onPressed: _busy ? null : () => _accept(r['id'] as int),
                        child: const Text('Accept'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _reject(r['id'] as int),
                        child: const Text('Reject'),
                      ),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Outgoing', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_outgoing.isEmpty) const Text('No outgoing pending requests')
              else ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _outgoing.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _outgoing[i];
                  final UserProfile? cp = r['counterpart'] as UserProfile?;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(cp?.fullName ?? 'User'),
                    subtitle: Text('@${cp?.userTag ?? 'no-tag'}'),
                    trailing: OutlinedButton(
                      onPressed: _busy ? null : () => _cancel(r['id'] as int),
                      child: const Text('Cancel'),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChallengesTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  const ChallengesTab({super.key, required this.onSelectTab});

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: _AppDrawer(
        onSelectTab: widget.onSelectTab,
        currentScreenIndex: 2, // Challenges tab
      ),
      appBar: AppBar(
        title: const Text('Challenges'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Complete Challenges',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Earn badges, profile borders, and cover photo borders by completing daily and weekly challenges.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Coming soon section
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Badge Challenges',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Unlock special badges by completing challenges',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.border_color,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Border Challenges',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Earn decorative borders for your profile picture',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.image,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cover Photo Border Challenges',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unlock special borders for your cover photo',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Load current user profile for drawer header (optimized version)
/// Offline-first: Loads from local DB first, then optionally fetches from cloud if avatar missing
/// This version prioritizes showing local data immediately
Future<UserProfile?> _loadCurrentUserProfileOptimized() async {
  try {
    final userId = SupabaseService().currentUserId;
    if (userId == null) return null;
    
    final db = DatabaseService();
    
    // STEP 1: Load from local DB first (fast, instant, works offline)
    final localProfile = await db.getUserProfile(userId);
    
    // STEP 2: If online and avatarUrl is missing/null/empty, fetch from cloud in background
    final supabaseService = SupabaseService();
    final isConnected = await supabaseService.isConnected();
    
    if (isConnected && (localProfile == null || localProfile.avatarUrl == null || localProfile.avatarUrl!.isEmpty)) {
      // Fetch from cloud in background (non-blocking)
      try {
        final cloudProfile = await supabaseService.getUserProfile(userId);
        if (cloudProfile != null) {
          // Cache cloud profile locally for offline access
          await db.insertUserProfile(cloudProfile);
          return cloudProfile; // Return updated profile with avatar
        }
      } catch (e) {
        print('Supabase profile fetch failed, using local: $e');
        // Continue with local profile if cloud fetch fails
      }
    }
    
    // Return local profile (either found in step 1, or cloud fetch failed/not needed)
    return localProfile;
  } catch (e) {
    print('Error loading current user profile: $e');
    // Last resort: try local DB even if there was an error
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        return await DatabaseService().getUserProfile(userId);
      }
    } catch (_) {
      // Ignore errors in fallback
    }
    return null;
  }
}

/// App-wide navigation drawer used across tabs
class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  final int currentScreenIndex;
  
  const _AppDrawer({
    required this.onSelectTab,
    this.currentScreenIndex = 0, // Default to Dashboard
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.75; // 75% of screen width
    
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header section
            _buildProfileHeader(context),
            _buildNavItem(
              context: context,
              icon: Icons.dashboard,
              title: 'Dashboard',
              index: 0,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(0);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.leaderboard,
              title: 'Rankings',
              index: 1,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(1);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.group,
              title: 'Friends',
              index: 100,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(100);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings,
              title: 'Account Settings',
              index: 200,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(200);
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                context: context,
                  useRootNavigator: true,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!context.mounted) return;
                        showDialog(
                          context: context,
                    useRootNavigator: true,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        try {
                          await UserSessionManager().logoutCurrentUser();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // close loading
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logout error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile header at top of drawer
  /// Shows local profile immediately, then updates from cloud if avatar missing
  Widget _buildProfileHeader(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _loadCurrentUserProfileOptimized(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        
        // Calculate XP progress
        int? level;
        double? progress;
        Map<String, int>? levelProgress;
        
        if (profile != null) {
          level = profile.level;
          progress = profile.progressToNextLevel;
          levelProgress = profile.currentLevelProgress;
        }
        
        final currentLevel = level ?? 1;
        final currentProgress = (progress ?? 0.0).clamp(0.0, 1.0);
        final xpInCurrentLevel = levelProgress?['currentLevelXP'] ?? 0;
        final xpNeededForNextLevel = levelProgress?['requiredForNextLevel'] ?? 100;
        
        return InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentProfileScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarWidget.medium(
                      avatarUrl: profile?.avatarUrl,
                      fullName: profile?.fullName,
                      size: 56.0,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile?.fullName ?? 'Loading...',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (profile?.userTag != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${profile!.userTag}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // XP Progress Bar
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Level $currentLevel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = currentScreenIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        onTap: onTap,
      ),
    );
  }
}

/// Custom debug button widget with icon and responsive design
class _DebugButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final bool isDestructive;

  const _DebugButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontScale = ResponsiveUtils.getFontScale(context);
    
    return SizedBox(
      height: 40 + (fontScale - 1) * 8, // Responsive height
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: ResponsiveUtils.getIconSize(context, mobile: 16, tablet: 18, desktop: 20),
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12 * fontScale,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive 
            ? Colors.red.shade100 
            : Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: isDestructive 
            ? Colors.red.shade700 
            : Theme.of(context).colorScheme.onPrimaryContainer,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
