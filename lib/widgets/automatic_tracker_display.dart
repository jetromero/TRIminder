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
    final fontScale = ResponsiveUtils.getFontScale(context);
    
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
                  Icons.auto_awesome,
                  color: _tracker.isMonitoring ? Colors.green : Colors.grey,
                  size: ResponsiveUtils.getIconSize(context),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                Expanded(
                  child: Text(
                    'Digital Wellness Tracker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * fontScale,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12), 
                    vertical: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                  ),
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
                      fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),

            // Today's Screen Time - Responsive layout
            context.isMobile 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScreenTimeSection(context, fontScale),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                    _buildWellnessSection(context, fontScale),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScreenTimeSection(context, fontScale),
                    _buildWellnessSection(context, fontScale),
                  ],
                ),
            SizedBox(height: ResponsiveUtils.getSpacing(context)),

            // XP Earned Today
            Container(
              padding: ResponsiveUtils.getCardPadding(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: context.isMobile
                ? Column(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Potential XP Today',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                                ),
                              ),
                              Text(
                                '+${_tracker.todayXP} XP',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                  fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) * fontScale,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_tracker.todayXP > 0) ...[
                        SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                        Text(
                          'XP awarded at end of day!',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade700,
                            fontStyle: FontStyle.italic,
                            fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.star, 
                        color: Colors.amber, 
                        size: ResponsiveUtils.getIconSize(context),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Potential XP Today',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
                            ),
                          ),
                          Text(
                            '+${_tracker.todayXP} XP',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                              fontSize: (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) * fontScale,
                            ),
                          ),
                        ],
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
            ),

            // Current Session (if screen is on)
            if (_tracker.currentSessionMinutes > 0) ...[
              SizedBox(height: ResponsiveUtils.getSpacing(context)),
              Container(
                padding: ResponsiveUtils.getCardPadding(context),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.smartphone,
                      color: Colors.blue,
                      size: ResponsiveUtils.getIconSize(context, mobile: 20, tablet: 24, desktop: 28),
                    ),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                    Expanded(
                      child: Text(
                        'Current session: ${_tracker.currentSession}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * fontScale,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Today's Badges
            if (_tracker.todayBadges.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.getSpacing(context)),
              Text(
                'Today\'s Badges',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (Theme.of(context).textTheme.titleSmall?.fontSize ?? 14) * fontScale,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
              Wrap(
                spacing: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                runSpacing: ResponsiveUtils.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
                children: _tracker.todayBadges
                    .map((badge) => Container(
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
                        ))
                    .toList(),
              ),
            ],

            // Motivational Message
            SizedBox(height: ResponsiveUtils.getSpacing(context)),
            Container(
              padding: ResponsiveUtils.getCardPadding(context),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: ResponsiveUtils.getIconSize(context, mobile: 20, tablet: 24, desktop: 28),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                  Expanded(
                    child: Text(
                      _getMotivationalMessage(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * fontScale,
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
