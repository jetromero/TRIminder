import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/badge_models.dart';

/// Helper class for badge icon display and rarity color mapping
class BadgeIconHelper {
  /// Get color based on badge rarity
  /// 
  /// Returns:
  /// - Common: Gray (#808080)
  /// - Rare: Blue (#4169E1)
  /// - Epic: Purple (#9370DB)
  /// - Legendary: Gold (#FFD700)
  static Color getRarityColor(BadgeRarity rarity) {
    switch (rarity) {
      case BadgeRarity.common:
        return const Color(0xFF808080); // Gray
      case BadgeRarity.rare:
        return const Color(0xFF4169E1); // Royal Blue
      case BadgeRarity.epic:
        return const Color(0xFF9370DB); // Medium Purple
      case BadgeRarity.legendary:
        return const Color(0xFFFFD700); // Gold
    }
  }

  /// Get badge icon widget
  /// 
  /// Parameters:
  /// - iconUrl: Optional URL to badge icon image
  /// - category: Badge category (used for fallback icon)
  /// - rarity: Badge rarity (used for fallback icon color)
  /// - size: Size of the icon (default: 24)
  /// 
  /// Returns:
  /// - Image widget if iconUrl is provided and valid
  /// - Icon widget with category-appropriate icon otherwise
  static Widget getBadgeIcon({
    String? iconUrl,
    required BadgeCategory category,
    required BadgeRarity rarity,
    double size = 24,
  }) {
    // If iconUrl is provided and not empty, try to load it
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(getRarityColor(rarity)),
          ),
        ),
        errorWidget: (context, url, error) => _getDefaultIcon(
          category: category,
          rarity: rarity,
          size: size,
        ),
      );
    }

    // Return default icon based on category
    return _getDefaultIcon(
      category: category,
      rarity: rarity,
      size: size,
    );
  }

  /// Get default icon based on badge category
  static Widget _getDefaultIcon({
    required BadgeCategory category,
    required BadgeRarity rarity,
    required double size,
  }) {
    final color = getRarityColor(rarity);
    final iconData = _getCategoryIcon(category);

    return Icon(
      iconData,
      color: color,
      size: size,
    );
  }

  /// Get appropriate icon data based on badge category
  static IconData _getCategoryIcon(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.daily:
        return Icons.today;
      case BadgeCategory.weekly:
        return Icons.date_range;
      case BadgeCategory.monthly:
        return Icons.calendar_month;
      case BadgeCategory.streak:
        return Icons.local_fire_department;
      case BadgeCategory.milestone:
        return Icons.flag;
      case BadgeCategory.social:
        return Icons.people;
      case BadgeCategory.special:
        return Icons.star;
    }
  }
}

