import 'package:flutter/material.dart';
import '../../models/badge_models.dart' as badge_models;
import '../../utils/badge_icon_helper.dart';

/// Widget to display a badge item in the catalog
/// Shows earned badges normally and unearned badges grayed out
class BadgeCatalogItem extends StatelessWidget {
  final badge_models.Badge badge;
  final bool isEarned;
  final int? level;
  final int? completionCount;

  const BadgeCatalogItem({
    super.key,
    required this.badge,
    required this.isEarned,
    this.level,
    this.completionCount,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isEarned ? 1.0 : 0.5;
    final currentLevel = level ?? 1;
    final currentCompletionCount = completionCount ?? 0;

    return Card(
      elevation: isEarned ? 2 : 1,
      child: Opacity(
        opacity: opacity,
        child: ColorFiltered(
          colorFilter: isEarned
              ? const ColorFilter.mode(Colors.transparent, BlendMode.color)
              : const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge icon
                Stack(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: BadgeIconHelper.getRarityColor(badge.rarity)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: BadgeIconHelper.getBadgeIcon(
                          iconUrl: badge.iconUrl,
                          category: badge.category,
                          rarity: badge.rarity,
                          size: 40,
                        ),
                      ),
                    ),
                    // Level indicator
                    if (isEarned && currentLevel > 1)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFa92d35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'Lv.$currentLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Badge details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge name
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badge.name,
                              style: Theme.of(context)
                                  .textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          // XP reward chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BadgeIconHelper.getRarityColor(badge.rarity)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: BadgeIconHelper.getRarityColor(
                                    badge.rarity,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${badge.xpReward} XP',
                                  style: Theme.of(context)
                                      .textTheme.bodySmall
                                      ?.copyWith(
                                        color: BadgeIconHelper.getRarityColor(
                                          badge.rarity,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Description
                      if (badge.description != null &&
                          badge.description!.isNotEmpty)
                        Text(
                          badge.description!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                        ),
                      const SizedBox(height: 8),
                      // Level thresholds
                      if (badge.levelThresholds != null &&
                          badge.levelThresholds!.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Levels:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            ...badge.levelThresholds!.asMap().entries.map((entry) {
                              final levelIndex = entry.key;
                              final threshold = entry.value;
                              final isReached = isEarned &&
                                  currentCompletionCount >= threshold;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isReached
                                      ? const Color(0xFFa92d35).withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isReached
                                        ? const Color(0xFFa92d35)
                                        : Colors.grey,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'L${levelIndex + 1}: $threshold',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isReached
                                            ? const Color(0xFFa92d35)
                                            : Colors.grey,
                                        fontWeight: isReached
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                ),
                              );
                            }),
                          ],
                        ),
                      // Required value if available
                      if (badge.requiredValue != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Requirement: ${badge.requiredValue}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

