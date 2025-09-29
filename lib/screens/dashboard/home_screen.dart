import 'package:flutter/material.dart';
import 'dart:async';
import '../auth/login_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/automatic_screen_tracker.dart';
import '../../services/improved_sync_service.dart';
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

class HomeScreen extends StatefulWidget {
  final bool isNewUser;
  const HomeScreen({super.key, this.isNewUser = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isNewUser = false;

  List<Widget> get _screens => [
    DashboardTab(
      isNewUser: _isNewUser,
      onSelectTab: _handleSelectTab,
    ),
    RankingsTab(
      onSelectTab: _handleSelectTab,
    ),
    ProfileTab(
      onSelectTab: _handleSelectTab,
    ),
  ];

  void _handleSelectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _isNewUser = widget.isNewUser;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
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
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  final bool isNewUser;
  final ValueChanged<int> onSelectTab;
  const DashboardTab({super.key, this.isNewUser = false, required this.onSelectTab});

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
    _startRefreshTimer();
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

  void _startRefreshTimer() {
    // Adjust interval based on connectivity
    final interval = Duration(seconds: 5);  // 5 seconds
    SimplifiedLogger.info('Starting ${interval.inSeconds}-second refresh timer (offline: $_isOffline)');
    _refreshTimer = Timer.periodic(interval, (_) {
      SimplifiedLogger.verbose('${interval.inSeconds}-second refresh tick triggered');
      _onRefreshTick();
    });
  }

  Future<void> _onRefreshTick() async {
  try {
    print('⏰ Dashboard refresh - updating data (offline: $_isOffline)');
    
    // Add timeout to prevent hanging
    // Check for end of day first
    await _automaticTracker.checkForEndOfDay();
    
    // Refresh tracker data
    await _automaticTracker.refreshTodayData();
    
    // Reload background service data
    await PersistentTrackerService.reloadTodayData();
    
    // Only perform sync if online
    if (!_isOffline) {
      await ImprovedSyncService().performSync();
    } else {
      print('📱 Skipping sync - offline mode');
    }
    
    if (mounted) {
      setState(() {});
      print('🔄 Dashboard UI updated');
    }
  } catch (e) {
    print('❌ Error in refresh (timeout or other): $e');
    // Still update UI even if refresh fails
    if (mounted) {
      setState(() {});
    }
  }
}

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
      
      // Refresh tracker data
      await _automaticTracker.refreshTodayData();
      
      // Perform sync
      await ImprovedSyncService().performSync();
      
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
    return Scaffold(
      drawer: _AppDrawer(onSelectTab: widget.onSelectTab),
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
              await _comprehensiveRefresh();
              if (mounted) setState(() {});
            },
            child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.getMaxContentWidth(context),
              ),
              child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
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
            _buildLegendItem(context, '4-6 hours', '50 XP', 'Good ��', Colors.orange),
            _buildLegendItem(context, '6-8 hours', '25 XP', 'Fair 🥉', Colors.deepOrange),
            _buildLegendItem(context, '8-10 hours', '10 XP', 'High ⚠️', Colors.red),
            _buildLegendItem(context, '10+ hours', '0 XP', 'Excessive ��', Colors.red.shade800),
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
                    Text(
                      'Level ${currentLevel + 1}',
                      style: TextStyle(fontSize: 14 * fontScale),
                    ),
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

class RankingsTab extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  const RankingsTab({super.key, required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(onSelectTab: onSelectTab),
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            SizedBox(height: 200),
            Center(
        child: Text(
          'Rankings Coming Soon!',
          style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  const ProfileTab({super.key, required this.onSelectTab});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserProfile? _profile;
  String? _deptName;
  bool _loading = true;
  final _tagController = TextEditingController();
  String? _availabilityMsg;
  bool _checking = false;
  bool _saving = false;

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        setState(() { _loading = false; });
        return;
      }

      UserProfile? profile;
      // Try Supabase first
      try { profile = await SupabaseService().getUserProfile(userId); } catch (_) {}
      // Fallback to local DB
      profile ??= await DatabaseService().getUserProfile(userId);

      String? deptName;
      if (profile?.departmentId != null) {
        // Try cache first
        deptName = await DatabaseService().getDepartmentName(profile!.departmentId!);
        // Try cloud and cache
        deptName ??= await SupabaseService().getDepartmentNameById(profile.departmentId!);
      }

      setState(() {
        _profile = profile;
        _deptName = deptName;
        _tagController.text = profile?.userTag ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _AppDrawer(onSelectTab: widget.onSelectTab),
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfile();
          if (mounted) setState(() {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_profile == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No profile found')),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _kv('Full name', _profile!.fullName),
                      _kv('Email', _profile!.email),
                      _kv('Role', _profile!.role),
                      _kv('Department', _deptName ?? (_profile!.departmentId?.toString() ?? '—')),
                      _kv('User tag', _profile!.userTag ?? '—'),
                    ],
                  ),
                ),
              ),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Tag',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1–15 letters + up to 4 digits. Case-insensitive unique.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'Enter your tag (e.g., Alice7)',
                        suffixIcon: _checking ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ) : (_availabilityMsg == null
                          ? null
                          : Icon(
                              _availabilityMsg!.startsWith('Available') ? Icons.check_circle : Icons.error,
                              color: _availabilityMsg!.startsWith('Available') ? Colors.green : Colors.red,
                            )),
                      ),
                      onChanged: (value) async {
                        setState(() {
                          _availabilityMsg = null;
                          _checking = true;
                        });
                        await Future.delayed(const Duration(milliseconds: 350));
                        final svc = SupabaseService();
                        if (!svc.isValidUserTag(value)) {
                          setState(() {
                            _availabilityMsg = 'Invalid format';
                            _checking = false;
                          });
                          return;
                        }
                        final ok = await svc.isUserTagAvailable(value);
                        setState(() {
                          _availabilityMsg = ok ? 'Available' : 'Already taken';
                          _checking = false;
                        });
                      },
                    ),
                    if (_availabilityMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _availabilityMsg!,
                        style: TextStyle(
                          color: _availabilityMsg!.startsWith('Available') ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () async {
                          final tag = _tagController.text.trim();
                          final svc = SupabaseService();
                          if (!svc.isValidUserTag(tag)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid tag format')),
                            );
                            return;
                          }
                          setState(() { _saving = true; });
                          final ok = await svc.updateCurrentUserTag(tag);
                          setState(() { _saving = false; });
                          if (!mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User tag updated')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not update user tag')),
                            );
                          }
                        },
                        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                        label: const Text('Save Tag'),
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

Widget _kv(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}

/// App-wide navigation drawer used across tabs
class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  const _AppDrawer({required this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'TRIminder',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: const Text('Rankings'),
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(2);
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
