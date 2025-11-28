import 'package:flutter/material.dart';
import '../../models/badge_models.dart' as badge_models;
import '../../services/supabase_service.dart';
import '../../services/database_service.dart';
import '../../widgets/badges/badge_catalog_item.dart';
import '../../widgets/app_scaffold.dart';

/// Screen displaying all available badges organized by category
/// Shows both earned and unearned badges, with unearned badges grayed out
class BadgeCatalogScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;

  const BadgeCatalogScreen({
    super.key,
    this.onSelectTab,
  });

  @override
  State<BadgeCatalogScreen> createState() => _BadgeCatalogScreenState();
}

class _BadgeCatalogScreenState extends State<BadgeCatalogScreen> {
  bool _isLoading = true;
  List<badge_models.Badge> _allBadges = [];
  Set<int> _earnedBadgeIds = {};
  Map<int, int> _badgeLevels = {}; // badgeId -> level
  Map<int, int> _badgeCompletionCounts = {}; // badgeId -> completion count

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch all badges - try Supabase first, fallback to local
      List<badge_models.Badge> allBadges = [];
      final supabaseService = SupabaseService();
      final db = DatabaseService();

      if (await supabaseService.isConnected()) {
        try {
          allBadges = await supabaseService.getAllBadges();
        } catch (e) {
          print('Error fetching badges from Supabase: $e');
        }
      }

      // Fallback to local database if Supabase failed or returned empty
      if (allBadges.isEmpty) {
        try {
          allBadges = await db.getAllBadges();
        } catch (e) {
          print('Error fetching badges from local database: $e');
        }
      }

      // Fetch user's earned badges - try Supabase first, fallback to local
      Set<int> earnedIds = {};
      final badgeLevels = <int, int>{};
      final badgeCompletionCounts = <int, int>{};

      if (await supabaseService.isConnected()) {
        try {
          // Fetch from Supabase
          final supabaseUserBadges = await supabaseService.getUserBadges(userId);
          for (final badgeData in supabaseUserBadges) {
            final badgeId = badgeData['badgeId'] is int
                ? badgeData['badgeId']
                : int.tryParse(badgeData['badgeId']?.toString() ?? '0') ?? 0;
            if (badgeId > 0) {
              earnedIds.add(badgeId);
              badgeLevels[badgeId] = badgeData['level'] is int
                  ? badgeData['level']
                  : (badgeData['level'] != null
                      ? int.tryParse(badgeData['level'].toString()) ?? 1
                      : 1);
              badgeCompletionCounts[badgeId] =
                  badgeData['completionCount'] is int
                      ? badgeData['completionCount']
                      : (badgeData['completionCount'] != null
                          ? int.tryParse(
                                  badgeData['completionCount'].toString()) ??
                              1
                          : 1);
            }
          }
        } catch (e) {
          print('Error fetching user badges from Supabase: $e');
        }
      }

      // Fallback to local database if Supabase failed or returned empty
      if (earnedIds.isEmpty) {
        try {
          final localUserBadges = await db.getUserBadges(userId);
          for (final userBadge in localUserBadges) {
            earnedIds.add(userBadge.badgeId);
            badgeLevels[userBadge.badgeId] = userBadge.level;
            badgeCompletionCounts[userBadge.badgeId] =
                userBadge.completionCount;
          }
        } catch (e) {
          print('Error fetching user badges from local database: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allBadges = allBadges;
          _earnedBadgeIds = earnedIds;
          _badgeLevels = badgeLevels;
          _badgeCompletionCounts = badgeCompletionCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading badges: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<badge_models.Badge> _getBadgesByCategory(
      badge_models.BadgeCategory category) {
    return _allBadges
        .where((badge) => badge.category == category)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  IconData _getCategoryIcon(badge_models.BadgeCategory category) {
    switch (category) {
      case badge_models.BadgeCategory.daily:
        return Icons.today;
      case badge_models.BadgeCategory.weekly:
        return Icons.date_range;
      case badge_models.BadgeCategory.monthly:
        return Icons.calendar_month;
      case badge_models.BadgeCategory.streak:
        return Icons.local_fire_department;
      case badge_models.BadgeCategory.milestone:
        return Icons.flag;
      case badge_models.BadgeCategory.social:
        return Icons.people;
      case badge_models.BadgeCategory.special:
        return Icons.star;
    }
  }

  String _getCategoryTitle(badge_models.BadgeCategory category) {
    switch (category) {
      case badge_models.BadgeCategory.daily:
        return 'Daily Badges';
      case badge_models.BadgeCategory.weekly:
        return 'Weekly Badges';
      case badge_models.BadgeCategory.monthly:
        return 'Monthly Badges';
      case badge_models.BadgeCategory.streak:
        return 'Streak Badges';
      case badge_models.BadgeCategory.milestone:
        return 'Milestone Badges';
      case badge_models.BadgeCategory.social:
        return 'Social Badges';
      case badge_models.BadgeCategory.special:
        return 'Special Badges';
    }
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int badgeCount,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFa92d35),
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFa92d35).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$badgeCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFa92d35),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        appBar: AppBar(
          title: const Text('Badge Catalog'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Get all categories that have badges
    final categories = badge_models.BadgeCategory.values.where((category) {
      return _getBadgesByCategory(category).isNotEmpty;
    }).toList();

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Badge Catalog'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBadges,
        child: _allBadges.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No badges available',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Badges will appear here once they are added to the system',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary header
                    Card(
                      color: const Color(0xFFa92d35).withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.workspace_premium,
                              color: const Color(0xFFa92d35),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Badge Collection',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_earnedBadgeIds.length} of ${_allBadges.length} badges earned',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Badge categories
                    ...categories.map((category) {
                      final badges = _getBadgesByCategory(category);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            context,
                            icon: _getCategoryIcon(category),
                            title: _getCategoryTitle(category),
                            badgeCount: badges.length,
                          ),
                          const SizedBox(height: 12),
                          ...badges.map((badge) {
                            final isEarned = _earnedBadgeIds.contains(badge.id);
                            final level = _badgeLevels[badge.id];
                            final completionCount =
                                _badgeCompletionCounts[badge.id];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: BadgeCatalogItem(
                                badge: badge,
                                isEarned: isEarned,
                                level: level,
                                completionCount: completionCount,
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                        ],
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}


