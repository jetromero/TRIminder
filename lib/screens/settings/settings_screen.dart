import 'package:flutter/material.dart';
import '../../widgets/permission_status_widget.dart';
import '../../utils/responsive_utils.dart';
import '../../services/supabase_service.dart';
import '../../services/user_session_manager.dart';
import '../../services/database_service.dart';
import '../../models/user_models.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../auth/login_screen.dart';
import '../profile/student_profile_screen.dart';
import '../../config/app_config.dart';
import '../../widgets/app_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  
  const SettingsScreen({super.key, this.onSelectTab});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isDeletingAccount = false;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        final profile = await SupabaseService().getUserProfile(userId);
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading user data: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20 * ResponsiveUtils.getFontScale(context),
          ),
        ),
        centerTitle: true,
      ),
      drawer: _AppDrawer(
        onSelectTab: widget.onSelectTab ?? (index) {},
        currentScreenIndex: 200, // Settings screen index
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.getMaxContentWidth(context),
                ),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: ResponsiveUtils.getScreenPadding(context),
                  children: [
                    const SizedBox(height: 16),
                    
                    // User Profile Section
                    _buildUserProfileSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Permissions Section
                    _buildPermissionsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // App Settings Section
                    _buildAppSettingsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Data Management Section
                    _buildDataManagementSection(),
                    
                    const SizedBox(height: 24),
                    
                    // App Information Section
                    _buildAppInformationSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Sign Out Section
                    _buildSignOutSection(),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_userProfile != null) ...[
              _buildInfoRow('Name', _userProfile!.fullName),
              _buildInfoRow('Email', _userProfile!.email),
              if (_userProfile!.userTag != null)
                _buildInfoRow('User Tag', '@${_userProfile!.userTag}'),
              _buildInfoRow('XP', '${_userProfile!.xp} points'),
            ] else ...[
              const Text('Unable to load profile information'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.security,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const PermissionStatusWidget(),
      ],
    );
  }

  Widget _buildAppSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () {
                // TODO: Implement notification settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.dark_mode,
              title: 'Theme',
              subtitle: 'Light, Dark, or System',
              onTap: () {
                // TODO: Implement theme settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme settings coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.sync,
              title: 'Auto Sync',
              subtitle: 'Automatically sync data',
              onTap: () {
                // TODO: Implement sync settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync settings coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.cloud_sync,
              title: 'Sync Data',
              subtitle: 'Manually sync with cloud',
              onTap: () {
                // TODO: Implement manual sync
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual sync coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.download,
              title: 'Export Data',
              subtitle: 'Download your data',
              onTap: () {
                // TODO: Implement data export
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data export coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.delete_sweep,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () {
                // TODO: Implement cache clearing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache clearing coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInformationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', AppConfig.appVersion),
            _buildInfoRow('Build', '1'),
            _buildInfoRow('Platform', 'Android'),
            const SizedBox(height: 8),
            _buildSettingsItem(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: () {
                // TODO: Implement help section
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help section coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                // TODO: Implement privacy policy viewer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy policy viewer coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeletingAccount ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeletingAccount ? null : _showDeleteAccountConfirmation,
                icon: const Icon(Icons.delete_forever),
                label: _isDeletingAccount 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmation() async {
    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.\n\n'
          'All your data including:\n'
          '• Screen time history\n'
          '• XP and achievements\n'
          '• Friends and social connections\n'
          '• All account information\n\n'
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation dialog with text input
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Final Confirmation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is your last chance to cancel. Type "DELETE" in the box below to confirm account deletion.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  border: OutlineInputBorder(),
                  errorText: null,
                ),
                onChanged: (value) {
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: textController.text.trim() == 'DELETE'
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Proceed with account deletion
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final sessionManager = UserSessionManager();
      final success = await sessionManager.deleteAccount();

      if (!mounted) return;

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deletion failed. Please try again or contact support if the problem persists.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting account: ${e.toString()}\n\n'
            'Your local data has been deleted. If you were offline, cloud data deletion may be pending.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );

      // Still navigate to login screen even on error
      // since local data is likely deleted
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// App-wide navigation drawer used in Settings screen
class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  final int currentScreenIndex;
  
  const _AppDrawer({
    required this.onSelectTab,
    this.currentScreenIndex = 200, // Default to Settings
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
            // Profile header section (matching home screen drawer)
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

  /// Load current user profile for drawer header (optimized version)
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
