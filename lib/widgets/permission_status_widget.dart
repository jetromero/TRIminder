import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../utils/battery_optimization_helper.dart';

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
    _loadPermissionStatus();
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
    
    return PermissionStatusInfo(
      permissions: permissions,
      batteryOptimized: batteryOptimized,
      batteryStatus: batteryStatus,
      hasIssues: !batteryOptimized || permissions.values.any((status) => status != PermissionStatus.granted),
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
      ],
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required bool status,
    required String description,
  }) {
    return Row(
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
      ],
    );
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
      final result = await BatteryOptimizationHelper.requestBatteryOptimizationBypass();
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Battery optimization bypassed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        onPermissionChanged?.call();
      } else {
        await BatteryOptimizationHelper.showBatteryOptimizationDialog(context);
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

  Future<void> _fixAllPermissions(BuildContext context) async {
    // Fix battery optimization
    await _fixBatteryOptimization(context);
    
    // Fix notification permission
    if (Platform.isAndroid) {
      await _fixNotificationPermission(context);
    }
  }
}

/// Information about permission status
class PermissionStatusInfo {
  final Map<Permission, PermissionStatus> permissions;
  final bool batteryOptimized;
  final BatteryOptimizationStatus batteryStatus;
  final bool hasIssues;

  PermissionStatusInfo({
    required this.permissions,
    required this.batteryOptimized,
    required this.batteryStatus,
    required this.hasIssues,
  });
}
