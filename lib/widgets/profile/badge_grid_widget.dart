import 'package:flutter/material.dart';
import '../../utils/responsive_utils.dart';

/// Widget to display badges in a grid layout
class BadgeGridWidget extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  final bool isLoading;

  const BadgeGridWidget({
    super.key,
    required this.badges,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (badges.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No badges earned yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete challenges to earn badges!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final crossAxisCount = ResponsiveUtils.isMobile(context) ? 3 : ResponsiveUtils.isTablet(context) ? 4 : 5;
    final spacing = ResponsiveUtils.getSpacing(context, mobile: 8.0, tablet: 12.0, desktop: 16.0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 0.9,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badgeData = badges[index];
        final badge = badgeData['badge'] as Map<String, dynamic>;
        final awardedAt = badgeData['awardedAt'] as DateTime;

        return _BadgeItem(
          name: badge['name'] as String? ?? 'Unknown',
          description: badge['description'] as String?,
          iconUrl: badge['iconUrl'] as String?,
          awardedAt: awardedAt,
        );
      },
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final String name;
  final String? description;
  final String? iconUrl;
  final DateTime awardedAt;

  const _BadgeItem({
    required this.name,
    this.description,
    this.iconUrl,
    required this.awardedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description ?? name,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge icon
              Expanded(
                child: iconUrl != null && iconUrl!.isNotEmpty
                    ? Image.network(
                        iconUrl!,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultIcon();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        },
                      )
                    : _buildDefaultIcon(),
              ),
              const SizedBox(height: 4),
              // Badge name
              Text(
                name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultIcon() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.emoji_events,
        color: Colors.amber,
        size: 32,
      ),
    );
  }
}


