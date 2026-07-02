import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dtzibvsvj';

  // Unsigned upload presets (you need to create these in Cloudinary dashboard)
  static const String _profileUploadPreset = 'amn_profile_upload';
  static const String _licenseUploadPreset = 'amn_license_upload';

  /// Upload image to Cloudinary and return secure URL
  /// imageType: 'profile' or 'license'
  static Future<String?> uploadImage({
    required File imageFile,
    required String imageType,
  }) async {
    try {
      // Determine upload preset based on image type
      final uploadPreset = imageType == 'profile'
          ? _profileUploadPreset
          : _licenseUploadPreset;

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Add upload preset (unsigned upload)
      request.fields['upload_preset'] = uploadPreset;

      // Add folder structure for organization
      request.fields['folder'] = 'amn-app/${imageType}s';

      // Add public ID based on timestamp for uniqueness
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      request.fields['public_id'] = '${imageType}_$timestamp';

      debugPrint('Uploading image to Cloudinary: $imageType');

      // Send request
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
            'Upload timeout. Please check your internet connection.',
          );
        },
      );

      debugPrint('Cloudinary response status: ${response.statusCode}');

      // Parse response
      final responseBody = await response.stream.bytesToString();
      final decodedResponse = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Successfully uploaded
        final secureUrl = decodedResponse['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('No URL returned from Cloudinary');
        }
      } else {
        // Error from Cloudinary
        final errorMessage =
            decodedResponse['error']?['message'] ??
            'Upload failed with status ${response.statusCode}';
        throw Exception('Cloudinary error: $errorMessage');
      }
    } on SocketException catch (e) {
      debugPrint('Network error during upload: $e');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      throw Exception('Upload failed: $e');
    }
  }

  /// Upload profile image
  static Future<String?> uploadProfileImage(File imageFile) async {
    return uploadImage(imageFile: imageFile, imageType: 'profile');
  }

  /// Upload license image (driver or car)
  static Future<String?> uploadLicenseImage(File imageFile) async {
    return uploadImage(imageFile: imageFile, imageType: 'license');
  }

  /// Upload multiple images and return URLs map
  static Future<Map<String, String?>> uploadMultipleImages({
    required File? profileImage,
    required File? driverLicense,
    required File? carLicense,
  }) async {
    final results = <String, String?>{};

    try {
      // Upload profile image
      if (profileImage != null) {
        try {
          results['profileImage'] = await uploadProfileImage(profileImage);
        } catch (e) {
          debugPrint('Profile image upload failed: $e');
          results['profileImage'] = null;
        }
      }

      // Upload driver license
      if (driverLicense != null) {
        try {
          results['driverLicense'] = await uploadLicenseImage(driverLicense);
        } catch (e) {
          debugPrint('Driver license upload failed: $e');
          results['driverLicense'] = null;
        }
      }

      // Upload car license
      if (carLicense != null) {
        try {
          results['carLicense'] = await uploadLicenseImage(carLicense);
        } catch (e) {
          debugPrint('Car license upload failed: $e');
          results['carLicense'] = null;
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error in uploadMultipleImages: $e');
      rethrow;
    }
  }
}
