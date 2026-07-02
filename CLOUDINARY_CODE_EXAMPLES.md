/**
 * CLOUDINARY INTEGRATION - COMPLETE CODE EXAMPLES
 * 
 * This file demonstrates all the code used for Cloudinary image uploads
 * and Firestore integration in the AMN App.
 */

// ============================================================================
// FILE 1: lib/services/cloudinary_service.dart
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dtzibvsvj';
  static const String _profileUploadPreset = 'amn_profile_upload';
  static const String _licenseUploadPreset = 'amn_license_upload';

  /// Upload image to Cloudinary
  static Future<String?> uploadImage({
    required File imageFile,
    required String imageType,
  }) async {
    try {
      final uploadPreset = imageType == 'profile' 
          ? _profileUploadPreset 
          : _licenseUploadPreset;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'amn-app/${imageType}s';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      request.fields['public_id'] = '${imageType}_$timestamp';

      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Upload timeout'),
      );

      final responseBody = await response.stream.bytesToString();
      final decodedResponse = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return decodedResponse['secure_url'] as String?;
      } else {
        throw Exception('Upload failed: ${decodedResponse['error']?['message']}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      rethrow;
    }
  }

  static Future<String?> uploadProfileImage(File imageFile) =>
      uploadImage(imageFile: imageFile, imageType: 'profile');

  static Future<String?> uploadLicenseImage(File imageFile) =>
      uploadImage(imageFile: imageFile, imageType: 'license');
}

// ============================================================================
// FILE 2: lib/screens/verify_code_screen.dart (RELEVANT SECTIONS)
// ============================================================================

// In VerifyCodeScreen._verify() method after phone verification:

if (widget.args.flow == VerifyFlow.signup) {
  // 1. Upload images to Cloudinary
  String? driverUrl;
  String? carUrl;
  String? profilePictureUrl;

  // Upload driver license
  try {
    driverUrl = await CloudinaryService.uploadLicenseImage(
      File(widget.args.driverLicenseFile!.path),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Driver license upload failed: $e')),
    );
    return;
  }

  // Upload car license
  try {
    carUrl = await CloudinaryService.uploadLicenseImage(
      File(widget.args.carLicenseFile!.path),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Car license upload failed: $e')),
    );
    return;
  }

  // Upload profile picture (optional)
  if (widget.args.profilePicture != null) {
    try {
      profilePictureUrl = await CloudinaryService.uploadProfileImage(
        File(widget.args.profilePicture!.path),
      );
    } catch (e) {
      debugPrint('Profile picture upload failed: $e');
      // Continue even if profile fails
    }
  }

  // 2. Save all data to Firestore with Cloudinary URLs
  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'userId': user.uid,
    'firstName': widget.args.firstName,
    'lastName': widget.args.lastName,
    'email': email.trim(),
    'phone': widget.args.phone,
    'phone_verified': true,
    'profileImage': profilePictureUrl, // Cloudinary URL
    'licenseImage': driverUrl, // Cloudinary URL
    'carLicenseImage': carUrl, // Cloudinary URL
    'carDetails': {
      'model': widget.args.selectedCarModel,
      'plateNumber': widget.args.plateNumber,
      'color': widget.args.selectedCarColor,
    },
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Navigator.pushNamedAndRemoveUntil(context, 'home', (route) => false);
}

// ============================================================================
// FILE 3: lib/widgets/image_upload_widget.dart
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';

class ImageUploadWidget extends StatelessWidget {
  final String label;
  final File? selectedImage;
  final VoidCallback onPickImage;
  final VoidCallback? onRemoveImage;
  final bool isLoading;
  final String? errorMessage;

  const ImageUploadWidget({
    required this.label,
    this.selectedImage,
    required this.onPickImage,
    this.onRemoveImage,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[700]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Image preview
              if (selectedImage != null)
                Image.file(selectedImage!, height: 150, fit: BoxFit.cover)
              else
                Container(
                  height: 150,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.image, size: 48, color: Colors.grey),
                  ),
                ),
              // Buttons
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onPickImage,
                  icon: const Icon(Icons.upload),
                  label: const Text('Pick Image'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FILE 4: lib/widgets/cloudinary_image_widget.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CloudinaryImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final double width;
  final double height;

  const CloudinaryImageWidget({
    required this.imageUrl,
    required this.label,
    this.width = double.infinity,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[800],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text('No $label'),
            ],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey[800],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[800],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      ),
    );
  }
}

// ============================================================================
// USAGE EXAMPLES IN YOUR SCREENS
// ============================================================================

// Example 1: Upload during sign-up (in verify_code_screen.dart)
Future<void> uploadAndSaveToFirestore() async {
  try {
    // Upload to Cloudinary
    final profileUrl = await CloudinaryService.uploadProfileImage(
      File(profileImagePath),
    );
    
    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'profileImage': profileUrl});
        
  } catch (e) {
    print('Upload failed: $e');
  }
}

// Example 2: Display in Edit Profile Screen
void loadAndDisplayProfileImage() async {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  final profileImageUrl = userDoc['profileImage']; // Cloudinary URL
  
  // Display using CloudinaryImageWidget
  // CloudinaryImageWidget(
  //   imageUrl: profileImageUrl,
  //   label: 'Profile Picture',
  // )
}

// Example 3: Multiple image uploads
Future<Map<String, String?>> uploadAllImages() async {
  final results = await CloudinaryService.uploadMultipleImages(
    profileImage: File(profilePath),
    driverLicense: File(driverLicensePath),
    carLicense: File(carLicensePath),
  );
  return results;
}

// ============================================================================
// FIRESTORE DATA STRUCTURE
// ============================================================================

/**
After sign-up with Cloudinary, your Firestore document structure:

{
  "userId": "firebase_uid_123",
  "firstName": "Ahmed",
  "lastName": "Ali",
  "email": "ahmed@example.com",
  "phone": "+201234567890",
  "phone_verified": true,
  
  // Cloudinary image URLs
  "profileImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969000/amn-app/profiles/profile_1713969000.jpg",
  "licenseImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969001/amn-app/licenses/license_1713969001.jpg",
  "carLicenseImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969002/amn-app/licenses/license_1713969002.jpg",
  
  // Car details
  "carDetails": {
    "model": "Toyota",
    "plateNumber": "ABC-123",
    "color": "Black"
  },
  
  "createdAt": timestamp,
  "updatedAt": timestamp
}
*/

// ============================================================================
// SETUP CHECKLIST
// ============================================================================

/**
Before deploying:

1. ✅ Create unsigned upload preset 'amn_profile_upload' in Cloudinary
2. ✅ Create unsigned upload preset 'amn_license_upload' in Cloudinary
3. ✅ Run: flutter pub get (to install http and cached_network_image)
4. ✅ Test sign-up with image uploads
5. ✅ Verify images appear in Cloudinary Media Library
6. ✅ Verify URLs stored in Firestore
7. ✅ Test image display in app (CloudinaryImageWidget)
8. ✅ Verify cached_network_image caching works

Cloudinary Cloud Name: dtzibvsvj
Profile Upload Preset: amn_profile_upload
License Upload Preset: amn_license_upload
*/
