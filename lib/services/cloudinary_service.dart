import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudinary image upload service (free tier: 25GB storage, 25GB bandwidth)
///
/// Setup:
/// 1. Sign up at https://cloudinary.com (free)
/// 2. Go to Settings → Upload → Add upload preset → set to "Unsigned"
/// 3. Copy your Cloud Name and Upload Preset name
/// 4. Update the values below
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // ─── CLOUDINARY CREDENTIALS ───
  static const String cloudName = 'drhjmo1uv';
  static const String uploadPreset = 'medicine_app';  // Create this in Cloudinary Settings → Upload → Upload presets (Unsigned)

  static const String _uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Check if Cloudinary is configured
  bool get isConfigured =>
      cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  /// Upload an image file and return the secure URL
  ///
  /// [file] - The image file to upload
  /// [folder] - Optional folder path in Cloudinary (e.g. 'chat_images', 'profile')
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImage(File file, {String? folder}) async {
    if (!isConfigured) {
      throw Exception(
        'Cloudinary is not configured. Update cloud_name and upload_preset in '
        'lib/services/cloudinary_service.dart',
      );
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      debugPrint('[Cloudinary] Uploading image to folder: $folder');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String;
        debugPrint('[Cloudinary] Upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('[Cloudinary] Upload failed: $responseBody');
        throw Exception('Upload failed (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      debugPrint('[Cloudinary] Error: $e');
      rethrow;
    }
  }

  /// Upload image bytes (for when you have bytes instead of a File)
  Future<String> uploadBytes(List<int> bytes, String filename, {String? folder}) async {
    if (!isConfigured) {
      throw Exception(
        'Cloudinary is not configured. Update cloud_name and upload_preset in '
        'lib/services/cloudinary_service.dart',
      );
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return json['secure_url'] as String;
      } else {
        throw Exception('Upload failed (${response.statusCode}): $responseBody');
      }
    } catch (e) {
      debugPrint('[Cloudinary] Error: $e');
      rethrow;
    }
  }
}
