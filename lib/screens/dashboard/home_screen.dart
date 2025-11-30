import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../services/persistent_tracker_service.dart';
import '../../services/database_service.dart';
import '../../utils/simplified_logger.dart';
import '../../widgets/app_scaffold.dart';
import '../../utils/app_hibernation_helper.dart';
import '../../utils/battery_optimization_helper.dart';
import '../../utils/usage_stats_helper.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../profile/student_profile_screen.dart';
import '../../models/app_usage_models.dart';
import '../../services/usage_stats_service.dart';
import '../../models/badge_models.dart' as badge_models;
import '../../models/challenge_models.dart' as challenge_models;
import '../badges/badge_catalog_screen.dart';
import '../../services/badge_service.dart';
import '../../services/challenge_service.dart';
import '../../utils/badge_icon_helper.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Widget> get _screens => [
    DashboardTab(
      isNewUser: _isNewUser,
      onSelectTab: _handleSelectTab,
      currentIndex: _currentIndex,
      scaffoldKey: _scaffoldKey,
    ),
    RankingsTab(
      onSelectTab: _handleSelectTab,
      scaffoldKey: _scaffoldKey,
    ),
    ChallengesTab(
      onSelectTab: _handleSelectTab,
      scaffoldKey: _scaffoldKey,
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
              // Wait a bit before showing next dialog
              await Future.delayed(const Duration(milliseconds: 300));
            }
          }
          
          if (mounted) {
            // Finally check UsageStats permission (for per-app tracking)
            final usageStatsPending = await UsageStatsHelper.isPromptPending();
            if (usageStatsPending) {
              // showUsageStatsDialog already clears the pending flag internally
              await UsageStatsHelper.showUsageStatsDialog(context);
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        onSelectTab: _handleSelectTab,
        currentScreenIndex: _showFriends ? 100 : (_showSettings ? 200 : _currentIndex),
      ),
      drawerEdgeDragWidth: screenWidth,
      body: _showFriends
          ? FriendsTab(onSelectTab: _handleSelectTab, scaffoldKey: _scaffoldKey)
          : _showSettings
              ? SettingsScreen(onSelectTab: _handleSelectTab, scaffoldKey: _scaffoldKey)
          : _screens[_currentIndex],
      bottomNavigationBar: Stack(
        children: [
          // Background layer with pale accent color to fill the corners
          Positioned.fill(
            child: Container(
              color: const Color(0xFFFDE8E9), // Same pale accent as body background
            ),
          ),
          // Actual bottom nav bar with rounded corners
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFa92d35), // Accent color
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: Colors.transparent, // Transparent to show container color
              elevation: 0, // Remove shadow
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white60,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                _showFriends = false;
                _showSettings = false;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.home),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.leaderboard),
                ),
                label: 'Rankings',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.emoji_events),
                ),
                label: 'Challenges',
              ),
            ],
          ),
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
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const DashboardTab({
    super.key, 
    this.isNewUser = false, 
    required this.onSelectTab,
    this.currentIndex = 0,
    this.scaffoldKey,
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
  final GlobalKey<_TopOffendersCardState> _topOffendersKey = GlobalKey<_TopOffendersCardState>();
  final GlobalKey<_UsageGraphWidgetState> _usageGraphKey = GlobalKey<_UsageGraphWidgetState>();
  bool _isStatusBarHidden = false;

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


  @override
  void dispose() {
    // Restore status bar when leaving
    if (_isStatusBarHidden) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    ImprovedSyncService().clearSyncCompleteCallback();
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      
      // Hide only status bar when scrolled down (keep bottom nav visible)
      if (currentOffset >= 50 && !_isStatusBarHidden) {
        _isStatusBarHidden = true;
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.bottom], // Hide status bar only, keep bottom
        );
      }
      // Show status bar when scrolled back to top
      else if (currentOffset < 10 && _isStatusBarHidden) {
        _isStatusBarHidden = false;
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom], // Show all
        );
      }
    }
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
      
      // Check for end of day XP awards before refreshing tracker data
      await _automaticTracker.checkForEndOfDay();
      
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
        
        // Check for end of day XP awards after profile is loaded
        await _automaticTracker.checkForEndOfDay();
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
      // Combined Greeting + Level Progress Card (includes avatar and notification - acts as AppBar)
      _GreetingLevelCard(
        userProfile: userProfile,
        onAvatarTap: () => widget.scaffoldKey?.currentState?.openDrawer(),
        onNotificationTap: () {
          // TODO: Show notifications
        },
      ),
      
      // Usage Graph
      _UsageGraphWidget(key: _usageGraphKey),
      
      // Screen Time and Pickup cards side by side
      const Row(
        children: [
          Expanded(child: _ScreenTimeCard()),
          SizedBox(width: 12),
          Expanded(child: _PickupCard()),
        ],
      ),
      
      // Main Offenders List (App Usage)
      TopOffendersCard(key: _topOffendersKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Pale version of accent color as background
    const bgColor = Color(0xFFFDE8E9); // Pale red/pink based on accent #a92d35
    
    // Set status bar style for dark background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Light icons for dark background
      statusBarBrightness: Brightness.dark,
    ));
    
    return AppScaffold(
      drawerGestureEnabled: false,
      extendBodyBehindAppBar: false,
      backgroundColor: bgColor,
      body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleScroll(notification);
              return false;
            },
            child: NestedScrollView(
              // Always allow scrolling for pull-to-refresh
              physics: const AlwaysScrollableScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // No SliverAppBar - avatar and notification are now part of the XP card
              // This allows the XP card and its header to scroll together as one unit
            ],
            body: RefreshIndicator(
                  color: const Color(0xFFa92d35), // Accent color
                  onRefresh: () async {
                    final coordinator = SyncCoordinator();
                    coordinator.requestSync(() => ImprovedSyncService().performSync());
                    await _automaticTracker.refreshTodayData();
                    // Refresh usage graph
                    await _usageGraphKey.currentState?.refresh();
                    // Refresh top offenders list (queries UsageStats directly - always fresh)
                    _topOffendersKey.currentState?.refresh();
                    if (mounted) setState(() {});
                  },
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveUtils.getMaxContentWidth(context),
                      ),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 0, // First card goes full width
                          right: 0,
                          top: 0, // No gap between AppBar and first card
                          bottom: 0, // No extra bottom padding - Main Offenders is edge to edge
                        ),
                        itemCount: _getDashboardWidgets().length,
                        separatorBuilder: (context, index) {
                          // No gap between XP card (index 0) and Graph (index 1)
                          if (index == 0) return const SizedBox.shrink();
                          // Even gap of 12 between other cards
                          return const SizedBox(height: 12);
                        },
                        itemBuilder: (context, index) {
                          final widget = _getDashboardWidgets()[index];
                          final widgetCount = _getDashboardWidgets().length;
                          // First item (XP card) goes full width
                          if (index == 0) {
                            return widget;
                          }
                          // Second item (Graph card) overlaps XP card with negative margin
                          if (index == 1) {
                            return Transform.translate(
                              offset: const Offset(0, -90),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveUtils.getScreenPadding(context).left,
                                ),
                                child: widget,
                              ),
                            );
                          }
                          // Last item (Main Offenders) - edge to edge, no horizontal padding
                          if (index == widgetCount - 1) {
                            return Transform.translate(
                              offset: const Offset(0, -90),
                              child: widget,
                            );
                          }
                          // Other items (Screen Time / Pickup row) with horizontal padding
                          return Transform.translate(
                            offset: const Offset(0, -90),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.getScreenPadding(context).left,
                              ),
                              child: widget,
                            ),
                          );
                        },
                      ),
                    ),
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
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFa92d35),
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

class TopOffendersCard extends StatefulWidget {
  const TopOffendersCard({super.key});

  @override
  State<TopOffendersCard> createState() => _TopOffendersCardState();
}

class _TopOffendersCardState extends State<TopOffendersCard> with TickerProviderStateMixin {
  List<AppUsageEntry> _topApps = [];
  Map<String, String?> _appIcons = {}; // Cache app icons: packageName -> base64
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _hasData = false;
  
  // Animation controllers for staggered slide-up effect
  final List<AnimationController> _itemAnimationControllers = [];
  final List<Animation<double>> _itemAnimations = [];
  
  // Title animation
  late AnimationController _titleAnimationController;
  late Animation<double> _titleAnimation;

