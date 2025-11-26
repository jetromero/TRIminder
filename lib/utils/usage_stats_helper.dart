import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/usage_stats_service.dart';

/// Helper class for handling UsageStatsManager permission (PACKAGE_USAGE_STATS)
/// This permission enables per-app usage tracking for features like "Top Offenders List"
class UsageStatsHelper {
  static const String _promptFlagKey = 'pending_usage_stats_prompt';

  /// Check if UsageStats permission is granted
  static Future<bool> isUsageStatsPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await UsageStatsService.isPermissionGranted();
    } catch (e) {
      print('Error checking UsageStats permission: $e');
      return false;
    }
  }

  /// Get UsageStats permission status
  static Future<UsageStatsStatus> getUsageStatsStatus() async {
    if (!Platform.isAndroid) {
      return UsageStatsStatus(
        isGranted: false,
        requiresAttention: false,
      );
    }
    
    try {
      final isGranted = await isUsageStatsPermissionGranted();
      return UsageStatsStatus(
        isGranted: isGranted,
        requiresAttention: !isGranted,
      );
    } catch (e) {
      print('Error getting UsageStats status: $e');
      return UsageStatsStatus(
        isGranted: false,
        requiresAttention: true,
      );
    }
  }

  /// Request UsageStats permission (launches settings)
  static Future<bool> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await UsageStatsService.requestPermission();
    } catch (e) {
      print('Error requesting UsageStats permission: $e');
      return false;
    }
  }

  /// Show UsageStats permission setup dialog
  static Future<void> showUsageStatsDialog(BuildContext context) async {
    final status = await getUsageStatsStatus();
    
    // If permission is already granted, clear the pending flag and don't show dialog
    if (!status.requiresAttention) {
      await clearPromptPending();
      return;
    }
    
    // Only show dialog if permission is not granted and context is mounted
    if (!context.mounted) {
      return;
    }
    
    // Clear pending flag when we're about to show the dialog
    await clearPromptPending();
    
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Usage Tracking'),
        content: const Text(
          'TRIminder can track which apps you use to help you understand your digital habits. '
          'This enables features like "Top Offenders List" to show your most-used apps.\n\n'
          'This data stays on your device and is never synced to the cloud.\n\n'
          'Would you like to enable app usage tracking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    
    if (shouldOpen == true && context.mounted) {
      final launched = await requestUsageStatsPermission();
      if (!launched) {
        // Show error if settings couldn't be opened
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open settings. Please enable Usage Access manually in Settings → Apps → Special app access → Usage access'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  /// Mark that we should auto-prompt the user about UsageStats permission
  static Future<void> setPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptFlagKey, true);
  }

  /// Clear the auto-prompt flag
  static Future<void> clearPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_promptFlagKey);
  }

  /// Check whether we should auto-prompt the user
  static Future<bool> isPromptPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_promptFlagKey) ?? false;
  }
}

/// Status information about UsageStats permission
class UsageStatsStatus {
  final bool isGranted;
  final bool requiresAttention;

  UsageStatsStatus({
    required this.isGranted,
    required this.requiresAttention,
  });
}

