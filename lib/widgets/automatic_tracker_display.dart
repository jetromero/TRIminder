import 'package:flutter/material.dart';
import '../services/automatic_screen_tracker.dart';

/// Widget displaying automatic screen time tracking data
/// Shows wellness-focused metrics where LESS usage = BETTER scores
class AutomaticTrackerDisplay extends StatefulWidget {
  const AutomaticTrackerDisplay({super.key});

  @override
  State<AutomaticTrackerDisplay> createState() => _AutomaticTrackerDisplayState();
}

class _AutomaticTrackerDisplayState extends State<AutomaticTrackerDisplay> {
  late AutomaticScreenTracker _tracker;

  @override
  void initState() {
    super.initState();
    _tracker = AutomaticScreenTracker();
    _tracker.addListener(_onTrackerUpdate);
    _initializeTracking();
  }

  @override
  void dispose() {
    _tracker.removeListener(_onTrackerUpdate);
    super.dispose();
  }

  void _onTrackerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeTracking() async {
    await _tracker.startMonitoring();
  }

  Color _getWellnessColor() {
    switch (_tracker.wellnessRating) {
      case 'Excellent 🏆':
        return Colors.green;
      case 'Great 🥇':
        return Colors.lightGreen;
      case 'Good 🥈':
        return Colors.orange;
      case 'Fair 🥉':
        return Colors.deepOrange;
      case 'High ⚠️':
        return Colors.red;
      case 'Excessive 🚨':
        return Colors.red.shade800;
      default:
        return Colors.grey;
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
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: _tracker.isMonitoring ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Digital Wellness Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tracker.isMonitoring 
                                            ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _tracker.isMonitoring ? 'AUTO' : 'OFF',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _tracker.isMonitoring ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Today's Screen Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Screen Time',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tracker.todayScreenTime,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getWellnessColor(),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Digital Wellness',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tracker.wellnessRating,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getWellnessColor(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // XP Earned Today
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'XP Earned Today',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '+${_tracker.todayXP} XP',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_tracker.todayXP > 0)
                    Text(
                      'Less screen time = More XP!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            // Current Session (if screen is on)
            if (_tracker.currentSessionMinutes > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.smartphone,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current session: ${_tracker.currentSession}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Today's Badges
            if (_tracker.todayBadges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Today\'s Badges',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tracker.todayBadges
                    .map((badge) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],

            // Motivational Message
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getMotivationalMessage(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMotivationalMessage() {
    final minutes = _tracker.todayScreenTimeMinutes;
    
    if (minutes <= 60) {
      return 'Amazing! You\'re maintaining excellent digital wellness today! 🏆';
    } else if (minutes <= 120) {
      return 'Great job! You\'re keeping your screen time balanced. 🥇';
    } else if (minutes <= 180) {
      return 'Good progress! Consider taking more breaks from screens. 🥈';
    } else if (minutes <= 240) {
      return 'Try to reduce screen time for better digital wellness. 🥉';
    } else if (minutes <= 360) {
      return 'High screen time detected. Take regular breaks! ⚠️';
    } else {
      return 'Consider a digital detox - your wellness matters! 🚨';
    }
  }
}
