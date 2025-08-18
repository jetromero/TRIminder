import 'package:flutter/material.dart';
import '../services/screen_time_service.dart';

/// Widget for controlling screen time tracking
/// Shows current session, today's total, and start/stop controls
class ScreenTimeTracker extends StatefulWidget {
  const ScreenTimeTracker({super.key});

  @override
  State<ScreenTimeTracker> createState() => _ScreenTimeTrackerState();
}

class _ScreenTimeTrackerState extends State<ScreenTimeTracker> {
  late ScreenTimeService _screenTimeService;

  @override
  void initState() {
    super.initState();
    _screenTimeService = ScreenTimeService();
    _screenTimeService.addListener(_onTrackingUpdate);
    _screenTimeService.loadTodayTotal();
  }

  @override
  void dispose() {
    _screenTimeService.removeListener(_onTrackingUpdate);
    super.dispose();
  }

  void _onTrackingUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleTracking() async {
    if (_screenTimeService.isTracking) {
      await _screenTimeService.stopTracking();
      _showSessionSummary();
    } else {
      await _screenTimeService.startTracking();
    }
  }

  void _showSessionSummary() {
    if (_screenTimeService.sessionXP > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.amber),
              SizedBox(width: 8),
              Text('Session Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Tracked: ${_screenTimeService.sessionDuration}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'XP Earned: +${_screenTimeService.sessionXP}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_screenTimeService.sessionBadges.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Badges Earned:'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: _screenTimeService.sessionBadges
                      .map((badge) => Chip(
                            label: Text(badge),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
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
                  Icons.timer,
                  color: _screenTimeService.isTracking 
                      ? Colors.green 
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Screen Time Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _screenTimeService.isTracking 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _screenTimeService.isTracking ? 'ACTIVE' : 'STOPPED',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _screenTimeService.isTracking ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current Session
            if (_screenTimeService.isTracking) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Session',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _screenTimeService.sessionDuration,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'XP Earning',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(
                            '+${_screenTimeService.sessionXP}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Today's Total
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _screenTimeService.todayTotal,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Control Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _toggleTracking,
                icon: Icon(_screenTimeService.isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(_screenTimeService.isTracking ? 'Stop Tracking' : 'Start Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _screenTimeService.isTracking 
                      ? Colors.red 
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Quick Tips
            if (!_screenTimeService.isTracking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Track your screen time to earn XP and unlock badges!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}
