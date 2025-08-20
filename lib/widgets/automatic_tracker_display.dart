import 'package:flutter/material.dart';
import '../services/automatic_screen_tracker.dart';
import '../utils/responsive_utils.dart';

/// Widget displaying automatic screen time tracking data
/// Shows wellness-focused metrics where LESS usage = BETTER scores
class AutomaticTrackerDisplay extends StatefulWidget {
  const AutomaticTrackerDisplay({super.key});

  @override
  State<AutomaticTrackerDisplay> createState() => _AutomaticTrackerDisplayState();
}

class _AutomaticTrackerDisplayState extends State<AutomaticTrackerDisplay> {
  late AutomaticScreenTracker _tracker;
  DateTime _lastUpdate = DateTime.now();

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
      _lastUpdate = DateTime.now();
      print('🔄 AutomaticTrackerDisplay: Listener triggered, updating UI at ${_lastUpdate.toLocal()}');
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
    return ListenableBuilder(
      listenable: _tracker,
      builder: (context, child) {
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final fontScale = ResponsiveUtils.getFontScale(context);
    
    return Container(
      padding: ResponsiveUtils.getCardPadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and XP info
          Row(
            children: [
              Icon(
                Icons.smartphone,
                color: _getWellnessColor(),
                size: ResponsiveUtils.getIconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen Time',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * fontScale,
                      ),
                    ),
                    Text(
                      _tracker.wellnessRating,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getWellnessColor(),
                        fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_tracker.todayXP > 0)
                Flexible(
                  child: Text(
                    'XP awarded at end of day!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade700,
                      fontStyle: FontStyle.italic,
                      fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),

          // Current session indicator removed for consistency

          // Today's Badges
          if (_tracker.todayBadges.isNotEmpty) ...[
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            Wrap(
              spacing: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
              runSpacing: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
              children: _tracker.todayBadges.map((badge) => _buildBadge(context, badge, fontScale)).toList(),
            ),
          ],

          // Main stats section
          SizedBox(height: ResponsiveUtils.getSpacing(context)),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Tablet/Desktop layout
                return Row(
                  children: [
                    Expanded(child: _buildScreenTimeSection(context, fontScale)),
                    SizedBox(width: ResponsiveUtils.getSpacing(context)),
                    Expanded(child: _buildWellnessSection(context, fontScale)),
                  ],
                );
              } else {
                // Mobile layout
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScreenTimeSection(context, fontScale),
                    SizedBox(height: ResponsiveUtils.getSpacing(context)),
                    _buildWellnessSection(context, fontScale),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeSection(BuildContext context, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Screen Time',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
        Text(
          _tracker.todayScreenTime,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: _getWellnessColor(),
            fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * fontScale,
          ),
        ),
        // Live session indicator removed for consistency
      ],
    );
  }

  Widget _buildWellnessSection(BuildContext context, double fontScale) {
    return Column(
      crossAxisAlignment: context.isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          'Digital Wellness',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
        Text(
          _tracker.wellnessRating,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: _getWellnessColor(),
            fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * fontScale,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String badge, double fontScale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12),
        vertical: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
      ),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badge,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green.shade700,
          fontWeight: FontWeight.w500,
          fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
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
