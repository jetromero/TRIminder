import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;

class SupabaseStorageService {
  static final SupabaseStorageService _instance = SupabaseStorageService._internal();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._internal();

  SupabaseClient get _client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
  }

  // Storage bucket names
  static const String _avatarBucket = 'avatars';
  static const String _coverPhotoBucket = 'cover-photos';

  // Image constraints
  static const int _maxFileSizeBytes = 2 * 1024 * 1024; // 2MB
  static const int _avatarSize = 400; // 400x400
  static const int _coverPhotoWidth = 1200;
  static const int _coverPhotoHeight = 400;

  /// Upload avatar image with compression and resizing
  Future<String?> uploadAvatar(File imageFile, String userId) async {
    try {
      // Read and process image
      final processedBytes = await _processImage(
        imageFile,
        maxWidth: _avatarSize,
        maxHeight: _avatarSize,
        quality: 85,
      );

      if (processedBytes == null) {
        throw Exception('Failed to process image');
      }

      // Check file size
      if (processedBytes.length > _maxFileSizeBytes) {
        throw Exception('Image file too large after compression');
      }

      // Upload to Supabase Storage
      final fileName = '$userId.jpg';
      final path = fileName;

      try {
        await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          processedBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
          throw Exception(
            'Storage bucket "$_avatarBucket" not found. Please create it in Supabase Storage. '
            'See STORAGE_SETUP.md for instructions.'
          );
        }
        rethrow;
      }

      // Get public URL
      final url = _client.storage.from(_avatarBucket).getPublicUrl(path);
      return url;
    } catch (e) {
      print('Error uploading avatar: $e');
      rethrow;
    }
  }

  /// Upload cover photo image with compression and resizing
  Future<String?> uploadCoverPhoto(File imageFile, String userId) async {
    try {
      // Read and process image
      final processedBytes = await _processImage(
        imageFile,
        maxWidth: _coverPhotoWidth,
        maxHeight: _coverPhotoHeight,
        quality: 85,
      );

      if (processedBytes == null) {
        throw Exception('Failed to process image');
      }

      // Check file size
      if (processedBytes.length > _maxFileSizeBytes) {
        throw Exception('Image file too large after compression');
      }

      // Upload to Supabase Storage
      final fileName = '$userId.jpg';
      final path = fileName;

      try {
        await _client.storage.from(_coverPhotoBucket).uploadBinary(
          path,
          processedBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('bucket') || errorMsg.contains('not found')) {
          throw Exception(
            'Storage bucket "$_coverPhotoBucket" not found. Please create it in Supabase Storage. '
            'See STORAGE_SETUP.md for instructions.'
          );
        }
        rethrow;
      }

      // Get public URL
      final url = _client.storage.from(_coverPhotoBucket).getPublicUrl(path);
      return url;
    } catch (e) {
      print('Error uploading cover photo: $e');
      rethrow;
    }
  }

  /// Delete avatar image
  Future<bool> deleteAvatar(String userId) async {
    try {
      final fileName = '$userId.jpg';
      await _client.storage.from(_avatarBucket).remove([fileName]);
      return true;
    } catch (e) {
      print('Error deleting avatar: $e');
      return false;
    }
  }

  /// Delete cover photo image
  Future<bool> deleteCoverPhoto(String userId) async {
    try {
      final fileName = '$userId.jpg';
      await _client.storage.from(_coverPhotoBucket).remove([fileName]);
      return true;
    } catch (e) {
      print('Error deleting cover photo: $e');
      return false;
    }
  }

  /// Process image: resize and compress
  Future<Uint8List?> _processImage(
    File imageFile, {
    required int maxWidth,
    required int maxHeight,
    required int quality,
  }) async {
    try {
      // Read image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        print('Failed to decode image');
        return null;
      }

      // Resize if needed
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        resizedImage = img.copyResize(
          image,
          width: maxWidth,
          height: maxHeight,
          maintainAspect: true,
        );
      }

      // Encode as JPEG with quality
      final jpegBytes = img.encodeJpg(resizedImage, quality: quality);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  /// Get avatar URL (public)
  String? getAvatarUrl(String userId) {
    try {
      final fileName = '$userId.jpg';
      return _client.storage.from(_avatarBucket).getPublicUrl(fileName);
    } catch (e) {
      print('Error getting avatar URL: $e');
      return null;
    }
  }

  /// Get cover photo URL (public)
  String? getCoverPhotoUrl(String userId) {
    try {
      final fileName = '$userId.jpg';
      return _client.storage.from(_coverPhotoBucket).getPublicUrl(fileName);
    } catch (e) {
      print('Error getting cover photo URL: $e');
      return null;
    }
  }
}

