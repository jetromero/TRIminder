import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../utils/battery_optimization_helper.dart';
import '../utils/app_hibernation_helper.dart';
import '../utils/usage_stats_helper.dart';

/// Widget that displays permission status and provides management options
class PermissionStatusWidget extends StatefulWidget {
  final VoidCallback? onPermissionChanged;
  
  const PermissionStatusWidget({
    super.key,
    this.onPermissionChanged,
  });

  @override
  State<PermissionStatusWidget> createState() => _PermissionStatusWidgetState();
}

class _PermissionStatusWidgetState extends State<PermissionStatusWidget> {
  bool _isLoading = true;
  PermissionStatusInfo? _statusInfo;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus().then((_) async {
      // Auto-show App Hibernation dialog if pending
      try {
        if (mounted && Platform.isAndroid) {
          final pending = await AppHibernationHelper.isPromptPending();
          if (pending) {
            await AppHibernationHelper.showAppHibernationDialog(context);
            await AppHibernationHelper.clearPromptPending();
            widget.onPermissionChanged?.call();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _loadPermissionStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final statusInfo = await _getPermissionStatusInfo();
      if (mounted) {
        setState(() {
          _statusInfo = statusInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading permission status: $e');
    }
  }

  Future<PermissionStatusInfo> _getPermissionStatusInfo() async {
    final permissions = <Permission, PermissionStatus>{};
    
    // Check notification permission (Android 13+)
    if (Platform.isAndroid) {
      permissions[Permission.notification] = await Permission.notification.status;
    }
    
    // Check battery optimization status
    final batteryOptimized = await BatteryOptimizationHelper.isBatteryOptimizationBypassed();
    final batteryStatus = await BatteryOptimizationHelper.getBatteryOptimizationStatus();
    
    // Check app hibernation status (Android 12+). Informational only.
    final appHibernationStatus = await AppHibernationHelper.getAppHibernationStatus();
    
    // Check UsageStats permission (for per-app tracking)
    final usageStatsStatus = await UsageStatsHelper.getUsageStatsStatus();
    
    // Has issues if battery optimization is not bypassed or permissions not granted.
    // App hibernation is informational only and does not affect overall "hasIssues".
    // UsageStats is optional (for per-app tracking) so it doesn't affect "hasIssues".
    final hasPermissionIssues = permissions.values.any((status) => status != PermissionStatus.granted);
    final hasIssues = !batteryOptimized || hasPermissionIssues;
    
    return PermissionStatusInfo(
      permissions: permissions,
      batteryOptimized: batteryOptimized,
      batteryStatus: batteryStatus,
      appHibernationStatus: appHibernationStatus,
      usageStatsStatus: usageStatsStatus,
      hasIssues: hasIssues,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    if (_statusInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 12),
              Text('Unable to check permissions'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _statusInfo!.hasIssues ? Icons.warning : Icons.check_circle,
                  color: _statusInfo!.hasIssues ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Permission Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_statusInfo!.hasIssues)
                  TextButton.icon(
                    onPressed: _showPermissionDialog,
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Fix'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPermissionList(),
            if (_statusInfo!.hasIssues) ...[
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionList() {
    return Column(
      children: [
        // Battery optimization status
        _buildPermissionItem(
          icon: Icons.battery_charging_full,
          title: 'Battery Optimization',
          status: _statusInfo!.batteryOptimized,
          description: _statusInfo!.batteryOptimized 
              ? 'Background tracking enabled'
              : 'Required for continuous tracking',
        ),
        
        // App hibernation status (Android 12+) - informational (neutral, no status icon)
        if (_statusInfo!.appHibernationStatus.isAvailable) ...[
          const SizedBox(height: 8),
          _buildAppHibernationItem(),
        ],
        
        // Notification permission status
        if (Platform.isAndroid) ...[
          const SizedBox(height: 8),
          _buildPermissionItem(
            icon: Icons.notifications,
            title: 'Notifications',
            status: _statusInfo!.permissions[Permission.notification] == PermissionStatus.granted,
            description: _statusInfo!.permissions[Permission.notification] == PermissionStatus.granted
                ? 'Foreground service notifications enabled'
                : 'Required for background service',
          ),
        ],
        
        // UsageStats permission status (optional, for per-app tracking)
        if (Platform.isAndroid) ...[
          const SizedBox(height: 8),
          _buildPermissionItem(
            icon: Icons.apps,
            title: 'App Usage Tracking',
            status: _statusInfo!.usageStatsStatus.isGranted,
            description: _statusInfo!.usageStatsStatus.isGranted
                ? 'Per-app usage tracking enabled'
                : 'Optional: Enables "Top Offenders" feature',
            onTap: () => _showUsageStatsDialog(),
          ),
        ],
      ],
    );
  }

  /// Build app hibernation item without status icon (informational only)
  Widget _buildAppHibernationItem() {
    return InkWell(
      onTap: () => _showAppHibernationDialog(),
      child: Row(
        children: [
          Icon(
            Icons.power_settings_new,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Hibernation',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Disable Unused Apps to ensure continuous tracking.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: () => _showAppHibernationDialog(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Learn more',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required bool status,
    required String description,
    VoidCallback? onTap,
  }) {
    final widget = Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: status ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Icon(
          status ? Icons.check_circle : Icons.warning,
          size: 16,
          color: status ? Colors.green : Colors.orange,
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Learn more',
          ),
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: widget,
      );
    }
    return widget;
  }

  void _showAppHibernationDialog() {
    AppHibernationHelper.showAppHibernationDialog(context).then((_) {
      _loadPermissionStatus();
      widget.onPermissionChanged?.call();
    });
  }

  void _showUsageStatsDialog() {
    UsageStatsHelper.showUsageStatsDialog(context).then((_) {
      _loadPermissionStatus();
      widget.onPermissionChanged?.call();
    });
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showPermissionDialog,
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Fix Permissions'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => PermissionSetupDialog(
        statusInfo: _statusInfo!,
        onPermissionChanged: () {
          _loadPermissionStatus();
          widget.onPermissionChanged?.call();
        },
      ),
    );
  }

  void _refreshStatus() {
    _loadPermissionStatus();
  }
}

/// Dialog for setting up permissions
class PermissionSetupDialog extends StatelessWidget {
  final PermissionStatusInfo statusInfo;
  final VoidCallback? onPermissionChanged;

  const PermissionSetupDialog({
    super.key,
    required this.statusInfo,
    this.onPermissionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Permission Setup'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TRIminder needs these permissions to track your screen time automatically:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Battery optimization section
            _buildPermissionSection(
              context,
              icon: Icons.battery_charging_full,
              title: 'Battery Optimization',
              description: 'Allows TRIminder to run in the background and track screen time even when the phone is idle.',
              isGranted: statusInfo.batteryOptimized,
              onFix: () => _fixBatteryOptimization(context),
            ),
            
            const SizedBox(height: 16),
            
            // App hibernation section (Android 12+)
            if (statusInfo.appHibernationStatus.isAvailable) ...[
              _buildPermissionSection(
                context,
                icon: Icons.power_settings_new,
                title: 'App Hibernation',
                description: 'Android can revoke permissions for unused apps. Tap to review and adjust the setting.',
                isGranted: true, // neutral - treated as informational
                onFix: () => _fixAppHibernation(context),
              ),
              const SizedBox(height: 16),
            ],
            
            // Notification permission section
            if (Platform.isAndroid) ...[
              _buildPermissionSection(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                description: 'Required for the foreground service that tracks your screen time.',
                isGranted: statusInfo.permissions[Permission.notification] == PermissionStatus.granted,
                onFix: () => _fixNotificationPermission(context),
              ),
              const SizedBox(height: 16),
            ],
            
            // UsageStats permission section (optional)
            if (Platform.isAndroid) ...[
              _buildPermissionSection(
                context,
                icon: Icons.apps,
                title: 'App Usage Tracking',
                description: 'Optional: Enables per-app usage tracking to show which apps you use most. This data stays on your device.',
                isGranted: statusInfo.usageStatsStatus.isGranted,
                onFix: () => _fixUsageStatsPermission(context),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _fixAllPermissions(context);
            Navigator.of(context).pop();
          },
          child: const Text('Fix All'),
        ),
      ],
    );
  }

  Widget _buildPermissionSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onFix,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isGranted ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  isGranted ? Icons.check_circle : Icons.warning,
                  color: isGranted ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (!isGranted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onFix,
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Fix This Permission'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fixBatteryOptimization(BuildContext context) async {
    try {
      // Show dialog that redirects to settings (no auto-request)
      await BatteryOptimizationHelper.showBatteryOptimizationDialog(context);
      // Callback will trigger parent widget to refresh permission status
      onPermissionChanged?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fixNotificationPermission(BuildContext context) async {
    try {
      final status = await Permission.notification.request();
      if (status == PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission granted!'),
            backgroundColor: Colors.green,
          ),
        );
        onPermissionChanged?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission denied. Please enable it in Settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fixAppHibernation(BuildContext context) async {
    try {
      await AppHibernationHelper.showAppHibernationDialog(context);
      onPermissionChanged?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fixUsageStatsPermission(BuildContext context) async {
    try {
      await UsageStatsHelper.showUsageStatsDialog(context);
      onPermissionChanged?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fixAllPermissions(BuildContext context) async {
    // Fix battery optimization
    await _fixBatteryOptimization(context);
    
    // Fix app hibernation (Android 12+)
    if (statusInfo.appHibernationStatus.isAvailable && statusInfo.appHibernationStatus.requiresAttention) {
      await _fixAppHibernation(context);
    }
    
    // Fix notification permission
    if (Platform.isAndroid) {
      await _fixNotificationPermission(context);
    }
    
    // Note: UsageStats is optional, so we don't force it in "Fix All"
  }
}

/// Information about permission status
class PermissionStatusInfo {
  final Map<Permission, PermissionStatus> permissions;
  final bool batteryOptimized;
  final BatteryOptimizationStatus batteryStatus;
  final AppHibernationStatus appHibernationStatus;
  final UsageStatsStatus usageStatsStatus;
  final bool hasIssues;

  PermissionStatusInfo({
    required this.permissions,
    required this.batteryOptimized,
    required this.batteryStatus,
    required this.appHibernationStatus,
    required this.usageStatsStatus,
    required this.hasIssues,
  });
}
