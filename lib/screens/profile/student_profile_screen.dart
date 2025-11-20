import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../services/database_service.dart';
import '../../models/user_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../../widgets/profile/badge_grid_widget.dart';
import '../../utils/responsive_utils.dart';
import 'edit_profile_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final String? userId; // null = own profile

  const StudentProfileScreen({
    super.key,
    this.userId,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  UserProfile? _profile;
  List<Map<String, dynamic>> _badges = [];
  String? _friendshipStatus;
  int _friendsCount = 0;
  String? _departmentName;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  bool _isOffline = false;
  int _avatarRefreshKey = 0; // Key to force avatar refresh
  int _coverPhotoRefreshKey = 0; // Key to force cover photo refresh

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Update friendship status and optionally friends count without reloading entire profile
  /// This prevents unnecessary page reloads for all friend actions
  /// [updateFriendsCount] - whether to update friends count (true for accept/unfriend)
  Future<void> _updateFriendshipData({bool updateFriendsCount = false}) async {
    if (_profile == null) return;
    
    try {
      final supabaseService = SupabaseService();
      final isConnected = await supabaseService.isConnected();
      final currentUserId = SupabaseService().currentUserId;
      final targetUserId = widget.userId ?? currentUserId;
      final isOwnProfile = targetUserId == currentUserId;
      
      if (isConnected && targetUserId != null) {
        // Update friends count only if requested (for accept/unfriend actions)
        int? friendsCount;
        if (updateFriendsCount) {
          try {
            friendsCount = await supabaseService.getFriendsCountForUser(targetUserId);
          } catch (e) {
            print('Friends count update failed: $e');
          }
        }
        
        // Always update friendship status if viewing other user's profile
        // This ensures consistency after any action (send, cancel, accept, unfriend)
        String? friendshipStatus;
        if (!isOwnProfile && currentUserId != null) {
          try {
            friendshipStatus = await supabaseService.getFriendshipStatus(targetUserId);
          } catch (e) {
            print('Friendship status update failed: $e');
          }
        }
        
        if (mounted) {
          setState(() {
            if (friendsCount != null) {
              _friendsCount = friendsCount;
            }
            if (friendshipStatus != null) {
              _friendshipStatus = friendshipStatus;
            }
          });
        }
      }
    } catch (e) {
      print('Error updating friendship data: $e');
      // If update fails, fall back to full reload only if critical
      if (updateFriendsCount && mounted) {
        await _loadProfile();
      }
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = SupabaseService().currentUserId;
      final targetUserId = widget.userId ?? currentUserId;
      _isOwnProfile = targetUserId == currentUserId;

      // Check connectivity
      final supabaseService = SupabaseService();
      final isConnected = await supabaseService.isConnected();
      final db = DatabaseService();

      // Load profile - try Supabase first, fallback to local database
      UserProfile? profile;
      
      // Get local profile first to track old URLs
      final localProfile = await db.getUserProfile(targetUserId ?? '');
      
      if (isConnected) {
        try {
          profile = await supabaseService.getUserProfileById(targetUserId ?? '');
          
          // CRITICAL: Always prioritize local DB URLs if they differ from Supabase
          // This prevents stale Supabase data from overwriting fresh local data
          // Local DB has the correct URLs we just uploaded, even if Supabase hasn't propagated yet
          if (profile != null && localProfile != null) {
            // Check if local DB has different URLs than Supabase
            final bool localHasDifferentAvatar = localProfile.avatarUrl != null && 
                localProfile.avatarUrl!.isNotEmpty &&
                localProfile.avatarUrl != profile.avatarUrl;
            final bool localHasDifferentCover = localProfile.coverPhotoUrl != null && 
                localProfile.coverPhotoUrl!.isNotEmpty &&
                localProfile.coverPhotoUrl != profile.coverPhotoUrl;
            
            // If local DB has different URLs, use local URLs (they're the ones we just uploaded)
            // This handles the case where Supabase hasn't propagated changes yet
            if (localHasDifferentAvatar || localHasDifferentCover) {
              print('⚠️ Using local DB URLs (differ from Supabase - likely just uploaded)');
              // Merge: use local URLs but keep other Supabase data
              profile = profile.copyWith(
                avatarUrl: localHasDifferentAvatar ? localProfile.avatarUrl : profile.avatarUrl,
                coverPhotoUrl: localHasDifferentCover ? localProfile.coverPhotoUrl : profile.coverPhotoUrl,
              );
            }
          }
          
          // Update local database with fresh profile from Supabase to keep it in sync
          // But only if we're not using local data due to stale Supabase data
          if (profile != null && profile != localProfile) {
            try {
              // Save fresh profile to local database so we have correct data if Supabase fails next time
              await db.insertUserProfile(profile);
            } catch (e) {
              print('Error updating local database: $e');
              // Don't fail profile load if local update fails
            }
          }
          
          // Clear cache AFTER fetching new profile data, using NEW URLs
          // Only clear old URLs if they differ from new URLs
          if (profile != null && localProfile != null) {
            try {
              // Clear old avatar cache if URL changed
              if (localProfile.avatarUrl != null && 
                  localProfile.avatarUrl!.isNotEmpty &&
                  localProfile.avatarUrl != profile.avatarUrl) {
                final oldAvatarUrl = localProfile.avatarUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(oldAvatarUrl);
              }
              // Clear new avatar cache to ensure fresh image
              if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
                final avatarUrl = profile.avatarUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(avatarUrl);
              }
              
              // Clear old cover photo cache if URL changed
              if (localProfile.coverPhotoUrl != null && 
                  localProfile.coverPhotoUrl!.isNotEmpty &&
                  localProfile.coverPhotoUrl != profile.coverPhotoUrl) {
                final oldCoverUrl = localProfile.coverPhotoUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(oldCoverUrl);
              }
              // Clear new cover photo cache to ensure fresh image
              if (profile.coverPhotoUrl != null && profile.coverPhotoUrl!.isNotEmpty) {
                final coverUrl = profile.coverPhotoUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(coverUrl);
              }
            } catch (e) {
              print('Error clearing image cache: $e');
            }
          } else if (profile != null) {
            // No local profile to compare, just clear cache for new URLs
            try {
              if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
                final avatarUrl = profile.avatarUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(avatarUrl);
              }
              if (profile.coverPhotoUrl != null && profile.coverPhotoUrl!.isNotEmpty) {
                final coverUrl = profile.coverPhotoUrl!.split('?').first;
                CachedNetworkImage.evictFromCache(coverUrl);
              }
            } catch (e) {
              print('Error clearing image cache: $e');
            }
          }
        } catch (e) {
          print('Supabase profile fetch failed, trying local: $e');
        }
      }

      // Fallback to local database if offline or Supabase failed
      if (profile == null) {
        profile = await db.getUserProfile(targetUserId ?? '');
        if (profile != null) {
          setState(() => _isOffline = true);
          print('📱 Loaded profile from local database (offline mode)');
        }
      }

      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Load badges - try Supabase first, fallback to local
      List<Map<String, dynamic>> badges = [];
      if (isConnected) {
        try {
          badges = await supabaseService.getUserBadges(targetUserId ?? '');
        } catch (e) {
          print('Supabase badges fetch failed, trying local: $e');
        }
      }

      // Fallback to local badges if offline
      if (badges.isEmpty) {
        try {
          final localBadges = await db.getUserBadges(targetUserId ?? '');
          // Convert UserBadge to Map format expected by BadgeGridWidget
          // Fetch badge details from local database
          final badgeMaps = <Map<String, dynamic>>[];
          for (final userBadge in localBadges) {
            final badge = await db.getBadgeById(userBadge.badgeId.toString());
            if (badge != null) {
              badgeMaps.add({
                'badgeId': userBadge.badgeId,
                'awardedAt': userBadge.awardedAt,
                'badge': {
                  'id': badge.id,
                  'name': badge.name,
                  'description': badge.description ?? 'Badge earned',
                  'iconUrl': badge.iconUrl,
                  'xpReward': badge.xpReward,
                },
              });
            } else {
              // Fallback if badge details not found locally
              badgeMaps.add({
                'badgeId': userBadge.badgeId,
                'awardedAt': userBadge.awardedAt,
                'badge': {
                  'id': userBadge.badgeId,
                  'name': 'Badge #${userBadge.badgeId}',
                  'description': 'Badge details unavailable offline',
                  'iconUrl': null,
                  'xpReward': 0,
                },
              });
            }
          }
          badges = badgeMaps;
        } catch (e) {
          print('Local badges fetch failed: $e');
        }
      }

      // Load department name - try Supabase first, fallback to local cache
      String? departmentName;
      if (profile.departmentId != null) {
        if (isConnected) {
          try {
            departmentName = await supabaseService.getDepartmentNameById(profile.departmentId!);
          } catch (e) {
            print('Supabase department fetch failed, trying local: $e');
          }
        }
        // Fallback to local cache
        if (departmentName == null) {
          departmentName = await db.getDepartmentName(profile.departmentId!);
        }
      }

      // Load friendship status if viewing other user's profile (only when online)
      String? friendshipStatus;
      if (!_isOwnProfile && currentUserId != null && isConnected) {
        try {
          friendshipStatus = await supabaseService.getFriendshipStatus(targetUserId ?? '');
        } catch (e) {
          print('Friendship status fetch failed: $e');
        }
      }

      // Load friends count for the profile owner
      int friendsCount = 0;
      if (isConnected && targetUserId != null) {
        try {
          friendsCount = await supabaseService.getFriendsCountForUser(targetUserId);
        } catch (e) {
          print('Friends count fetch failed: $e');
        }
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _badges = badges;
          _friendshipStatus = friendshipStatus;
          _friendsCount = friendsCount;
          _departmentName = departmentName;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _handleFriendAction() async {
    if (_profile == null || _friendshipStatus == null) return;

    try {
      bool success = false;
      String message = '';
      bool needsReload = false; // Track if friends count changed

      switch (_friendshipStatus) {
        case 'none':
          success = await SupabaseService().sendFriendRequest(_profile!.id);
          message = success ? 'Friend request sent' : 'Failed to send friend request';
          if (success) _friendshipStatus = 'pending_out';
          // No reload needed - only button state changes
          break;
        case 'pending_in':
          // Get the friendship ID to accept
          final incoming = await SupabaseService().getIncomingPendingRequests();
          final friendship = incoming.firstWhere(
            (f) => (f['counterpart'] as UserProfile?)?.id == _profile!.id,
            orElse: () => {},
          );
          if (friendship['id'] != null) {
            success = await SupabaseService().acceptFriendRequest(friendship['id'] as int);
            message = success ? 'Friend request accepted' : 'Failed to accept request';
            if (success) {
              _friendshipStatus = 'friends';
              needsReload = true; // Friends count increased
            }
          }
          break;
        case 'pending_out':
          // Cancel request
          final outgoing = await SupabaseService().getOutgoingPendingRequests();
          final friendship = outgoing.firstWhere(
            (f) => (f['counterpart'] as UserProfile?)?.id == _profile!.id,
            orElse: () => {},
          );
          if (friendship['id'] != null) {
            success = await SupabaseService().cancelMyPendingRequest(friendship['id'] as int);
            message = success ? 'Friend request cancelled' : 'Failed to cancel request';
            if (success) _friendshipStatus = 'none';
            // No reload needed - only button state changes
          }
          break;
        case 'friends':
          // Unfriend
          success = await SupabaseService().unfriend(_profile!.id);
          if (success) {
            message = 'Unfriended ${_profile!.fullName}';
            _friendshipStatus = 'none';
            needsReload = true; // Friends count decreased
          } else {
            message = 'Failed to unfriend. Check console logs for details. If this persists, ensure RLS policies are set up (see supabase_migrations/friendships_rls_policies.sql)';
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        // Update UI immediately - use optimized update for all actions
        if (success) {
          // Update friendship status for all actions, friends count only when it changes
          // This ensures consistency and prevents full page reloads
          await _updateFriendshipData(updateFriendsCount: needsReload);
        } else {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildFriendButton() {
    if (_isOwnProfile) {
      return FilledButton.icon(
        onPressed: _isOffline ? null : () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditProfileScreen(),
            ),
          );
                if (result == true) {
                  // Increment refresh keys to force image refresh
                  setState(() {
                    _avatarRefreshKey++;
                    _coverPhotoRefreshKey++;
                  });
                  // Wait a bit for Supabase to propagate changes
                  await Future.delayed(const Duration(milliseconds: 500));
                  // Force reload profile and clear image cache
                  await _loadProfile();
                  // Force rebuild to refresh images
                  if (mounted) {
                    setState(() {
                      _avatarRefreshKey++; // Increment again after reload
                      _coverPhotoRefreshKey++; // Increment again after reload
                    });
                  }
                }
        },
        icon: const Icon(Icons.edit),
        label: const Text('Edit Profile'),
      );
    }

    if (_friendshipStatus == null || _isOffline) {
      if (_isOffline) {
        return Text(
          'Friend features unavailable offline',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
          textAlign: TextAlign.center,
        );
      }
      return const SizedBox.shrink();
    }

    String buttonText;
    IconData icon;

    switch (_friendshipStatus) {
      case 'none':
        buttonText = 'Add Friend';
        icon = Icons.person_add;
        break;
      case 'pending_out':
        buttonText = 'Request Sent';
        icon = Icons.pending;
        break;
      case 'pending_in':
        buttonText = 'Accept Request';
        icon = Icons.check;
        break;
      case 'friends':
        buttonText = 'Unfriend';
        icon = Icons.person_remove;
        break;
      default:
        buttonText = 'Add Friend';
        icon = Icons.person_add;
    }

    // Use different button style for unfriend (outlined) vs other actions (filled)
    if (_friendshipStatus == 'friends') {
      return OutlinedButton.icon(
        onPressed: _handleFriendAction,
        icon: Icon(icon),
        label: Text(buttonText),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _handleFriendAction,
      icon: Icon(icon),
      label: Text(buttonText),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Profile not found')),
      );
    }

    final level = _profile!.level;
    final departmentName = _departmentName ?? (_profile!.departmentId != null
        ? 'Department ${_profile!.departmentId}'
        : 'No Department');

    return AppScaffold(
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'My Profile' : _profile!.fullName),
        actions: [
          if (_isOffline)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.cloud_off,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Clear image cache before reloading
          try {
            if (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty) {
              final avatarUrl = _profile!.avatarUrl!.split('?').first;
              CachedNetworkImage.evictFromCache(avatarUrl);
            }
            if (_profile?.coverPhotoUrl != null && _profile!.coverPhotoUrl!.isNotEmpty) {
              final coverUrl = _profile!.coverPhotoUrl!.split('?').first;
              CachedNetworkImage.evictFromCache(coverUrl);
            }
          } catch (e) {
            print('Error clearing cache on refresh: $e');
          }
          // Increment refresh keys to force image refresh
          setState(() {
            _avatarRefreshKey++;
            _coverPhotoRefreshKey++;
          });
          // Reload profile data
          await _loadProfile();
          // Force rebuild to refresh images
          if (mounted) {
            setState(() {
              _avatarRefreshKey++;
              _coverPhotoRefreshKey++;
            });
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even when content fits
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Cover Photo Section
            _buildCoverPhoto(),
            
            // Profile Header
            _buildProfileHeader(departmentName, level),
            
            const SizedBox(height: 24),
            
            // Offline indicator
            if (_isOffline)
              Padding(
                padding: ResponsiveUtils.getScreenPadding(context),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing offline data. Some features may be limited.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Action Button
            Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: _buildFriendButton(),
            ),
            
            const SizedBox(height: 24),
            
            // XP Progress Bar
            Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: _buildXPProgressCard(),
            ),
            
            const SizedBox(height: 24),
            
            // Stats Row
            Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: _buildStatsRow(level),
            ),
            
            const SizedBox(height: 24),
            
            // Bio Section
            if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
              Padding(
                padding: ResponsiveUtils.getScreenPadding(context),
                child: _buildBioSection(),
              ),
            
            const SizedBox(height: 24),
            
            // Badges Section
            Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: _buildBadgesSection(),
            ),
            
            const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPhoto() {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: _profile!.coverPhotoUrl != null && _profile!.coverPhotoUrl!.isNotEmpty
              ? Builder(
                  builder: (context) {
                    // Force refresh mechanism similar to avatar
                    if (_coverPhotoRefreshKey > 0) {
                      final baseUrl = _profile!.coverPhotoUrl!.split('?').first;
                      // Clear cache BEFORE loading new image
                      CachedNetworkImage.evictFromCache(baseUrl);
                      // Use NetworkImage directly when forcing refresh to bypass cache
                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                      return Image.network(
                        '$baseUrl?t=$timestamp',
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: Center(
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                        ),
                      );
                    }
                    // Use CachedNetworkImage for offline support and performance
                    // Add timestamp to force network check when online, but use base URL as cache key
                    final baseUrl = _profile!.coverPhotoUrl!.split('?').first;
                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    return CachedNetworkImage(
                      imageUrl: '$baseUrl?t=$timestamp',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: Center(
                          child: Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                      ),
                      // Cache images to disk for offline access
                      // Use base URL as cache key so cache is shared (timestamp doesn't affect caching)
                      cacheKey: baseUrl,
                      maxWidthDiskCache: 2400, // Cache at 2x resolution (1200 * 2) for better quality
                      maxHeightDiskCache: 800, // Cache at 2x resolution (400 * 2) for better quality
                      key: ValueKey('cover_${_profile!.id}_$_coverPhotoRefreshKey'), // Force widget rebuild with unique key
                    );
                  },
                )
              : Center(
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
        ),
        if (_isOwnProfile)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileScreen(),
                  ),
                );
                if (result == true) {
                  // Clear image cache IMMEDIATELY before reloading
                  try {
                    if (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty) {
                      final avatarUrl = _profile!.avatarUrl!.split('?').first;
                      CachedNetworkImage.evictFromCache(avatarUrl);
                    }
                    if (_profile?.coverPhotoUrl != null && _profile!.coverPhotoUrl!.isNotEmpty) {
                      final coverUrl = _profile!.coverPhotoUrl!.split('?').first;
                      CachedNetworkImage.evictFromCache(coverUrl);
                    }
                  } catch (e) {
                    print('Error clearing cache: $e');
                  }
                  // Increment refresh keys to force image refresh
                  setState(() {
                    _avatarRefreshKey++;
                    _coverPhotoRefreshKey++;
                  });
                  // Wait a bit for Supabase to propagate changes
                  await Future.delayed(const Duration(milliseconds: 500));
                  // Force reload profile
                  await _loadProfile();
                  // Force rebuild to refresh images
                  if (mounted) {
                    setState(() {
                      _avatarRefreshKey++; // Increment again after reload
                      _coverPhotoRefreshKey++; // Increment again after reload
                    });
                  }
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileHeader(String departmentName, int level) {
    return Padding(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (overlapped on cover)
          Transform.translate(
            offset: const Offset(0, -60),
            child: AvatarWidget.large(
              avatarUrl: _profile!.avatarUrl,
              fullName: _profile!.fullName,
              forceRefresh: _avatarRefreshKey > 0, // Force refresh after edit
              key: ValueKey('avatar_${_profile!.id}_$_avatarRefreshKey'), // Force widget rebuild with unique key
            ),
          ),
          const SizedBox(width: 16),
          // Name and info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_profile!.userTag != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '@${_profile!.userTag}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _profile!.userTag!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied @${_profile!.userTag} to clipboard'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.copy,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        departmentName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Level $level',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPProgressCard() {
    if (_profile == null) return const SizedBox.shrink();
    
    final currentLevel = _profile!.level;
    final currentProgress = _profile!.progressToNextLevel.clamp(0.0, 1.0);
    final levelProgress = _profile!.currentLevelProgress;
    final xpInCurrentLevel = levelProgress['currentLevelXP'] ?? 0;
    final xpNeededForNextLevel = levelProgress['requiredForNextLevel'] ?? 100;
    final xpRemaining = levelProgress['remaining'] ?? 100;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'XP Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Level $currentLevel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '$xpRemaining XP to Level ${currentLevel + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: currentProgress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int level) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.star,
          label: 'XP',
          value: '${_profile!.xp}',
        ),
        _buildStatItem(
          icon: Icons.emoji_events,
          label: 'Level',
          value: '$level',
        ),
        _buildStatItem(
          icon: Icons.people,
          label: 'Friends',
          value: '$_friendsCount',
        ),
        _buildStatItem(
          icon: Icons.workspace_premium,
          label: 'Badges',
          value: '${_badges.length}',
        ),
      ],
    );
  }

  Widget _buildStatItem({required IconData icon, required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_isOwnProfile) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        // Clear image cache IMMEDIATELY before reloading
                        try {
                          if (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty) {
                            final avatarUrl = _profile!.avatarUrl!.split('?').first;
                            CachedNetworkImage.evictFromCache(avatarUrl);
                          }
                          if (_profile?.coverPhotoUrl != null && _profile!.coverPhotoUrl!.isNotEmpty) {
                            final coverUrl = _profile!.coverPhotoUrl!.split('?').first;
                            CachedNetworkImage.evictFromCache(coverUrl);
                          }
                        } catch (e) {
                          print('Error clearing cache: $e');
                        }
                        // Increment refresh keys to force image refresh
                        setState(() {
                          _avatarRefreshKey++;
                          _coverPhotoRefreshKey++;
                        });
                        // Wait a bit for Supabase to propagate changes
                        await Future.delayed(const Duration(milliseconds: 500));
                        // Force reload profile
                        await _loadProfile();
                        // Force rebuild to refresh images
                        if (mounted) {
                          setState(() {
                            _avatarRefreshKey++; // Increment again after reload
                            _coverPhotoRefreshKey++; // Increment again after reload
                          });
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _profile!.bio!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Badges',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        BadgeGridWidget(badges: _badges),
      ],
    );
  }
}

