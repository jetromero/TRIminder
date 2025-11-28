import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable avatar widget with fallback to initials
class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final double size;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool forceRefresh; // Add cache-busting parameter

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 40.0,
    this.onTap,
    this.backgroundColor,
    this.forceRefresh = false,
  });

  /// Small avatar (40x40) for rankings
  const AvatarWidget.small({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 40.0,
    this.onTap,
    this.backgroundColor,
    this.forceRefresh = false,
  });

  /// Medium avatar (80x80) for profile headers
  const AvatarWidget.medium({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 80.0,
    this.onTap,
    this.backgroundColor,
    this.forceRefresh = false,
  });

  /// Large avatar (120x120) for profile pages
  const AvatarWidget.large({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 120.0,
    this.onTap,
    this.backgroundColor,
    this.forceRefresh = false,
  });

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getColorFromName(String? name) {
    // Use a neutral gray color for all avatars without photos
    return const Color(0xFF9E9E9E); // Material Grey 500
  }

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? _getColorFromName(fullName),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
      child: avatarUrl != null && avatarUrl!.isNotEmpty
          ? ClipOval(
              child: Builder(
                builder: (context) {
                  // Clear cache if forceRefresh is true
                  if (forceRefresh) {
                    final baseUrl = avatarUrl!.split('?').first;
                    // Clear cache BEFORE loading new image
                    CachedNetworkImage.evictFromCache(baseUrl);
                    // Use NetworkImage directly when forcing refresh to bypass cache
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    return Image.network(
                      '$baseUrl?t=$timestamp',
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => _buildInitialsWidget(),
                    );
                  }
                  // Use CachedNetworkImage for offline support and performance
                  // Add timestamp to force network check when online, but use base URL as cache key
                  final baseUrl = avatarUrl!.split('?').first;
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  return CachedNetworkImage(
                    imageUrl: '$baseUrl?t=$timestamp', // Timestamp forces network check
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildInitialsWidget(),
                    // Cache images to disk for offline access
                    // Use base URL as cache key so cache is shared (timestamp doesn't affect caching)
                    cacheKey: baseUrl,
                    maxWidthDiskCache: (size * 2).toInt(), // Cache at 2x resolution for better quality
                    maxHeightDiskCache: (size * 2).toInt(),
                  );
                },
              ),
            )
          : _buildInitialsWidget(),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildInitialsWidget() {
    return Center(
      child: Text(
        _getInitials(fullName),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