  @override
  void initState() {
    super.initState();
    _titleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _titleAnimation = CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeOutCubic,
    );
    _loadTopApps();
  }
  
  @override
  void dispose() {
    _titleAnimationController.dispose();
    for (final controller in _itemAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  void _initializeAnimations(int itemCount) {
    // Dispose existing controllers
    for (final controller in _itemAnimationControllers) {
      controller.dispose();
    }
    _itemAnimationControllers.clear();
    _itemAnimations.clear();
    
    // Create new controllers for each item
    for (int i = 0; i < itemCount; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      _itemAnimationControllers.add(controller);
      _itemAnimations.add(animation);
    }
    
    // Start staggered animations - rank 1 first, then others
    for (int i = 0; i < itemCount; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (mounted && i < _itemAnimationControllers.length) {
          _itemAnimationControllers[i].forward();
        }
      });
    }
  }

  void refresh() {
    _loadTopApps();
  }

  Future<void> _loadTopApps() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if UsageStats permission is granted
      final hasPermission = await UsageStatsHelper.isUsageStatsPermissionGranted();
      
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
            _hasData = false;
          });
        }
        return;
      }

      _hasPermission = true;

      // Get current user ID (needed for AppUsageEntry model)
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasData = false;
          });
        }
        return;
      }

      // Get today's date
      final today = DateTime.now();
      
      // Query UsageStats directly for today's app usage (fresh data)
      final usageMap = await UsageStatsService.getAppUsageForDate(today);
      
      // Convert to AppUsageEntry list
      final topApps = <AppUsageEntry>[];
      
      for (final entry in usageMap.entries) {
        final packageName = entry.key;
        final usageMinutes = entry.value;
        
        if (usageMinutes <= 0) continue;
        
        // Get app name
        final appName = await UsageStatsService.getAppName(packageName);
        
        topApps.add(AppUsageEntry(
          userId: userId,
          packageName: packageName,
          appName: appName,
          usageMinutes: usageMinutes,
          date: today,
          createdAt: DateTime.now(),
        ));
      }
      
      // Sort by usage minutes (descending) and take top 10
      topApps.sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
      final top10Apps = topApps.take(10).toList();

      // Load app icons for top apps
      final iconMap = <String, String?>{};
      for (final app in top10Apps) {
        try {
          final iconBase64 = await UsageStatsService.getAppIconBase64(app.packageName);
          iconMap[app.packageName] = iconBase64;
        } catch (e) {
          print('Error loading icon for ${app.packageName}: $e');
          iconMap[app.packageName] = null;
        }
      }

      if (mounted) {
        setState(() {
          _topApps = top10Apps;
          _appIcons = iconMap;
          _hasData = top10Apps.isNotEmpty;
          _isLoading = false;
        });
        // Start title animation first, then staggered item animations
        _titleAnimationController.forward();
        if (top10Apps.isNotEmpty) {
          _initializeAnimations(top10Apps.length);
        }
      }
    } catch (e) {
      print('Error loading top apps: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasData = false;
        });
      }
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }

  Widget _buildAppIcon(BuildContext context, String packageName) {
    final iconBase64 = _appIcons[packageName];
    const double iconSize = 40;
    
    if (iconBase64 != null && iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(iconBase64);
        return Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderIcon(context, iconSize);
              },
            ),
          ),
        );
      } catch (e) {
        print('Error decoding app icon for $packageName: $e');
        return _buildPlaceholderIcon(context, iconSize);
      }
    }
    
    return _buildPlaceholderIcon(context, iconSize);
  }

  Widget _buildPlaceholderIcon(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.apps,
        size: size * 0.55,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontScale = ResponsiveUtils.getFontScale(context);
    
    return Container(
      // Transparent background, no shadow
      color: Colors.transparent,
      child: Padding(
        // Extra bottom padding to extend to bottom nav bar (compensates for negative transforms)
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _titleAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - _titleAnimation.value)),
                  child: Opacity(
                    opacity: _titleAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  const SizedBox(width: 8), // Extra left padding
                  Text(
                    'Today\'s Offenders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const SizedBox.shrink() // No skeleton, just wait for animated items
            else if (!_hasPermission)
              _buildPermissionPrompt(context, fontScale)
            else if (!_hasData)
              _buildNoDataMessage(context, fontScale)
            else
              _buildAppList(context, fontScale),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPrompt(BuildContext context, double fontScale) {
    return InkWell(
      onTap: () => _showPermissionInfo(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insights_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable App Usage Tracking',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'See which apps you use most',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(BuildContext context, double fontScale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getSpacing(context, mobile: 24, tablet: 32, desktop: 48)),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_android_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            Text(
              'No usage data',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Start using apps to see your top offenders',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppList(BuildContext context, double fontScale) {
    const accentColor = Color(0xFFa92d35);
    
    return Column(
      children: _topApps.asMap().entries.map((entry) {
        final index = entry.key;
        final app = entry.value;
        final isLast = index == _topApps.length - 1;
        
        // Format rank with leading zero: 01, 02, ... 09, 10
        final rankText = (index + 1).toString().padLeft(2, '0');
        
        // Get animation for this index (with bounds check)
        final hasAnimation = index < _itemAnimations.length;
        
        // Each app in its own white card with shadow - closer gaps
        Widget cardContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ranking number with leading zero
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index < 3 
                      ? accentColor.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rankText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: index < 3 ? accentColor : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // App icon
              _buildAppIcon(context, app.packageName),
              const SizedBox(width: 12),
              
              // App name
              Expanded(
                child: Text(
                  app.appName ?? app.packageName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Usage time on right
              Text(
                _formatDuration(app.usageMinutes),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
        
        // Wrap with animation if available
        if (hasAnimation) {
          cardContent = AnimatedBuilder(
            animation: _itemAnimations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - _itemAnimations[index].value)), // Slide from bottom
                child: Opacity(
                  opacity: _itemAnimations[index].value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: cardContent,
          );
        }
        
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
          child: cardContent,
        );
      }).toList(),
    );
  }

  void _showPermissionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Usage Tracking'),
        content: const Text(
          'To see which apps you use most, TRIminder needs Usage Access permission.\n\n'
          'This enables the "Top Offenders List" feature to help you understand your digital habits.\n\n'
          'Your app usage data stays on your device and is never synced to the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final launched = await UsageStatsHelper.requestUsageStatsPermission();
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open settings. Please enable Usage Access manually in Settings → Apps → Special app access → Usage access'),
                    duration: Duration(seconds: 5),
                  ),
                );
              } else {
                // Reload data after permission is potentially granted
                await Future.delayed(const Duration(milliseconds: 500));
                _loadTopApps();
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

// ============ NEW DASHBOARD WIDGETS ============

/// Combined Greeting + Level Progress Card
class _GreetingLevelCard extends StatefulWidget {
  final UserProfile? userProfile;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationTap;
  
  const _GreetingLevelCard({
    this.userProfile,
    this.onAvatarTap,
    this.onNotificationTap,
  });

  @override
  State<_GreetingLevelCard> createState() => _GreetingLevelCardState();
}

class _GreetingLevelCardState extends State<_GreetingLevelCard> 
    with SingleTickerProviderStateMixin {
  late AutomaticScreenTracker _tracker;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _progressAnimation;
  int? totalXP;
  int? level;
  double? progress;
  Map<String, int>? levelProgress;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    
    // Setup dropdown and progress bar animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    
    _updateXPData();
    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_GreetingLevelCard oldWidget) {
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

  String _getFirstName() {
    final fullName = widget.userProfile?.fullName ?? 'Student';
    return fullName.split(' ').first;
  }

  int _getProgressPercent() {
    final p = progress ?? widget.userProfile?.progressToNextLevel ?? 0.0;
    return (p * 100).round();
  }

  void _showXPInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('XP System'),
        content: const Text(
          'Earn XP daily based on your screen time:\n\n'
          '• ≤2 hours: 100 XP\n'
          '• 2-4 hours: 75 XP\n'
          '• 4-6 hours: 50 XP\n'
          '• 6-8 hours: 25 XP\n'
          '• 8-10 hours: 10 XP\n'
          '• 10+ hours: 0 XP\n\n'
          'Less screen time = More XP!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = level ?? widget.userProfile?.level ?? 1;
    final currentProgress = progress ?? widget.userProfile?.progressToNextLevel ?? 0.0;
    const accentColor = Color(0xFFa92d35);

    // Get status bar height for proper padding
    final statusBarHeight = MediaQuery.of(context).padding.top;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * -50), // Dropdown animation
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: statusBarHeight + 12, // Status bar + padding
          bottom: 100, // Extended bottom so Graph card overlaps
        ),
        decoration: BoxDecoration(
          color: accentColor, // Accent color background
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFd4777c), // Light accent color shadow
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 0: Avatar (left) + Notification (right) - acts as AppBar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onAvatarTap,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFffc542),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.userProfile?.avatarUrl != null
                        ? NetworkImage(widget.userProfile!.avatarUrl!)
                        : null,
                    child: widget.userProfile?.avatarUrl == null
                        ? Text(
                            widget.userProfile?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              color: Color(0xFFa92d35),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: widget.onNotificationTap,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 1: Hello, Name (left) + LEVEL X (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Hello, ${_getFirstName()}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                  color: Colors.white,
                ),
              ),
              Text(
                'LEVEL $currentLevel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white, // White text
                ),
              ),
            ],
          ),
          // Row 2: Your progress + info icon (left) + percentage (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your progress',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70, // Semi-transparent white
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showXPInfo(context),
                    child: const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.white70, // Semi-transparent white
                    ),
                  ),
                ],
              ),
              // Animated percentage counter
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  final animatedPercent = (_getProgressPercent() * _progressAnimation.value).round();
                  return Text(
                    '$animatedPercent%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Animated progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              final animatedProgress = currentProgress * _progressAnimation.value;
              return Stack(
                children: [
                  // Unfilled bar (background)
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Filled bar (foreground) - gradient golden
                  FractionallySizedBox(
                    widthFactor: animatedProgress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFffc542),
                            Color(0xFFFFE066),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFffc542).withOpacity(0.4),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
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
        );
      },
    );
  }
}

/// Screen Time Card widget
class _ScreenTimeCard extends StatefulWidget {
  const _ScreenTimeCard();

  @override
  State<_ScreenTimeCard> createState() => _ScreenTimeCardState();
}

