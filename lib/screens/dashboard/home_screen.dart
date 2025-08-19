import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardTab(),
    const RankingsTab(),
    const ProfileTab(),
  ];

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
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with WidgetsBindingObserver {
  UserProfile? userProfile;
  bool isLoading = true;
  late AutomaticScreenTracker _automaticTracker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _automaticTracker = AutomaticScreenTracker();
    _loadUserData();
    _startAutomaticTracking();
  }

  Future<void> _startAutomaticTracking() async {
    // Start the automatic screen tracker for UI display
    final started = await _automaticTracker.startMonitoring();
    if (!started) {
      print('Failed to start automatic screen tracking');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App goes to background - just log, don't reset session
        // The PersistentTrackerService handles actual screen OFF events
        print('App paused - background service continues tracking');
        break;
      case AppLifecycleState.resumed:
        // App comes to foreground - refresh data and sync, but don't restart session
        // The PersistentTrackerService handles screen ON events
        print('App resumed - refreshing data and syncing');
        _automaticTracker.checkForEndOfDay();
        _automaticTracker.refreshTodayData();
        ImprovedSyncService().performSync();
        break;
      case AppLifecycleState.detached:
        // App is being terminated - stop automatic tracking display
        _automaticTracker.stopMonitoring();
        break;
      default:
        break;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        final profile = await SupabaseService().getUserProfile(userId);
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
      WelcomeCard(userProfile: userProfile),
      
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
            children: [
              Text('Debug Panel', style: Theme.of(context).textTheme.titleMedium),
              // First row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await DebugHelper.checkAuthStatus();
                    },
                    child: const Text('Auth'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await DebugHelper.checkDatabaseContent();
                    },
                    child: const Text('Check DB'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await DebugHelper.testScreenTimeTracking();
                    },
                    child: const Text('Test Track'),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
              // Second row - Session debugging
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await DebugHelper.addTestScreenTimeEntry();
                      await _automaticTracker.refreshTodayData();
                      setState(() {}); // Refresh UI
                    },
                    child: const Text('Add Test'),
                  ),
                              ElevatedButton(
              onPressed: () async {
                await DebugHelper.testBidirectionalSync();
              },
              child: const Text('Old Sync'),
            ),
                  ElevatedButton(
                    onPressed: () async {
                      await DebugHelper.checkSessionStatus();
                    },
                    child: const Text('Session'),
                  ),
                ],
              ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        // Third row - Data management
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () async {
                await DebugHelper.saveCurrentSessionManually();
                await _automaticTracker.refreshTodayData();
                setState(() {}); // Refresh UI
              },
              child: const Text('Save Session'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Show confirmation dialog
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
                  setState(() {}); // Refresh UI
                }
              },
              child: const Text('Clear Data'),
            ),
            const Expanded(child: SizedBox()), // Spacer
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
        // Fourth row - Sync testing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () async {
                await DebugHelper.testImprovedSync();
              },
              child: const Text('New Sync'),
            ),
            ElevatedButton(
              onPressed: () async {
                await DebugHelper.compareSyncMethods();
              },
              child: const Text('Compare'),
            ),
            const Expanded(child: SizedBox()), // Spacer
          ],
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
      appBar: AppBar(
        title: Text(
          'TRIminder Dashboard',
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
        : Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.getMaxContentWidth(context),
              ),
              child: ListView.separated(
                padding: ResponsiveUtils.getScreenPadding(context),
                itemCount: _getDashboardWidgets().length,
                separatorBuilder: (context, index) => SizedBox(
                  height: ResponsiveUtils.getSpacing(context),
                ),
                itemBuilder: (context, index) => _getDashboardWidgets()[index],
              ),
            ),
          ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  final UserProfile? userProfile;
  
  const WelcomeCard({super.key, this.userProfile});

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
              'Welcome back, ${userProfile?.fullName ?? 'Student'}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * fontScale,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Text(
              'Ready to continue your digital wellness journey?',
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

class XPProgressCard extends StatelessWidget {
  final UserProfile? userProfile;
  
  const XPProgressCard({super.key, this.userProfile});

  @override
  Widget build(BuildContext context) {
    final xp = userProfile?.xp ?? 0;
    final level = userProfile?.level ?? 1;
    final progress = userProfile?.progressToNextLevel ?? 0.0;
    final levelProgress = userProfile?.currentLevelProgress ?? {'currentLevelXP': 0, 'requiredForNextLevel': 100, 'remaining': 100};
    final xpInCurrentLevel = levelProgress['currentLevelXP']!;
    final xpNeededForNextLevel = levelProgress['requiredForNextLevel']!;
    final xpRemaining = levelProgress['remaining']!;
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
                Text(
                  'Level $level',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            // Make this responsive for different screen sizes
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
                      'Level ${level + 1}',
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
                      'Level ${level + 1}',
                      style: TextStyle(fontSize: 14 * fontScale),
                    ),
                  ],
                ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
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
                    ? '$xpRemaining XP to Level ${level + 1}'
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
  const RankingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: const Center(
        child: Text(
          'Rankings Coming Soon!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Show logout confirmation
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop(); // Close dialog first
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        
                        try {
                          // Proper logout with session cleanup
                          await UserSessionManager().logoutCurrentUser();
                          
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loading dialog
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.of(context).pop(); // Close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logout error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            // Force navigation anyway
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Profile Coming Soon!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
