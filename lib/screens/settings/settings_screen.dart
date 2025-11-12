import 'package:flutter/material.dart';
import '../../widgets/permission_status_widget.dart';
import '../../utils/responsive_utils.dart';
import '../../services/supabase_service.dart';
import '../../models/user_models.dart';
import '../auth/login_screen.dart';
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
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              icon: Icons.person,
              title: 'Profile',
              index: 2,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(2);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings,
              title: 'Settings',
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
                  try {
                    await SupabaseService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')),
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