class _ScreenTimeCardState extends State<_ScreenTimeCard> 
    with SingleTickerProviderStateMixin {
  late AutomaticScreenTracker _tracker;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // Slide from left animation - same as Graph
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFa92d35);
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-100 * (1 - _slideAnimation.value), 0), // Slide from left
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFFFF5F5), // Very light pink tint
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFfffff), // Gold border
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Tilted icon on the right
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Transform.rotate(
                      angle: 0.3, // Slight tilt
                      child: Icon(
                        Icons.phone_android,
                        size: 80,
                        color: accentColor.withOpacity(0.12),
                      ),
                    ),
                  ),
                  // Left-aligned content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Screen Time',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Animated screen time - left aligned
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.5 + (_slideAnimation.value * 0.5),
                            alignment: Alignment.centerLeft,
                            child: Opacity(
                              opacity: _slideAnimation.value,
                              child: Text(
                                _tracker.todayScreenTime,
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                  height: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Today label - left aligned
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Today',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pickup Card widget showing daily phone pickups
class _PickupCard extends StatefulWidget {
  const _PickupCard();

  @override
  State<_PickupCard> createState() => _PickupCardState();
}

class _PickupCardState extends State<_PickupCard> 
    with SingleTickerProviderStateMixin {
  late AutomaticScreenTracker _tracker;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // Slide from left animation - same as Graph (staggered after Screen Time card)
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFa92d35);
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-100 * (1 - _slideAnimation.value), 0), // Slide from left
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFc13d45), // Lighter accent
                    Color(0xFFa92d35), // Main accent
                    Color(0xFF8a2329), // Darker accent
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFa92d35), // Gold border
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Tilted icon on the right
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Transform.rotate(
                      angle: -0.3, // Slight tilt opposite direction
                      child: Icon(
                        Icons.touch_app,
                        size: 80,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  ),
                  // Left-aligned content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickups',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70, // White text for accent background
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Animated pickup count - left aligned
                      AnimatedBuilder(
                        animation: _slideAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 0.5 + (_slideAnimation.value * 0.5),
                            alignment: Alignment.centerLeft,
                            child: Opacity(
                              opacity: _slideAnimation.value,
                              child: Text(
                                '${_tracker.todayPickupCount}',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                  height: 1,
                                  color: Colors.white, // White text
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Today label - left aligned
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2), // Semi-transparent white
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Today',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white, // White text
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Usage graph widget showing screen time over hours
class _UsageGraphWidget extends StatefulWidget {
  const _UsageGraphWidget({super.key});

  @override
  State<_UsageGraphWidget> createState() => _UsageGraphWidgetState();
}

class _UsageGraphWidgetState extends State<_UsageGraphWidget> 
    with TickerProviderStateMixin {
  late AutomaticScreenTracker _tracker;
  late AnimationController _slideController;
  late AnimationController _lineController;
  late Animation<double> _slideAnimation;
  late Animation<double> _lineAnimation;
  List<double> _weeklyData = List.filled(7, 0.0); // Current week data
  List<double> _lastWeekData = List.filled(7, 0.0); // Last week data
  
  static const List<String> _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    
    // Setup slide animation for card
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    
    // Setup line animation (starts after slide completes)
    _lineController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _lineAnimation = CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeOutCubic,
    );
    
    // Start slide animation after delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _slideController.forward();
    });
    
    _loadWeeklyData();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _lineController.dispose();
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      _loadWeeklyData();
      setState(() {});
    }
  }

  /// Public method to refresh graph data
  Future<void> refresh() async {
    await _loadWeeklyData();
  }
  
  Future<void> _loadWeeklyData() async {
    try {
      final weeklyUsage = await _tracker.getWeeklyUsage();
      final lastWeekUsage = await _tracker.getLastWeekUsage();
      if (mounted) {
        setState(() {
          _weeklyData = weeklyUsage;
          _lastWeekData = lastWeekUsage;
        });
        // Start line animation after slide completes
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _lineController.reset();
            _lineController.forward();
          }
        });
      }
    } catch (e) {
      // Use sample data if loading fails
    }
  }
  
  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
  
  int _getTodayIndex() {
    return DateTime.now().weekday % 7; // Sunday = 0
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFa92d35);
    
    final todayIndex = _getTodayIndex();
    
    // Use live screen time for today (includes current session), database values for other days
    final liveWeeklyData = List<double>.from(_weeklyData);
    liveWeeklyData[todayIndex] = _tracker.todayScreenTimeMinutes.toDouble();
    
    // Get max usage for scaling
    final maxUsage = liveWeeklyData.reduce((a, b) => a > b ? a : b);
    final normalizedData = maxUsage > 0 
        ? liveWeeklyData.map((v) => v / maxUsage).toList()
        : List.filled(7, 0.0);
    
    // Normalize last week data using same max for fair comparison
    final combinedMax = [maxUsage, _lastWeekData.reduce((a, b) => a > b ? a : b)].reduce((a, b) => a > b ? a : b);
    final normalizedLastWeek = combinedMax > 0 
        ? _lastWeekData.map((v) => v / combinedMax).toList()
        : List.filled(7, 0.0);
    final normalizedCurrentWeek = combinedMax > 0 
        ? liveWeeklyData.map((v) => v / combinedMax).toList()
        : List.filled(7, 0.0);
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(-100 * (1 - _slideAnimation.value), 0), // Slide from left
          child: Opacity(
            opacity: _slideAnimation.value.clamp(0.0, 1.0),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF232525), // Dark charcoal
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Animated Graph
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _lineAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                    painter: _UsageGraphPainter(
                      context: context,
                      accentColor: accentColor,
                      weeklyData: normalizedCurrentWeek,
                      lastWeekData: normalizedLastWeek,
                      todayIndex: todayIndex,
                      animationProgress: _lineAnimation.value,
                    ),
                  );
                },
              ),
            ),
              // Current week info box (always visible) - top left
              Positioned(
                left: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dayLabels[todayIndex],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(_tracker.todayScreenTimeMinutes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Last week info box (always visible) - top right
              Positioned(
                right: 12,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Last ${_dayLabels[todayIndex]}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDuration(_lastWeekData[todayIndex].toInt()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Day labels at bottom
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _dayLabels.asMap().entries.map((entry) {
                    final isToday = entry.key == todayIndex;
                    return Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                            ? const Color(0xFFffc542) // Golden for today
                            : Colors.white.withOpacity(0.6),
                      ),
                    );
                  }).toList(),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UsageGraphPainter extends CustomPainter {
  final BuildContext context;
  final Color accentColor;
  final List<double> weeklyData;
  final List<double> lastWeekData;
  final int todayIndex;
  final double animationProgress;

  _UsageGraphPainter({
    required this.context, 
    required this.accentColor,
    required this.weeklyData,
    required this.lastWeekData,
    required this.todayIndex,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Leave space at bottom for labels and padding on sides to align with day labels
    final graphHeight = size.height - 35;
    final topPadding = 20.0;
    final horizontalPadding = 25.0; // Match day labels padding
    final graphWidth = size.width - (horizontalPadding * 2);
    
    // Draw grid lines - lighter for dark background
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal grid lines (4 lines)
    for (var i = 0; i < 4; i++) {
      final y = topPadding + (graphHeight - topPadding) * (i / 3);
      canvas.drawLine(
        Offset(horizontalPadding, y),
        Offset(size.width - horizontalPadding, y),
        gridPaint,
      );
    }

    // Vertical grid lines (7 lines for each day)
    for (var i = 0; i < 7; i++) {
      final x = horizontalPadding + (i / 6) * graphWidth;
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, graphHeight),
        gridPaint,
      );
    }
    
    // Define golden color for lines
    const goldenColor = Color(0xFFffc542);

    // Last week line paint - pale white
    final lastWeekLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Current week line - golden
    final linePaint = Paint()
      ..color = goldenColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw last week line first (behind current week)
    final lastWeekPoints = <Offset>[];
    for (var i = 0; i < lastWeekData.length; i++) {
      final x = horizontalPadding + (i / (lastWeekData.length - 1)) * graphWidth;
      final normalizedValue = lastWeekData[i].clamp(0.0, 1.0);
      final y = topPadding + (graphHeight - topPadding) * (1.0 - normalizedValue);
      lastWeekPoints.add(Offset(x, y));
    }

    if (lastWeekPoints.isNotEmpty) {
      final lastWeekPath = Path();
      lastWeekPath.moveTo(lastWeekPoints.first.dx, lastWeekPoints.first.dy);
      
      for (var i = 0; i < lastWeekPoints.length - 1; i++) {
        final current = lastWeekPoints[i];
        final next = lastWeekPoints[i + 1];
        final controlPoint1 = Offset(
          current.dx + (next.dx - current.dx) / 3,
          current.dy,
        );
        final controlPoint2 = Offset(
          current.dx + 2 * (next.dx - current.dx) / 3,
          next.dy,
        );
        lastWeekPath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
      }
      
      // Animate last week line drawing
      final lastWeekMetrics = lastWeekPath.computeMetrics().first;
      final animatedLastWeekPath = lastWeekMetrics.extractPath(
        0, 
        lastWeekMetrics.length * animationProgress,
      );
      canvas.drawPath(animatedLastWeekPath, lastWeekLinePaint);
    }

    // Current week points
    final points = <Offset>[];
    for (var i = 0; i < weeklyData.length; i++) {
      final x = horizontalPadding + (i / (weeklyData.length - 1)) * graphWidth;
      final normalizedValue = weeklyData[i].clamp(0.0, 1.0);
      final y = topPadding + (graphHeight - topPadding) * (1.0 - normalizedValue);
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // Create smooth curve for current week
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlPoint1 = Offset(
        current.dx + (next.dx - current.dx) / 3,
        current.dy,
      );
      final controlPoint2 = Offset(
        current.dx + 2 * (next.dx - current.dx) / 3,
        next.dy,
      );
      linePath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        next.dx, next.dy,
      );
    }

    // Animate current week line drawing
    final lineMetrics = linePath.computeMetrics().first;
    final animatedLinePath = lineMetrics.extractPath(
      0, 
      lineMetrics.length * animationProgress,
    );
    
    // Get the current end point of animated line for fill
    final currentEndX = horizontalPadding + (animationProgress * graphWidth);
    
    // Create animated filled area path
    final fillPaint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          goldenColor.withOpacity(0.4 * animationProgress),
          goldenColor.withOpacity(0.1 * animationProgress),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, graphHeight));
    
    final fillPath = Path.from(animatedLinePath);
    final lastPoint = lineMetrics.getTangentForOffset(lineMetrics.length * animationProgress)?.position;
    if (lastPoint != null) {
      fillPath.lineTo(lastPoint.dx, graphHeight);
      fillPath.lineTo(points.first.dx, graphHeight);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint2);
    }
    
    canvas.drawPath(animatedLinePath, linePaint);

    // Always draw today's vertical indicator line (fade in with animation)
    if (todayIndex < points.length && animationProgress > 0.8) {
      final todayPoint = points[todayIndex];
      final lineOpacity = ((animationProgress - 0.8) / 0.2).clamp(0.0, 1.0);
      
      // Vertical indicator line - golden (always visible)
      final todayLinePaint = Paint()
        ..color = goldenColor.withOpacity(0.6 * lineOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(todayPoint.dx, topPadding),
        Offset(todayPoint.dx, graphHeight),
        todayLinePaint,
      );
    }

    // Draw today indicator dot - golden (fade in at end of animation)
    if (todayIndex < points.length && animationProgress > 0.9) {
      final todayPoint = points[todayIndex];
      final dotOpacity = ((animationProgress - 0.9) / 0.1).clamp(0.0, 1.0);
      final dotOuterPaint = Paint()
        ..color = Colors.white.withOpacity(dotOpacity)
        ..style = PaintingStyle.fill;
      final dotPaint = Paint()
        ..color = goldenColor.withOpacity(dotOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(todayPoint, 8, dotOuterPaint);
      canvas.drawCircle(todayPoint, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _UsageGraphPainter oldDelegate) {
    return oldDelegate.weeklyData != weeklyData || 
           oldDelegate.lastWeekData != lastWeekData ||
           oldDelegate.todayIndex != todayIndex ||
           oldDelegate.animationProgress != animationProgress;
  }
}

/// Combined row widget with Level and Screen Time side by side
class _LevelAndScreenTimeRow extends StatefulWidget {
  final UserProfile? userProfile;
  
  const _LevelAndScreenTimeRow({this.userProfile});

  @override
  State<_LevelAndScreenTimeRow> createState() => _LevelAndScreenTimeRowState();
}

class _LevelAndScreenTimeRowState extends State<_LevelAndScreenTimeRow> {
  late AutomaticScreenTracker _tracker;
  int? totalXP;
  int? level;
  double? progress;
  Map<String, int>? levelProgress;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    _updateXPData();
  }

  @override
  void dispose() {
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_LevelAndScreenTimeRow oldWidget) {
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

  void _showXPInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('XP System'),
        content: const Text(
          'Earn XP daily based on your screen time:\n\n'
          '• ≤2 hours: 100 XP\n'
          '• 2-4 hours: 75 XP\n'
          '• 4-6 hours: 50 XP\n'
          '• 6-8 hours: 25 XP\n'
          '• 8-10 hours: 10 XP\n'
          '• 10+ hours: 0 XP\n\n'
          'Less screen time = More XP!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = level ?? widget.userProfile?.level ?? 1;
    final currentProgress = progress ?? widget.userProfile?.progressToNextLevel ?? 0.0;
    final currentLevelProgress = levelProgress ?? widget.userProfile?.currentLevelProgress ?? {'currentLevelXP': 0, 'requiredForNextLevel': 100, 'remaining': 100};
    final xpInCurrentLevel = currentLevelProgress['currentLevelXP']!;
    final xpNeededForNextLevel = currentLevelProgress['requiredForNextLevel']!;
    const accentColor = Color(0xFFa92d35);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Level Card - half width
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level label with info icon
                Row(
                  children: [
                    Text(
                      'Level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showXPInfo(context),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Large level number
                Center(
                  child: Text(
                    '$currentLevel',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Progress bar
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFfec443),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: currentProgress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // XP text
                Center(
                  child: Text(
                    '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Screen Time Card - half width
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Screen Time',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                // Large screen time
                Center(
                  child: Text(
                    _tracker.todayScreenTime,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Today label
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Today',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

/// Stats row widget showing Screen Time and Pickups side by side (DEPRECATED - kept for reference)
class _StatsRowWidget extends StatefulWidget {
  const _StatsRowWidget();

  @override
  State<_StatsRowWidget> createState() => _StatsRowWidgetState();
}

class _StatsRowWidgetState extends State<_StatsRowWidget> {
  late AutomaticScreenTracker _tracker;
  int _pickups = 0;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onUpdate);
    _loadPickups();
  }

  @override
  void dispose() {
    _tracker.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPickups() async {
    // Pickups would come from native platform channel
    // For now, showing placeholder
    if (mounted) {
      setState(() {
        _pickups = 0; // Placeholder - implement native pickup tracking
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Screen Time stat
          Expanded(
            child: Column(
              children: [
                Text(
                  'Screen Time',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tracker.todayScreenTime,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            height: 50,
            width: 1,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
          ),
          
          // Pickups stat
          Expanded(
            child: Column(
              children: [
                Text(
                  'Pickups',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pickups > 0 ? '$_pickups' : '--',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ END NEW DASHBOARD WIDGETS ============

class RankingsTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const RankingsTab({super.key, required this.onSelectTab, this.scaffoldKey});

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
      drawerGestureEnabled: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
        ),
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
                Tab(text: 'All'),
                Tab(text: 'Department'),
                Tab(text: 'Friends'),
              ],
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorColor: const Color(0xFFa92d35),
              labelColor: const Color(0xFFa92d35),
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
            ),
          ),
          // Period tabs (Day, Week, Month, Year)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _PeriodTab(
                  label: 'Day',
                  isSelected: _period == 'daily',
                  onTap: () {
                    setState(() { _period = 'daily'; });
                    _fetchRankings(reset: true, forceCurrentPeriod: true);
                  },
                ),
                const SizedBox(width: 8),
                _PeriodTab(
                  label: 'Week',
                  isSelected: _period == 'weekly',
                  onTap: () {
                    setState(() { _period = 'weekly'; });
                    _fetchRankings(reset: true, forceCurrentPeriod: true);
                  },
                ),
                const SizedBox(width: 8),
                _PeriodTab(
                  label: 'Month',
                  isSelected: _period == 'monthly',
                  onTap: () {
                    setState(() { _period = 'monthly'; });
                    _fetchRankings(reset: true, forceCurrentPeriod: true);
                  },
                ),
                const Spacer(),
                _SortToggleButton(
                  ascending: _ascending,
                  onToggle: () {
                    setState(() { _ascending = !_ascending; });
                    _fetchRankings(reset: true, forceCurrentPeriod: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
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
      return RefreshIndicator(
        onRefresh: () async {
          await _loadMyDepartment();
          await _fetchRankings(reset: true, forceCurrentPeriod: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No department assigned to your profile. Rankings unavailable.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Handle empty state for friends scope
    if (_scope == 'friends' && !_loading && _entries.isEmpty) {
      // Show different message based on whether user has friends or not
      final hasFriends = _friendCount > 0;
      return RefreshIndicator(
        onRefresh: () async {
          await _fetchRankings(reset: true, forceCurrentPeriod: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
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
              ),
            ),
          ],
        ),
      );
    }

    // Get Top 3 and remaining entries
    final top3 = _entries.take(3).toList();
    final remaining = _entries.skip(3).take(7).toList(); // Positions 4-10
    final currentUserId = SupabaseService().currentUserId;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchRankings(reset: true, forceCurrentPeriod: true);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Top 3 Podium Section
          if (top3.isNotEmpty) ...[
            _Top3Podium(
              entries: top3,
              currentUserId: currentUserId,
            ),
            const SizedBox(height: 20),
          ],
          
          // "Students" section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewAllRankingsScreen(
                          scope: _scope,
                          period: _period,
                          ascending: _ascending,
                          departmentId: _scope == 'department' ? _myDepartmentId : null,
                        ),
                      ),
                    );
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          
          // Ranked List (Positions 4-10)
          if (remaining.isNotEmpty) ...[
            ...remaining.asMap().entries.map((entry) {
              final index = entry.key;
              final rankingEntry = entry.value;
              return _RankingTile(
                rank: index + 4, // Start from rank 4
                entry: rankingEntry,
                you: rankingEntry.userId == currentUserId,
              );
            }),
            const SizedBox(height: 16),
          ],
          
          // Loading indicator for pagination
          if (_hasMore && _entries.length > 10)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// (old custom scope tab removed; now using TabBar)

/// Period Tab Widget
class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFa92d35);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(
            color: Colors.black26,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? accentColor
                : Colors.black87,
          ),
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

/// Top 3 Podium Widget
class _Top3Podium extends StatelessWidget {
  final List<RankingEntry> entries;
  final String? currentUserId;

  const _Top3Podium({
    required this.entries,
    this.currentUserId,
  });

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
    // Ensure we have at least 1 entry, pad with nulls if needed
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place (left, slightly lower)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 50, bottom: 0), // Push down slightly
              child: second != null
                  ? _buildPodiumCard(
                      context,
                      entry: second,
                      rank: 2,
                      isCenter: false,
                      isLeft: true,
                    )
                  : _buildEmptyPodiumCard(context, rank: 2, isCenter: false),
            ),
          ),
          const SizedBox(width: 4),
          // 1st place (center, highest) - larger
          Expanded(
            flex: 1,
            child: first != null
                ? _buildPodiumCard(
                    context,
                    entry: first,
                    rank: 1,
                    isCenter: true,
                    isLeft: false,
                  )
                : _buildEmptyPodiumCard(context, rank: 1, isCenter: true),
          ),
          const SizedBox(width: 4),
          // 3rd place (right, slightly lower)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 50, bottom: 0), // Push down slightly
              child: third != null
                  ? _buildPodiumCard(
                      context,
                      entry: third,
                      rank: 3,
                      isCenter: false,
                      isLeft: false,
                    )
                  : _buildEmptyPodiumCard(context, rank: 3, isCenter: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPodiumCard(BuildContext context, {required int rank, required bool isCenter}) {
    // Colors and sizes based on rank
    Color borderColor;
    Color badgeColor;
    double avatarSize;

    if (rank == 1) {
      borderColor = Colors.amber.shade700; // Gold
      badgeColor = Colors.amber.shade600;
      avatarSize = 100;
    } else if (rank == 2) {
      borderColor = Colors.grey.shade400; // Silver
      badgeColor = Colors.grey.shade500;
      avatarSize = 80;
    } else {
      borderColor = Colors.orange.shade600; // Bronze
      badgeColor = Colors.orange.shade700;
      avatarSize = 80;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Empty avatar with border to maintain spacing
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize + 8,
              height: avatarSize + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor.withOpacity(0.3),
                  width: 4,
                ),
              ),
            ),
            CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              child: Icon(
                Icons.person,
                size: avatarSize * 0.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            // Rank badge
            Positioned(
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Empty space for name
        SizedBox(
          width: double.infinity,
          height: isCenter ? 20 : 18,
        ),
        const SizedBox(height: 4),
        // Empty space for department
        SizedBox(
          width: double.infinity,
          height: isCenter ? 16 : 14,
        ),
        const SizedBox(height: 4),
        // Empty space for screen time
        SizedBox(
          width: double.infinity,
          height: isCenter ? 18 : 16,
        ),
      ],
    );
  }

  String _getFirstName(String? firstName, String? fullName) {
    // Prefer firstName if available, otherwise extract from fullName
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }
    if (fullName != null && fullName.isNotEmpty) {
      final parts = fullName.trim().split(' ');
      return parts.first;
    }
    return 'Unknown';
  }

  Widget _buildPodiumCard(
    BuildContext context, {
    required RankingEntry? entry,
    required int rank,
    required bool isCenter,
    required bool isLeft,
  }) {
    if (entry == null) {
      return const SizedBox.shrink();
    }

    final isYou = entry.userId == currentUserId;
    final fullName = entry.fullName ?? entry.userTag ?? 'Unknown';
    final firstName = _getFirstName(entry.firstName, fullName);
    final department = entry.departmentName ?? '—';
    final screenTime = _formatScreenTime(entry.valueMinutes);

    // Colors and sizes based on rank
    Color borderColor;
    Color badgeColor;
    double avatarSize;
    IconData? crownIcon;

    if (rank == 1) {
      borderColor = Colors.amber.shade700; // Gold
      badgeColor = Colors.amber.shade600;
      avatarSize = 100;
      crownIcon = Icons.emoji_events;
    } else if (rank == 2) {
      borderColor = Colors.grey.shade400; // Silver
      badgeColor = Colors.grey.shade500;
      avatarSize = 80;
    } else {
      borderColor = Colors.orange.shade600; // Bronze
      badgeColor = Colors.orange.shade700;
      avatarSize = 80;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentProfileScreen(userId: entry.userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with border
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize + 8,
                height: avatarSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              AvatarWidget(
                avatarUrl: entry.avatarUrl,
                fullName: fullName,
                size: avatarSize,
              ),
              // Crown icon for 1st place
              if (rank == 1 && crownIcon != null)
                Positioned(
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      crownIcon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              // Rank badge
              Positioned(
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // First name only - highlighted if current user
          SizedBox(
            width: double.infinity,
            child: Text(
              firstName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isCenter ? 16 : 14,
                color: isYou 
                    ? const Color(0xFFa92d35)
                    : Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Department
          SizedBox(
            width: double.infinity,
            child: Text(
              department,
              style: TextStyle(
                fontSize: isCenter ? 12 : 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Screen time
          SizedBox(
            width: double.infinity,
            child: Text(
              screenTime,
              style: TextStyle(
                fontSize: isCenter ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFa92d35),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final RankingEntry entry;
  final bool you;

  const _RankingTile({
    required this.rank,
    required this.entry,
    required this.you,
  });

  /// Get rank badge color (gold for 1st, silver for 2nd, bronze for 3rd, default for others)
  Color _getRankColor(BuildContext context, int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return Theme.of(context).colorScheme.primaryContainer;
  }

  /// Get border color for ranking list avatars (subtle colors that don't compete with podium)
  Color _getRankingBorderColor(BuildContext context, int rank) {
    // Use theme colors for positions 4+ - subtle and elegant
    if (rank <= 10) {
      // Top 10 get a subtle primary color border
      return Theme.of(context).colorScheme.primary.withOpacity(0.6);
    } else if (rank <= 25) {
      // Next tier gets secondary color
      return Theme.of(context).colorScheme.secondary.withOpacity(0.5);
    } else {
      // Others get tertiary color - very subtle
      return Theme.of(context).colorScheme.tertiary.withOpacity(0.4);
    }
  }

  /// Get rank text color (dark for top 3, theme color for others)
  Color _getRankTextColor(BuildContext context, int rank) {
    if (rank <= 3) return Colors.black87;
    return Theme.of(context).colorScheme.onPrimaryContainer;
  }

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
    final timeStr = _formatScreenTime(entry.valueMinutes);
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
              // Avatar with rank badge overlay - matching podium layout style
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Circular border container - similar style to podium but more subtle
                  Container(
                    width: 40 + 6, // avatar size + border padding
                    height: 40 + 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getRankingBorderColor(context, rank),
                        width: 2,
                      ),
                      // Subtle shadow effect - less intense than podium
                      boxShadow: [
                        BoxShadow(
                          color: _getRankingBorderColor(context, rank).withOpacity(0.25),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AvatarWidget.small(
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
                    ),
                  ),
                  // Rank badge positioned at bottom center - matching podium layout
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getRankColor(context, rank),
                        borderRadius: BorderRadius.circular(10),
                        // Subtle shadow matching avatar border style
                        boxShadow: [
                          BoxShadow(
                            color: _getRankingBorderColor(context, rank).withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: _getRankTextColor(context, rank),
                          fontWeight: FontWeight.bold,
                          fontSize: rank <= 3 ? 11 : 9,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: you ? const Color(0xFFa92d35) : null,
                          ),
                        ),
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

class FriendsTab extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const FriendsTab({super.key, required this.onSelectTab, this.scaffoldKey});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  bool _isStatusBarHidden = false;

  void _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return;
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      if (currentOffset >= kToolbarHeight && !_isStatusBarHidden) {
        _isStatusBarHidden = true;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (currentOffset < 1 && _isStatusBarHidden) {
        _isStatusBarHidden = false;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  @override
  void dispose() {
    if (_isStatusBarHidden) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawerGestureEnabled: false,
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScroll(notification);
          return false;
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              snap: true,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
              ),
              title: const Text('Friends'),
            ),
          ],
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
        ),
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
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const ChallengesTab({super.key, required this.onSelectTab, this.scaffoldKey});

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  bool _isLoading = true;
  bool _isStatusBarHidden = false;
  final ChallengeService _challengeService = ChallengeService();
  List<badge_models.Badge> _allBadges = [];
  List<challenge_models.Challenge> _challenges = [];
  Set<int> _earnedBadgeIds = {};
  Map<int, double> _badgeProgress = {};
  Map<int, int> _badgeLevels = {}; // badgeId -> level
  Map<int, int> _badgeCompletionCounts = {}; // badgeId -> completion count
  
  // Screen time stats
  int? _dailyScreenTimeMinutes;
  int? _weeklyAverageMinutes;
  int? _monthlyAverageMinutes;
  int? _currentStreak;
  int? _totalXP;
  int? _level;
  int? _friendCount;
  
  // Timer strings
  String _dailyResetTimer = 'Calculating...';
  String _weeklyResetTimer = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _loadChallengesData();
  }

  @override
  void dispose() {
    if (_isStatusBarHidden) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return;
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      if (currentOffset >= kToolbarHeight && !_isStatusBarHidden) {
        _isStatusBarHidden = true;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (currentOffset < 1 && _isStatusBarHidden) {
        _isStatusBarHidden = false;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> _loadChallengesData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load badges and stats first (in parallel)
      await Future.wait([
        _loadBadges(),
        _loadScreenTimeStats(),
      ]);
      
      // Then calculate progress (depends on badges and stats)
      await _calculateProgress();
      
      // Calculate timers (independent)
      _calculateTimers();
    } catch (e) {
      print('Error loading challenges data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBadges() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;
      
      final challenges = await _challengeService.loadChallenges();
      final allBadges = challenges
          .map((challenge) => challenge.badge ?? challenge.toBadgeFallback())
          .where((badge) => badge.id != 0)
          .toList();

      final db = DatabaseService();
      final userBadges = await db.getUserBadges(userId);
      final earnedIds = userBadges.map((b) => b.badgeId).toSet();
      final badgeLevels = <int, int>{};
      final badgeCompletionCounts = <int, int>{};
      
      for (final userBadge in userBadges) {
        badgeLevels[userBadge.badgeId] = userBadge.level;
        badgeCompletionCounts[userBadge.badgeId] = userBadge.completionCount;
      }
      
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _allBadges = allBadges;
          _earnedBadgeIds = earnedIds;
          _badgeLevels = badgeLevels;
          _badgeCompletionCounts = badgeCompletionCounts;
        });
      }
    } catch (e) {
      print('Error loading badges: $e');
    }
  }

  Future<void> _loadScreenTimeStats() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;
      
      final db = DatabaseService();
      final tracker = AutomaticScreenTracker();
      
      // Get daily screen time
      final dailyMinutes = tracker.todayScreenTimeMinutes;
      
      // Calculate weekly average
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weeklyEntries = await db.getScreenTimeEntriesForDateRange(userId, weekAgo, now);
      final weeklyTotal = weeklyEntries
          .where((e) => e.durationMinutes != null)
          .fold<int>(0, (sum, e) => sum + (e.durationMinutes ?? 0));
      final weeklyAverage = weeklyTotal > 0 ? (weeklyTotal / 7).round() : null;
      
      // Calculate monthly average
      final monthAgo = now.subtract(const Duration(days: 30));
      final monthlyEntries = await db.getScreenTimeEntriesForDateRange(userId, monthAgo, now);
      final monthlyTotal = monthlyEntries
          .where((e) => e.durationMinutes != null)
          .fold<int>(0, (sum, e) => sum + (e.durationMinutes ?? 0));
      final monthlyAverage = monthlyTotal > 0 ? (monthlyTotal / 30).round() : null;
      
      // Calculate streak (simplified - using BadgeService logic)
      int currentStreak = 0;
      final today = DateTime(now.year, now.month, now.day);
      final dailyTotals = <String, int>{};
      final allEntries = await db.getScreenTimeEntriesForDateRange(
        userId,
        now.subtract(const Duration(days: 60)),
        now,
      );
      for (final entry in allEntries) {
        if (entry.durationMinutes == null) continue;
        final dateKey = '${entry.startTime.year}-${entry.startTime.month.toString().padLeft(2, '0')}-${entry.startTime.day.toString().padLeft(2, '0')}';
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + entry.durationMinutes!;
      }
      for (int i = 0; i < 60; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
        final dayTotal = dailyTotals[dateKey] ?? 0;
        if (dayTotal == 0 && i > 0) break;
        if (dayTotal <= 240) {
          currentStreak++;
        } else {
          if (i == 0 && now.hour < 20) continue;
          break;
        }
      }
      
      // Get user profile for XP and level
      final userProfile = await db.getUserProfile(userId);
      final totalXP = userProfile?.xp ?? 0;
      final level = userProfile != null ? LevelCalculator.getLevel(totalXP) : 0;
      
      // Get friend count (optional)
      int? friendCount;
      try {
        final supabaseService = SupabaseService();
        if (await supabaseService.isConnected()) {
          final friends = await supabaseService.getFriends();
          friendCount = friends.length;
        }
      } catch (e) {
        // Friend count not critical
      }
      
      if (mounted) {
        setState(() {
          _dailyScreenTimeMinutes = dailyMinutes;
          _weeklyAverageMinutes = weeklyAverage;
          _monthlyAverageMinutes = monthlyAverage;
          _currentStreak = currentStreak > 0 ? currentStreak : null;
          _totalXP = totalXP;
          _level = level;
          _friendCount = friendCount;
        });
      }
    } catch (e) {
      print('Error loading screen time stats: $e');
    }
  }

  Future<void> _calculateProgress() async {
    try {
      final badgeService = BadgeService();
      final progressMap = <int, double>{};
      
      for (final badge in _allBadges) {
        // If badge is already earned, set progress to 100%
        if (_earnedBadgeIds.contains(badge.id)) {
          progressMap[badge.id] = 1.0;
        } else {
          // Calculate progress for unearned badges
          final progress = await badgeService.getBadgeProgress(
            badge,
            dailyScreenTimeMinutes: _dailyScreenTimeMinutes,
            weeklyAverageMinutes: _weeklyAverageMinutes,
            monthlyAverageMinutes: _monthlyAverageMinutes,
            currentStreak: _currentStreak,
            totalXP: _totalXP,
            level: _level,
            friendCount: _friendCount,
          );
          progressMap[badge.id] = progress;
        }
      }
      
      if (mounted) {
        setState(() {
          _badgeProgress = progressMap;
        });
      }
    } catch (e) {
      print('Error calculating progress: $e');
    }
  }

  void _calculateTimers() {
    final now = DateTime.now();
    
    // Daily reset (midnight)
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dailyDuration = tomorrow.difference(now);
    final dailyHours = dailyDuration.inHours;
    final dailyMinutes = dailyDuration.inMinutes % 60;
    _dailyResetTimer = dailyHours > 0 
        ? 'Resets in ${dailyHours}h ${dailyMinutes}m'
        : 'Resets in ${dailyMinutes}m';
    
    // Weekly reset (next Sunday)
    final daysUntilSunday = (7 - now.weekday) % 7;
    final nextSunday = DateTime(now.year, now.month, now.day + (daysUntilSunday == 0 ? 7 : daysUntilSunday));
    final weeklyDuration = nextSunday.difference(now);
    final weeklyDays = weeklyDuration.inDays;
    _weeklyResetTimer = weeklyDays > 0 
        ? '$weeklyDays ${weeklyDays == 1 ? 'day' : 'days'} left'
        : 'Resets today';
    
    setState(() {});
  }

  List<challenge_models.Challenge> _getChallengesByCategory(
      badge_models.BadgeCategory category) {
    final filtered = _challenges.where((challenge) => challenge.category == category).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (filtered.isEmpty && _challenges.isEmpty) {
      // Fallback to badge list if challenges have not been synced yet
      return _allBadges
          .where((badge) => badge.category == category)
          .map(challenge_models.Challenge.fromBadge)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        drawerGestureEnabled: false,
        extendBodyBehindAppBar: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _handleScroll(notification);
            return false;
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                elevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                floating: true,
                snap: true,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
                ),
                title: const Text('Challenges'),
              ),
            ],
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }
    return AppScaffold(
      drawerGestureEnabled: false,
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScroll(notification);
          return false;
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              snap: true,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
              ),
              title: const Text('Challenges'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.collections),
                  tooltip: 'View Badge Catalog',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BadgeCatalogScreen(
                          onSelectTab: widget.onSelectTab,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
          body: RefreshIndicator(
            onRefresh: _loadChallengesData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Challenges Section
              _buildSectionHeader(
                context,
                icon: Icons.today,
                title: 'Daily Challenges',
                timer: _dailyResetTimer,
              ),
              const SizedBox(height: 12),
              ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.daily)),
              
              const SizedBox(height: 24),
              
              // Weekly Challenges Section
              _buildSectionHeader(
                context,
                icon: Icons.date_range,
                title: 'Weekly Challenges',
                timer: _weeklyResetTimer,
              ),
              const SizedBox(height: 12),
              ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.weekly)),
              
              const SizedBox(height: 24),
              
              // Monthly Challenges Section
              _buildSectionHeader(
                context,
                icon: Icons.calendar_month,
                title: 'Monthly Challenges',
                timer: _weeklyResetTimer, // Use weekly timer for now
              ),
              const SizedBox(height: 12),
              ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.monthly)),
              
              const SizedBox(height: 24),
              
              // Streak Challenges Section
              _buildSectionHeader(
                context,
                icon: Icons.local_fire_department,
                title: 'Streak Challenges',
                timer: null,
              ),
              const SizedBox(height: 12),
              ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.streak)),
              
              const SizedBox(height: 24),
              
              // Milestone Challenges Section
              _buildSectionHeader(
                context,
                icon: Icons.flag,
                title: 'Milestone Challenges',
                timer: null,
              ),
              const SizedBox(height: 12),
              ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.milestone)),
              
              // Social Challenges (if any)
              if (_getChallengesByCategory(badge_models.BadgeCategory.social).isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader(
                  context,
                  icon: Icons.people,
                  title: 'Social Challenges',
                  timer: null,
                ),
                const SizedBox(height: 12),
                ..._buildChallengeCards(_getChallengesByCategory(badge_models.BadgeCategory.social)),
              ],
              
              // Empty state if no badges
              if (_challenges.isEmpty && _allBadges.isEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No challenges available',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Badges will appear here once they are added to the system',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? timer,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFa92d35),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (timer != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFa92d35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFa92d35),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildChallengeCards(List<challenge_models.Challenge> challenges) {
    if (challenges.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No challenges in this category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      ];
    }

    return challenges.map((challenge) {
      final badge = challenge.badge ?? challenge.toBadgeFallback();
      final isEarned = _earnedBadgeIds.contains(challenge.badgeId);
      final progress = _badgeProgress[challenge.badgeId] ?? 0.0;
      final level = _badgeLevels[challenge.badgeId] ?? 1;
      final completionCount = _badgeCompletionCounts[challenge.badgeId] ?? 0;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: _buildBadgeChallengeCard(
          context,
          badge,
          isEarned,
          progress,
          challenge: challenge,
          level: level,
          completionCount: completionCount,
        ),
      );
    }).toList();
  }

  Widget _buildBadgeChallengeCard(
    BuildContext context,
    badge_models.Badge badge,
    bool isEarned,
    double progress,
    {challenge_models.Challenge? challenge,
    int level = 1,
    int completionCount = 0}
  ) {
    return _buildChallengeCard(
      context,
      badge: badge,
      title: challenge?.title,
      description: challenge?.description,
      progress: progress,
      isCompleted: isEarned,
      level: level,
      completionCount: completionCount,
    );
  }

  Widget _buildChallengeCard(
    BuildContext context, {
    badge_models.Badge? badge,
    IconData? icon,
    String? title,
    String? description,
    double? progress,
    String? reward,
    required bool isCompleted,
    String? progressText,
    int level = 1,
    int completionCount = 0,
  }) {
    // Use badge data if provided, otherwise use individual parameters (for backward compatibility)
    final badgeTitle = title ?? badge?.name ?? 'Challenge';
    final badgeDescription = description ?? badge?.description ?? '';
    final badgeProgress = progress ?? 0.0;
    final badgeReward = badge != null 
        ? '+${badge.xpReward} XP'
        : (reward ?? '+0 XP');
    final badgeRarityColor = badge != null
        ? BadgeIconHelper.getRarityColor(badge.rarity)
        : const Color(0xFFa92d35);
    
    // Generate progress text based on badge type
    String? generatedProgressText;
    if (badge != null && !isCompleted) {
      generatedProgressText = _getProgressText(badge, badgeProgress);
    } else {
      generatedProgressText = progressText;
    }
    
    // Add level information for earned badges
    if (isCompleted && level > 1) {
      final levelText = 'Level $level';
      if (badge?.levelThresholds != null && badge!.levelThresholds!.isNotEmpty) {
        final thresholds = badge.levelThresholds!;
        final nextLevelThreshold = level <= thresholds.length ? thresholds[level - 1] : null;
        if (nextLevelThreshold != null) {
          generatedProgressText = '$levelText ($completionCount/$nextLevelThreshold completions)';
        } else {
          generatedProgressText = '$levelText ($completionCount completions)';
        }
      } else {
        generatedProgressText = '$levelText ($completionCount completions)';
      }
    }
    
    const accentColor = Color(0xFFa92d35);
    final displayColor = badge != null ? badgeRarityColor : accentColor;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.1)
                        : displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        )
                      : badge != null
                          ? BadgeIconHelper.getBadgeIcon(
                              iconUrl: badge.iconUrl,
                              category: badge.category,
                              rarity: badge.rarity,
                              size: 24,
                            )
                          : Icon(
                              icon ?? Icons.emoji_events,
                              color: displayColor,
                              size: 24,
                            ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badgeTitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                color: isCompleted ? Colors.grey : null,
                              ),
                            ),
                          ),
                          if (isCompleted && level > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lv.$level',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (badgeDescription.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          badgeDescription,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeReward,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (!isCompleted && badgeProgress < 1.0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: badgeProgress,
                  minHeight: 6,
                  backgroundColor: displayColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                ),
              ),
              if (generatedProgressText != null) ...[
                const SizedBox(height: 8),
                Text(
                  generatedProgressText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String? _getProgressText(badge_models.Badge badge, double progress) {
    if (badge.requiredValue == null) return null;
    
    switch (badge.category) {
      case badge_models.BadgeCategory.daily:
        if (_dailyScreenTimeMinutes != null) {
          final current = _dailyScreenTimeMinutes!;
          final required = badge.requiredValue!;
          final currentHours = current ~/ 60;
          final currentMins = current % 60;
          final requiredHours = required ~/ 60;
          final requiredMins = required % 60;
          if (requiredHours > 0) {
            return '${currentHours}h ${currentMins}m / ${requiredHours}h ${requiredMins}m';
          }
          return '${current}m / ${required}m';
        }
        return null;
        
      case badge_models.BadgeCategory.weekly:
        if (_weeklyAverageMinutes != null) {
          final current = _weeklyAverageMinutes!;
          final required = badge.requiredValue!;
          final currentHours = current ~/ 60;
          final currentMins = current % 60;
          final requiredHours = required ~/ 60;
          final requiredMins = required % 60;
          if (requiredHours > 0) {
            return 'Avg: ${currentHours}h ${currentMins}m / ${requiredHours}h ${requiredMins}m';
          }
          return 'Avg: ${current}m / ${required}m';
        }
        return null;
        
      case badge_models.BadgeCategory.monthly:
        if (_monthlyAverageMinutes != null) {
          final current = _monthlyAverageMinutes!;
          final required = badge.requiredValue!;
          final currentHours = current ~/ 60;
          final currentMins = current % 60;
          final requiredHours = required ~/ 60;
          final requiredMins = required % 60;
          if (requiredHours > 0) {
            return 'Avg: ${currentHours}h ${currentMins}m / ${requiredHours}h ${requiredMins}m';
          }
          return 'Avg: ${current}m / ${required}m';
        }
        return null;
        
      case badge_models.BadgeCategory.streak:
        if (_currentStreak != null) {
          return '${_currentStreak} / ${badge.requiredValue} days';
        }
        return '0 / ${badge.requiredValue} days';
        
      case badge_models.BadgeCategory.milestone:
        if (badge.unlockConditions?['type'] == 'level') {
          if (_level != null) {
            return 'Level ${_level} / ${badge.requiredValue}';
          }
          return 'Level 0 / ${badge.requiredValue}';
        } else if (badge.unlockConditions?['type'] == 'xp') {
          if (_totalXP != null) {
            return '${_totalXP} / ${badge.requiredValue} XP';
          }
          return '0 / ${badge.requiredValue} XP';
        }
        return null;
        
      case badge_models.BadgeCategory.social:
        if (_friendCount != null) {
          return '${_friendCount} / ${badge.requiredValue} friends';
        }
        return '0 / ${badge.requiredValue} friends';
        
      case badge_models.BadgeCategory.special:
        return null;
    }
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
    
    // STEP 2: If online, try to fetch from cloud to get latest data
    final supabaseService = SupabaseService();
    final isConnected = await supabaseService.isConnected();
    
    UserProfile? profileToReturn = localProfile;
    
    if (isConnected) {
      // Always try to fetch from cloud to get latest profile data
      try {
        final cloudProfile = await supabaseService.getUserProfile(userId);
        if (cloudProfile != null && localProfile != null) {
          // CRITICAL: Prioritize local DB URLs if they differ from Supabase
          // Local DB has the correct URLs we just uploaded, even if Supabase hasn't propagated yet
          final bool localHasDifferentAvatar = localProfile.avatarUrl != null && 
              localProfile.avatarUrl!.isNotEmpty &&
              localProfile.avatarUrl != cloudProfile.avatarUrl;
          final bool localHasDifferentCover = localProfile.coverPhotoUrl != null && 
              localProfile.coverPhotoUrl!.isNotEmpty &&
              localProfile.coverPhotoUrl != cloudProfile.coverPhotoUrl;
          
          // If local DB has different URLs, use local URLs (they're the ones we just uploaded)
          if (localHasDifferentAvatar || localHasDifferentCover) {
            print('⚠️ Nav drawer: Using local DB URLs (differ from Supabase)');
            // Merge: use local URLs but keep other Supabase data
            profileToReturn = cloudProfile.copyWith(
              avatarUrl: localHasDifferentAvatar ? localProfile.avatarUrl : cloudProfile.avatarUrl,
              coverPhotoUrl: localHasDifferentCover ? localProfile.coverPhotoUrl : cloudProfile.coverPhotoUrl,
            );
          } else {
            profileToReturn = cloudProfile;
          }
          
          // Clear avatar cache if URL changed
          if (localProfile.avatarUrl != null && 
              localProfile.avatarUrl != profileToReturn.avatarUrl) {
            try {
              CachedNetworkImage.evictFromCache(localProfile.avatarUrl!.split('?').first);
            } catch (e) {
              print('Error clearing old avatar cache in nav drawer: $e');
            }
          }
          // Clear new avatar cache to ensure fresh image
          if (profileToReturn.avatarUrl != null && profileToReturn.avatarUrl!.isNotEmpty) {
            try {
              CachedNetworkImage.evictFromCache(profileToReturn.avatarUrl!.split('?').first);
            } catch (e) {
              print('Error clearing new avatar cache in nav drawer: $e');
            }
          }
          
          // Cache the merged profile locally for offline access
          await db.insertUserProfile(profileToReturn);
        } else if (cloudProfile != null) {
          // No local profile, use cloud profile
          profileToReturn = cloudProfile;
          await db.insertUserProfile(cloudProfile);
        }
      } catch (e) {
        print('Supabase profile fetch failed, using local: $e');
        // Continue with local profile if cloud fetch fails
      }
    }
    
    // Return profile (either from cloud or local, with local URLs prioritized)
    return profileToReturn;
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

/// View All Rankings Screen with search and filters
class ViewAllRankingsScreen extends StatefulWidget {
  final String scope; // 'evsu' | 'department' | 'friends'
  final String period; // 'daily' | 'weekly' | 'monthly'
  final bool ascending;
  final int? departmentId;

  const ViewAllRankingsScreen({
    super.key,
    required this.scope,
    required this.period,
    required this.ascending,
    this.departmentId,
  });

  @override
  State<ViewAllRankingsScreen> createState() => _ViewAllRankingsScreenState();
}

class _ViewAllRankingsScreenState extends State<ViewAllRankingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RankingEntry> _allEntries = [];
  List<RankingEntry> _filteredEntries = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedPeriod = 'daily';
  int? _myDepartmentId; // Current user's department ID
  final ScrollController _scrollController = ScrollController();
  int _limit = 50;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.period;
    // Only load department if department scope
    if (widget.scope == 'department') {
      _loadMyDepartment();
    } else {
      // For EVSU and Friends scope, fetch immediately
      _fetchAllRankings();
    }
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadMyDepartment() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return;
      final profile = await SupabaseService().getUserProfile(userId);
      setState(() { 
        _myDepartmentId = profile?.departmentId;
      });
      // Fetch rankings after loading department
      if (_myDepartmentId != null) {
        _fetchAllRankings();
      }
    } catch (e) {
      print('Error loading user department: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_loading && _hasMore) {
        _loadMore();
      }
    }
  }


  Future<void> _fetchAllRankings({bool reset = false}) async {
    if (_loading) return;
    // Don't fetch if department scope and user's department is not loaded yet
    if (widget.scope == 'department' && _myDepartmentId == null) return;
    
    setState(() {
      _loading = true;
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _allEntries = [];
      }
    });

    try {
      final svc = SupabaseService();
      List<RankingEntry> page = [];

      if (widget.scope == 'friends') {
        if (_selectedPeriod == 'daily') {
          page = await svc.getFriendsDailyRankings(
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        } else if (_selectedPeriod == 'weekly') {
          page = await svc.getFriendsWeeklyRankings(
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        } else {
          page = await svc.getFriendsMonthlyRankings(
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        }
        // Filter friends by department only if department scope
        if (widget.scope == 'department' && _myDepartmentId != null) {
          page = page.where((e) => e.departmentId == _myDepartmentId).toList();
        }
      } else {
        // Use department ID only for department scope, otherwise null (all departments)
        final depId = widget.scope == 'department' ? _myDepartmentId : null;
        if (_selectedPeriod == 'daily') {
          page = await svc.getDailyRankings(
            departmentId: depId,
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        } else if (_selectedPeriod == 'weekly') {
          page = await svc.getWeeklyRankings(
            departmentId: depId,
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        } else {
          page = await svc.getMonthlyRankings(
            departmentId: depId,
            limit: _limit,
            offset: reset ? 0 : _offset,
            ascending: widget.ascending,
          );
        }
        // Client-side filter to ensure department match for department scope
        if (widget.scope == 'department' && _myDepartmentId != null) {
          page = page.where((e) => e.departmentId == _myDepartmentId).toList();
        }
      }

      setState(() {
        if (reset) {
          _allEntries = page;
        } else {
          _allEntries.addAll(page);
        }
        _offset += page.length;
        _hasMore = page.length == _limit;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching rankings: $e');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    await _fetchAllRankings(reset: false);
  }

  void _applyFilters() {
    List<RankingEntry> filtered = List.from(_allEntries);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final name = (entry.fullName ?? entry.userTag ?? '').toLowerCase();
        return name.contains(_searchQuery);
      }).toList();
    }

    // Filter by user's department only for department scope (entries should already be filtered, but double-check)
    if (widget.scope == 'department' && _myDepartmentId != null) {
      filtered = filtered.where((entry) {
        return entry.departmentId == _myDepartmentId;
      }).toList();
    }

    setState(() {
      _filteredEntries = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Rankings'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Filter
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Today',
                      selected: _selectedPeriod == 'daily',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPeriod = 'daily';
                          });
                          _fetchAllRankings(reset: true);
                        }
                      },
                    ),
                    _buildFilterChip(
                      label: 'Weekly',
                      selected: _selectedPeriod == 'weekly',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPeriod = 'weekly';
                          });
                          _fetchAllRankings(reset: true);
                        }
                      },
                    ),
                    _buildFilterChip(
                      label: 'Monthly',
                      selected: _selectedPeriod == 'monthly',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedPeriod = 'monthly';
                          });
                          _fetchAllRankings(reset: true);
                        }
                      },
                    ),
                  ],
                ),

                // Department filter removed - always showing only user's department
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Rankings List
          Expanded(
            child: (widget.scope == 'department' && _myDepartmentId == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No department assigned to your profile. Rankings unavailable.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : _loading && _allEntries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEntries.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No results found'
                                    : 'No rankings available',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          )
                    : RefreshIndicator(
                        onRefresh: () => _fetchAllRankings(reset: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredEntries.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index >= _filteredEntries.length) {
                              if (_hasMore && !_loading) {
                                _loadMore();
                              }
                              if (_hasMore) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            
                            final entry = _filteredEntries[index];
                            final currentUserId = SupabaseService().currentUserId;
                            final rank = index + 1;
                            final name = entry.fullName ?? entry.userTag ?? 'Unknown';
                            final screenTime = _formatScreenTime(entry.valueMinutes);
                            
                            return ListTile(
                              leading: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  // Circular border container
                                  Container(
                                    width: 40 + 6, // avatar size + border padding
                                    height: 40 + 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _getRankingBorderColor(context, rank),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getRankingBorderColor(context, rank).withOpacity(0.25),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: AvatarWidget.small(
                                        avatarUrl: entry.avatarUrl,
                                        fullName: name,
                                      ),
                                    ),
                                  ),
                                  // Rank badge positioned at bottom center
                                  Positioned(
                                    bottom: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getRankColor(context, rank),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getRankingBorderColor(context, rank).withOpacity(0.2),
                                            blurRadius: 4,
                                            spreadRadius: 0.5,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '$rank',
                                        style: TextStyle(
                                          color: _getRankTextColor(context, rank),
                                          fontWeight: FontWeight.bold,
                                          fontSize: rank <= 3 ? 11 : 9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: entry.userId == currentUserId 
                                      ? const Color(0xFFa92d35) 
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                entry.departmentName ?? '—',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    screenTime,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'screen time',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => StudentProfileScreen(userId: entry.userId),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    const accentColor = Color(0xFFa92d35);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? accentColor : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: accentColor.withOpacity(0.15),
      checkmarkColor: accentColor,
      side: selected ? null : BorderSide(color: Colors.black26),
      showCheckmark: true,
    );
  }

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

  /// Get border color for ranking list avatars (subtle colors that don't compete with podium)
  Color _getRankingBorderColor(BuildContext context, int rank) {
    // Use theme colors for positions - subtle and elegant
    if (rank <= 10) {
      // Top 10 get a subtle primary color border
      return Theme.of(context).colorScheme.primary.withOpacity(0.6);
    } else if (rank <= 25) {
      // Next tier gets secondary color
      return Theme.of(context).colorScheme.secondary.withOpacity(0.5);
    } else {
      // Others get tertiary color - very subtle
      return Theme.of(context).colorScheme.tertiary.withOpacity(0.4);
    }
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
}

/// App-wide navigation drawer used across tabs
class _AppDrawer extends StatefulWidget {
  final ValueChanged<int> onSelectTab;
  final int currentScreenIndex;
  
  const _AppDrawer({
    required this.onSelectTab,
    this.currentScreenIndex = 0, // Default to Dashboard
  });

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  int _profileRefreshKey = 0; // Key to force profile refresh
  UserProfile? _cachedProfile; // Cache profile to clear old URLs
  static int _globalRefreshKey = 0; // Global key to force all drawer instances to refresh

  @override
  void initState() {
    super.initState();
    // Sync with global refresh key
    _profileRefreshKey = _globalRefreshKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when drawer is opened (didChangeDependencies is called when drawer opens)
    if (_profileRefreshKey != _globalRefreshKey) {
      _profileRefreshKey = _globalRefreshKey;
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Static method to refresh all drawer instances
  static void refreshAllDrawers() {
    _globalRefreshKey++;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.75; // 75% of screen width
    
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        bottom: false, // Allow drawer to extend over bottom navbar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header section
            _buildProfileHeader(context, _profileRefreshKey),
            _buildNavItem(
              context: context,
              icon: Icons.dashboard,
              title: 'Dashboard',
              index: 0,
              onTap: () {
                Navigator.of(context).pop();
                widget.onSelectTab(0);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.leaderboard,
              title: 'Rankings',
              index: 1,
              onTap: () {
                Navigator.of(context).pop();
                widget.onSelectTab(1);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.group,
              title: 'Friends',
              index: 100,
              onTap: () {
                Navigator.of(context).pop();
                widget.onSelectTab(100);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings,
              title: 'Settings',
              index: 200,
              onTap: () {
                Navigator.of(context).pop();
                widget.onSelectTab(200);
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
  Widget _buildProfileHeader(BuildContext context, int refreshKey) {
    // IMPORTANT: Call the function directly to create a NEW future each time
    // The ValueKey ensures widget rebuilds, and calling the function ensures new future
    return FutureBuilder<UserProfile?>(
      future: _loadCurrentUserProfileOptimized(), // New future created each rebuild
      key: ValueKey('profile_header_$refreshKey'), // Force rebuild when refresh key changes
      builder: (context, snapshot) {
        final profile = snapshot.data;
        
        // Clear cache for old profile if URL changed
        if (profile != null && _cachedProfile != null) {
          if (_cachedProfile!.avatarUrl != profile.avatarUrl) {
            // Clear old avatar cache
            if (_cachedProfile!.avatarUrl != null && _cachedProfile!.avatarUrl!.isNotEmpty) {
              try {
                CachedNetworkImage.evictFromCache(_cachedProfile!.avatarUrl!.split('?').first);
              } catch (e) {
                print('Error clearing old nav drawer avatar cache: $e');
              }
            }
            // Clear new avatar cache
            if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
              try {
                CachedNetworkImage.evictFromCache(profile.avatarUrl!.split('?').first);
              } catch (e) {
                print('Error clearing new nav drawer avatar cache: $e');
              }
            }
          }
          _cachedProfile = profile; // Update cache
        } else if (profile != null) {
          _cachedProfile = profile; // First load
        }
        
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
          onTap: () async {
            Navigator.of(context).pop();
            // Store old avatar URL before navigating
            final oldAvatarUrl = profile?.avatarUrl;
            final oldCoverPhotoUrl = profile?.coverPhotoUrl;
            
            // Wait a bit before navigating to ensure drawer closes
            await Future.delayed(const Duration(milliseconds: 100));
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentProfileScreen(),
              ),
            );
            
            // Always refresh profile header when returning from profile screen
            if (mounted) {
              // Clear ALL avatar and cover photo caches aggressively
              try {
                // Clear old avatar cache
                if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
                  CachedNetworkImage.evictFromCache(oldAvatarUrl.split('?').first);
                }
                // Clear old cover photo cache
                if (oldCoverPhotoUrl != null && oldCoverPhotoUrl.isNotEmpty) {
                  CachedNetworkImage.evictFromCache(oldCoverPhotoUrl.split('?').first);
                }
                // Clear any potential new URLs (clear all user avatar URLs)
                final userId = SupabaseService().currentUserId;
                if (userId != null) {
                  // Clear potential new avatar URL
                  final potentialNewAvatarUrl = '${SupabaseService().client.storage.from('avatars').getPublicUrl('$userId.jpg')}';
                  CachedNetworkImage.evictFromCache(potentialNewAvatarUrl.split('?').first);
                  // Clear potential new cover photo URL
                  final potentialNewCoverUrl = '${SupabaseService().client.storage.from('cover-photos').getPublicUrl('$userId.jpg')}';
                  CachedNetworkImage.evictFromCache(potentialNewCoverUrl.split('?').first);
                }
              } catch (e) {
                print('Error clearing nav drawer image cache: $e');
              }
              
              // Wait a bit for Supabase to propagate
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Refresh ALL drawer instances (static method)
              _AppDrawerState.refreshAllDrawers();
              
              // Refresh the profile header to load updated data
              if (mounted) {
                setState(() {
                  _profileRefreshKey = _AppDrawerState._globalRefreshKey;
                  _cachedProfile = null; // Clear cache to force reload
                });
              }
            }
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
                      forceRefresh: refreshKey > 0, // Force refresh when key changes
                      key: ValueKey('nav_avatar_${profile?.id}_$refreshKey'), // Force widget rebuild
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
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Color(0xFFa92d35),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Level $currentLevel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFa92d35),
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
                  backgroundColor: const Color(0xFFfec443),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFa92d35),
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
    final isSelected = widget.currentScreenIndex == index;
    const accentColor = Color(0xFFa92d35);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected 
          ? accentColor.withOpacity(0.15)
          : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
            ? accentColor
            : Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
              ? accentColor
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

