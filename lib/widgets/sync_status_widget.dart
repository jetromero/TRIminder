import 'package:flutter/material.dart';
import '../services/improved_sync_service.dart';
import '../utils/responsive_utils.dart';

/// Widget to display sync status and allow manual sync trigger
class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  late ImprovedSyncService _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = ImprovedSyncService();
    _syncService.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    _syncService.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _syncService.getSyncStats();
    final isSyncing = stats['isSyncing'] as bool;
    final lastSync = stats['lastSuccessfulSync'] as String?;
    final hasErrors = stats['hasErrors'] as bool;
    final errorCount = stats['errorCount'] as int;

    return Card(
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  isSyncing 
                    ? Icons.sync 
                    : hasErrors 
                      ? Icons.sync_problem 
                      : Icons.cloud_done,
                  color: isSyncing 
                    ? Colors.blue 
                    : hasErrors 
                      ? Colors.orange 
                      : Colors.green,
                  size: ResponsiveUtils.getIconSize(context),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Expanded(
                  child: Text(
                    'Sync Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * 
                                ResponsiveUtils.getFontScale(context),
                    ),
                  ),
                ),
                if (!isSyncing)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: ResponsiveUtils.getIconSize(context, mobile: 20, tablet: 24, desktop: 28),
                    ),
                    onPressed: _forcSync,
                    tooltip: 'Force sync now',
                  ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),

            // Status info
            if (isSyncing) ...[
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Text(
                    'Syncing data...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * 
                                ResponsiveUtils.getFontScale(context),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    hasErrors ? Icons.warning : Icons.check_circle,
                    color: hasErrors ? Colors.orange : Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Expanded(
                    child: Text(
                      hasErrors 
                        ? 'Sync issues ($errorCount errors)'
                        : lastSync != null 
                          ? 'Last sync: ${_formatTime(lastSync)}'
                          : 'Not synced yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasErrors ? Colors.orange : Colors.green,
                        fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * 
                                  ResponsiveUtils.getFontScale(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Show errors if any
            if (hasErrors && !isSyncing) ...[
              SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: ResponsiveUtils.getIconSize(context, mobile: 16, tablet: 18, desktop: 20),
                    ),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    Expanded(
                      child: Text(
                        'Some data may not be synced. Tap refresh to retry.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * 
                                    ResponsiveUtils.getFontScale(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _forcSync() async {
    try {
      await _syncService.forceSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
