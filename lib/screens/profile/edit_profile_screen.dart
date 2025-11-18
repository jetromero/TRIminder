import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/supabase_storage_service.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
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

      if (mounted) {
        setState(() {
          _profile = profile;
          _bioController.text = profile.bio ?? '';
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

    setState(() => _isSaving = true);

    try {
      final userId = SupabaseService().currentUserId!;
      String? avatarUrl;
      String? coverPhotoUrl;

      // Upload avatar if changed
      if (_avatarFile != null) {
        try {
          avatarUrl = await SupabaseStorageService().uploadAvatar(_avatarFile!, userId);
          if (avatarUrl == null) {
            throw Exception('Failed to upload avatar');
          }
        } catch (e) {
          // If bucket doesn't exist, allow saving profile without avatar
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Avatar upload failed: Storage buckets not set up. Profile will be saved without avatar.'),
                duration: const Duration(seconds: 5),
              ),
            );
            avatarUrl = _profile!.avatarUrl; // Keep existing or null
          } else {
            rethrow;
          }
        }
      } else {
        avatarUrl = _profile!.avatarUrl;
      }

      // Upload cover photo if changed
      if (_coverPhotoFile != null) {
        try {
          coverPhotoUrl = await SupabaseStorageService().uploadCoverPhoto(_coverPhotoFile!, userId);
          if (coverPhotoUrl == null) {
            throw Exception('Failed to upload cover photo');
          }
        } catch (e) {
          // If bucket doesn't exist, allow saving profile without cover photo
          final errorMsg = e.toString().toLowerCase();
          if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cover photo upload failed: Storage buckets not set up. Profile will be saved without cover photo.'),
                duration: const Duration(seconds: 5),
              ),
            );
            coverPhotoUrl = _profile!.coverPhotoUrl; // Keep existing or null
          } else {
            rethrow;
          }
        }
      } else {
        coverPhotoUrl = _profile!.coverPhotoUrl;
      }

      // Update profile
      final updatedProfile = await SupabaseService().updateUserProfileFields(
        avatarUrl: avatarUrl,
        coverPhotoUrl: coverPhotoUrl,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      );

      if (updatedProfile == null) {
        throw Exception('Failed to update profile - no response from server');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
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
            Text(
              'Profile Picture',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
            Text(
              'Cover Photo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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

