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

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 40.0,
    this.onTap,
    this.backgroundColor,
  });

  /// Small avatar (40x40) for rankings
  const AvatarWidget.small({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 40.0,
    this.onTap,
    this.backgroundColor,
  });

  /// Medium avatar (80x80) for profile headers
  const AvatarWidget.medium({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 80.0,
    this.onTap,
    this.backgroundColor,
  });

  /// Large avatar (120x120) for profile pages
  const AvatarWidget.large({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 120.0,
    this.onTap,
    this.backgroundColor,
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
    if (name == null || name.isEmpty) {
      return Colors.grey;
    }
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];
    final index = name.hashCode % colors.length;
    return colors[index.abs()];
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
              child: CachedNetworkImage(
                imageUrl: avatarUrl!,
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
                cacheKey: avatarUrl!,
                maxWidthDiskCache: (size * 2).toInt(), // Cache at 2x resolution for better quality
                maxHeightDiskCache: (size * 2).toInt(),
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

