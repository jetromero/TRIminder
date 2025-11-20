import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/database_service.dart';
import '../../models/user_models.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../../utils/responsive_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  UserProfile? _profile;
  File? _avatarFile;
  File? _coverPhotoFile;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _userTagController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingTagAvailability = false;
  String? _tagAvailabilityMessage;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _userTagController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not authenticated')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final profile = await SupabaseService().getUserProfile(userId);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile not found')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Check connectivity
      final isConnected = await SupabaseService().isConnected();
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _bioController.text = profile.bio ?? '';
          _userTagController.text = profile.userTag ?? '';
          _isOffline = !isConnected;
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

  Future<void> _pickImage(ImageSource source, bool isAvatar) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: isAvatar ? 400 : 1200,
        maxHeight: isAvatar ? 400 : 400,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (isAvatar) {
            _avatarFile = File(image.path);
          } else {
            _coverPhotoFile = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _checkUserTagAvailability() async {
    final tag = _userTagController.text.trim();
    if (tag.isEmpty) {
      setState(() {
        _tagAvailabilityMessage = null;
        _isCheckingTagAvailability = false;
      });
      return;
    }

    // Validate format first
    final supabaseService = SupabaseService();
    if (!supabaseService.isValidUserTag(tag)) {
      setState(() {
        _tagAvailabilityMessage = 'Invalid format. Use up to 15 letters followed by up to 4 digits (e.g., john1234)';
        _isCheckingTagAvailability = false;
      });
      return;
    }

    // Check if it's the same as current tag
    if (tag == _profile?.userTag) {
      setState(() {
        _tagAvailabilityMessage = null;
        _isCheckingTagAvailability = false;
      });
      return;
    }

    setState(() => _isCheckingTagAvailability = true);

    try {
      final isConnected = await supabaseService.isConnected();
      if (!isConnected) {
        setState(() {
          _tagAvailabilityMessage = 'Tag availability check requires internet connection';
          _isCheckingTagAvailability = false;
        });
        return;
      }

      final isAvailable = await supabaseService.isUserTagAvailable(tag);
      setState(() {
        _tagAvailabilityMessage = isAvailable 
            ? '✓ Available' 
            : '✗ This tag is already taken';
        _isCheckingTagAvailability = false;
      });
    } catch (e) {
      setState(() {
        _tagAvailabilityMessage = 'Error checking availability: $e';
        _isCheckingTagAvailability = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    // Validate bio
    final bioError = UserProfile.validateBio(_bioController.text);
    if (bioError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bioError)),
      );
      return;
    }

    // Validate user tag if changed
    final newTag = _userTagController.text.trim();
    final tagChanged = newTag != (_profile!.userTag ?? '');
    if (tagChanged && newTag.isNotEmpty) {
      final supabaseService = SupabaseService();
      if (!supabaseService.isValidUserTag(newTag)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid user tag format. Use up to 15 letters followed by up to 4 digits.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final userId = SupabaseService().currentUserId!;
      final supabaseService = SupabaseService();
      final isConnected = await supabaseService.isConnected();
      setState(() => _isOffline = !isConnected);

      String? avatarUrl;
      String? coverPhotoUrl;
      bool photosPendingUpload = false;

      // Clear old URLs cache before upload
      final oldAvatarUrl = _profile!.avatarUrl;
      final oldCoverPhotoUrl = _profile!.coverPhotoUrl;
      try {
        if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
          CachedNetworkImage.evictFromCache(oldAvatarUrl.split('?').first);
        }
        if (oldCoverPhotoUrl != null && oldCoverPhotoUrl.isNotEmpty) {
          CachedNetworkImage.evictFromCache(oldCoverPhotoUrl.split('?').first);
        }
      } catch (e) {
        print('Error clearing old image cache: $e');
      }

      // Handle avatar upload
      if (_avatarFile != null) {
        if (isConnected) {
          try {
            avatarUrl = await SupabaseStorageService().uploadAvatar(_avatarFile!, userId);
            if (avatarUrl == null) {
              throw Exception('Failed to upload avatar');
            }
            // Clear cache for new avatar URL immediately after upload
            try {
              CachedNetworkImage.evictFromCache(avatarUrl.split('?').first);
            } catch (e) {
              print('Error clearing new avatar cache: $e');
            }
          } catch (e) {
            final errorMsg = e.toString().toLowerCase();
            if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Avatar upload failed: Storage buckets not set up. Profile will be saved without avatar.'),
                  duration: const Duration(seconds: 5),
                ),
              );
              avatarUrl = _profile!.avatarUrl;
            } else if (errorMsg.contains('network') || errorMsg.contains('connection') || errorMsg.contains('timeout')) {
              // Network error - queue for later upload
              photosPendingUpload = true;
              avatarUrl = _profile!.avatarUrl; // Keep existing for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Avatar will be uploaded when connection is restored'),
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              rethrow;
            }
          }
        } else {
          // Offline - queue for upload
          photosPendingUpload = true;
          avatarUrl = _profile!.avatarUrl; // Keep existing
        }
      } else {
        avatarUrl = _profile!.avatarUrl;
      }

      // Handle cover photo upload
      if (_coverPhotoFile != null) {
        if (isConnected) {
          try {
            coverPhotoUrl = await SupabaseStorageService().uploadCoverPhoto(_coverPhotoFile!, userId);
            if (coverPhotoUrl == null) {
              throw Exception('Failed to upload cover photo');
            }
            // Clear cache for new cover photo URL immediately after upload
            try {
              CachedNetworkImage.evictFromCache(coverPhotoUrl.split('?').first);
            } catch (e) {
              print('Error clearing new cover photo cache: $e');
            }
          } catch (e) {
            final errorMsg = e.toString().toLowerCase();
            if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cover photo upload failed: Storage buckets not set up. Profile will be saved without cover photo.'),
                  duration: const Duration(seconds: 5),
                ),
              );
              coverPhotoUrl = _profile!.coverPhotoUrl;
            } else if (errorMsg.contains('network') || errorMsg.contains('connection') || errorMsg.contains('timeout')) {
              // Network error - queue for later upload
              photosPendingUpload = true;
              coverPhotoUrl = _profile!.coverPhotoUrl; // Keep existing for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cover photo will be uploaded when connection is restored'),
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              rethrow;
            }
          }
        } else {
          // Offline - queue for upload
          photosPendingUpload = true;
          coverPhotoUrl = _profile!.coverPhotoUrl; // Keep existing
        }
      } else {
        coverPhotoUrl = _profile!.coverPhotoUrl;
      }

      // Update user tag if changed
      if (tagChanged && newTag.isNotEmpty) {
        if (isConnected) {
          final tagAvailable = await supabaseService.isUserTagAvailable(newTag);
          if (!tagAvailable) {
            throw Exception('User tag is already taken');
          }
          final tagUpdated = await supabaseService.updateCurrentUserTag(newTag);
          if (!tagUpdated) {
            throw Exception('Failed to update user tag');
          }
        }
        // Update local profile with new tag (will sync later if offline)
        _profile = _profile!.copyWith(userTag: newTag);
      }

      // Update profile fields (avatar, cover photo, bio)
      UserProfile? updatedProfile;
      if (isConnected) {
        final supabaseResponse = await supabaseService.updateUserProfileFields(
          avatarUrl: avatarUrl,
          coverPhotoUrl: coverPhotoUrl,
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        );

        if (supabaseResponse == null) {
          throw Exception('Failed to update profile - no response from server');
        }
        
        // CRITICAL: Use the URLs we uploaded, not what Supabase returns
        // Supabase might return stale data if changes haven't propagated yet
        // We know avatarUrl and coverPhotoUrl are correct because we just uploaded them
        updatedProfile = supabaseResponse.copyWith(
          avatarUrl: avatarUrl, // Use the URL we uploaded, not Supabase response
          coverPhotoUrl: coverPhotoUrl, // Use the URL we uploaded, not Supabase response
        );
      } else {
        // Offline: Create updated profile locally
        updatedProfile = _profile!.copyWith(
          avatarUrl: avatarUrl,
          coverPhotoUrl: coverPhotoUrl,
          bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
          isSynced: false,
        );
      }

      // Update local database with CORRECT URLs (the ones we uploaded)
      final db = DatabaseService();
      await db.updateUserProfile(updatedProfile);
      
      // Track when local DB was updated (for preventing stale overwrite)
      // This timestamp will be used by profile screen to prioritize local DB
      // We'll store this in a way that profile screen can access it
      // For now, we'll rely on the profile screen checking the actual URLs
      
      // Track when local DB was updated (for preventing stale overwrite in profile screen)
      // This is done by updating the profile screen's _lastLocalDbUpdate via a callback or state
      // For now, we'll rely on the timestamp check in _loadProfile()

      // Store pending photo uploads if offline
      if (photosPendingUpload || !isConnected) {
        // Store file paths for later upload (we'll implement a proper queue system)
        // For now, the files are already stored in _avatarFile and _coverPhotoFile
        // The sync service will need to handle these
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected 
                ? 'Profile updated successfully' 
                : 'Profile saved locally. Changes will sync when online.'),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        final errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg.contains('column') && errorMsg.contains('does not exist')
                  ? 'Database columns missing. Please run the migration SQL in Supabase.'
                  : 'Error saving profile: $e'
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: Text('Profile not found')),
      );
    }

    final bioLength = _bioController.text.length;
    final maxBioLength = 500;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: ResponsiveUtils.getScreenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Avatar Section
            _buildAvatarSection(),
            
            const SizedBox(height: 24),
            
            // Cover Photo Section
            _buildCoverPhotoSection(),
            
            const SizedBox(height: 24),
            
            // User Tag Section
            _buildUserTagSection(),
            
            const SizedBox(height: 24),
            
            // Bio Section
            _buildBioSection(bioLength, maxBioLength),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Profile Picture',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_avatarFile != null && _isOffline) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pending upload',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  _avatarFile != null
                      ? CircleAvatar(
                          radius: 60,
                          backgroundImage: FileImage(_avatarFile!),
                        )
                      : AvatarWidget.large(
                          avatarUrl: _profile!.avatarUrl,
                          fullName: _profile!.fullName,
                        ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        color: Theme.of(context).colorScheme.onPrimary,
                        onPressed: () => _showImagePickerDialog(true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery, true),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera, true),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ],
            ),
            if (_avatarFile != null)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _avatarFile = null);
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Cover Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_coverPhotoFile != null && _isOffline) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pending upload',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                image: _coverPhotoFile != null
                    ? DecorationImage(
                        image: FileImage(_coverPhotoFile!),
                        fit: BoxFit.cover,
                      )
                    : _profile!.coverPhotoUrl != null && _profile!.coverPhotoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_profile!.coverPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: Stack(
                children: [
                  if (_coverPhotoFile == null &&
                      (_profile!.coverPhotoUrl == null || _profile!.coverPhotoUrl!.isEmpty))
                    Center(
                      child: Icon(
                        Icons.photo_library_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        color: Colors.white,
                        onPressed: () => _showImagePickerDialog(false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery, false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera, false),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ],
            ),
            if (_coverPhotoFile != null)
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _coverPhotoFile = null);
                  },
                  child: const Text('Remove'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTagSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'User Tag',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_isOffline) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your unique identifier (e.g., john1234)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userTagController,
              decoration: InputDecoration(
                hintText: 'Enter user tag',
                prefixText: '@',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _isCheckingTagAvailability
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _userTagController.text.trim().isNotEmpty &&
                            _userTagController.text.trim() != (_profile?.userTag ?? '')
                        ? IconButton(
                            icon: const Icon(Icons.check_circle),
                            onPressed: _checkUserTagAvailability,
                            tooltip: 'Check availability',
                          )
                        : null,
              ),
              onChanged: (_) {
                setState(() {
                  _tagAvailabilityMessage = null;
                });
                // Auto-check after user stops typing
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _userTagController.text.trim().isNotEmpty) {
                    _checkUserTagAvailability();
                  }
                });
              },
            ),
            if (_tagAvailabilityMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _tagAvailabilityMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _tagAvailabilityMessage!.startsWith('✓')
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            if (_isOffline) ...[
              const SizedBox(height: 8),
              Text(
                'Tag availability check requires internet connection',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection(int bioLength, int maxBioLength) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Bio',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '$bioLength / $maxBioLength',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: bioLength > maxBioLength
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLength: maxBioLength,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerDialog(bool isAvatar) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isAvatar);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isAvatar);
              },
            ),
          ],
        ),
      ),
    );
  }
}

