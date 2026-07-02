# Cloudinary Integration Guide

## Setup Instructions

### 1. Cloudinary Account Setup

You already have:
- **Cloud Name**: `dtzibvsvj`

### 2. Create Unsigned Upload Presets

You need to create TWO unsigned upload presets in your Cloudinary dashboard:

#### Preset 1: Profile Images (amn_profile_upload)
1. Go to [Cloudinary Dashboard](https://cloudinary.com/console)
2. Navigate to **Settings → Upload**
3. Click **Add upload preset**
4. Configure:
   - **Name**: `amn_profile_upload`
   - **Unsigned**: Toggle ON
   - **Folder**: `amn-app/profiles`
   - **Resource type**: Image
   - **Allowed formats**: jpg, jpeg, png, webp, gif
   - **Max file size**: 5 MB (5242880 bytes)
   - **Transformation** (Optional but recommended):
     - **Width**: 800
     - **Height**: 800
     - **Crop**: fill
     - **Quality**: auto

#### Preset 2: License Images (amn_license_upload)
1. Click **Add upload preset** again
2. Configure:
   - **Name**: `amn_license_upload`
   - **Unsigned**: Toggle ON
   - **Folder**: `amn-app/licenses`
   - **Resource type**: Image
   - **Allowed formats**: jpg, jpeg, png, webp
   - **Max file size**: 8 MB (8388608 bytes)
   - **Transformation** (Optional):
     - **Width**: 1200
     - **Height**: 800
     - **Crop**: fill

### 3. Update Android Manifest (if not already set)

Add internet permission to `android/app/src/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### 4. Flutter Dependencies

Already added to `pubspec.yaml`:
- `http: ^1.1.0` - For Cloudinary API calls
- `cached_network_image: ^3.3.1` - For efficient image caching

Run:
```bash
flutter pub get
```

## Code Structure

### Files Created/Modified

1. **`lib/services/cloudinary_service.dart`**
   - Handles all Cloudinary upload operations
   - Supports profile and license image uploads
   - Error handling and network timeout management

2. **`lib/widgets/image_upload_widget.dart`**
   - Reusable UI component for image selection and upload
   - Shows image preview
   - Loading indicator during upload
   - Error message display

3. **`lib/widgets/cloudinary_image_widget.dart`**
   - Display Cloudinary images with caching
   - Placeholder and error states
   - Responsive sizing

4. **`lib/screens/verify_code_screen.dart`** (Updated)
   - Integrated Cloudinary uploads during sign-up
   - Automatic URL storage in Firestore
   - Complete error handling

## Usage Examples

### Upload Profile Image

```dart
import 'package:amn_app/services/cloudinary_service.dart';

// Upload
final imageFile = File(imagePath);
final url = await CloudinaryService.uploadProfileImage(imageFile);
print('Uploaded to: $url');

// Save to Firestore
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'profileImage': url});
```

### Upload License Image

```dart
final licenseFile = File(licensePath);
final url = await CloudinaryService.uploadLicenseImage(licenseFile);

// Save to Firestore
await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'licenseImage': url});
```

### Upload Multiple Images

```dart
final results = await CloudinaryService.uploadMultipleImages(
  profileImage: File(profilePath),
  driverLicense: File(driverLicensePath),
  carLicense: File(carLicensePath),
);

// results is a Map<String, String?>
// {
//   'profileImage': 'https://res.cloudinary.com/...',
//   'driverLicense': 'https://res.cloudinary.com/...',
//   'carLicense': 'https://res.cloudinary.com/...',
// }
```

### Display Cloudinary Image

```dart
import 'package:amn_app/widgets/cloudinary_image_widget.dart';

CloudinaryImageWidget(
  imageUrl: userProfile.profileImage,
  label: 'Profile Picture',
  width: 200,
  height: 200,
  fit: BoxFit.cover,
)
```

### Using Image Upload Widget in UI

```dart
import 'package:amn_app/widgets/image_upload_widget.dart';

ImageUploadWidget(
  label: 'Upload Profile Picture',
  selectedImage: _selectedImage,
  onPickImage: _pickImage,
  onRemoveImage: () => setState(() => _selectedImage = null),
  isLoading: _isUploading,
  errorMessage: _errorMessage,
)
```

## Firestore Data Structure

After sign-up with Cloudinary, your Firestore document looks like:

```json
{
  "userId": "user123",
  "firstName": "Ahmed",
  "lastName": "Ali",
  "email": "ahmed@example.com",
  "phone": "+201234567890",
  "phone_verified": true,
  
  // Cloudinary URLs
  "profileImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969000/amn-app/profiles/profile_1713969000.jpg",
  "licenseImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969001/amn-app/licenses/license_1713969001.jpg",
  "carLicenseImage": "https://res.cloudinary.com/dtzibvsvj/image/upload/v1713969002/amn-app/licenses/license_1713969002.jpg",
  
  // Car details
  "carDetails": {
    "model": "Toyota",
    "plateNumber": "ABC-123",
    "color": "Black"
  },
  
  // Legacy fields for compatibility
  "profilePictureUrl": "https://res.cloudinary.com/...",
  "driver_license_url": "https://res.cloudinary.com/...",
  "car_license_url": "https://res.cloudinary.com/...",
  
  "createdAt": "2026-04-24T10:30:00Z",
  "updatedAt": "2026-04-24T10:30:00Z"
}
```

## Sign-Up Flow with Cloudinary

```
1. User fills sign-up form
   ├─ Personal info (name, email, password)
   ├─ Phone number
   ├─ Car details
   └─ Image uploads (profile, licenses)

2. User verifies phone with OTP
   └─ Firebase Auth creates account

3. Images uploaded to Cloudinary
   ├─ Profile image → returns secure_url
   ├─ Driver license → returns secure_url
   └─ Car license → returns secure_url

4. URLs stored in Firestore
   └─ users/{userId} document created with all data

5. User redirected to home
   └─ Can view profile with Cloudinary images
```

## Error Handling

### Common Errors & Solutions

**Network Error:**
```
Error: "Network error. Please check your connection."
→ Check internet connection, retry upload
```

**Upload Timeout:**
```
Error: "Upload timed out. Please try again."
→ File size too large or slow connection
→ Check file size < 5MB for profiles, 8MB for licenses
```

**Invalid Preset:**
```
Error: "Cloudinary error: Invalid upload preset"
→ Create unsigned upload presets (amn_profile_upload, amn_license_upload)
→ Verify preset names match CloudinaryService.dart
```

**No URL Returned:**
```
Error: "No URL returned from Cloudinary"
→ Upload succeeded but URL missing
→ Check Cloudinary dashboard settings
```

## Image Preview & Display

### In Edit Profile Screen

```dart
// Load and display Cloudinary images
await _loadUserData() {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();
  
  final data = userDoc.data()!;
  _profileImageUrl = data['profileImage']; // Cloudinary URL
  _driverLicenseUrl = data['licenseImage'];
  _carLicenseUrl = data['carLicenseImage'];
}

// Display images
CloudinaryImageWidget(
  imageUrl: _profileImageUrl,
  label: 'Profile',
)
```

## Caching & Performance

### Image Caching

`CloudinaryImageWidget` automatically caches images using `cached_network_image`:
- Caches images locally on device
- Reduces network requests
- Improves app performance
- Auto-refreshes on URL change

### Optimization Tips

1. **Image Sizes**: Cloudinary presets automatically resize images
   - Profile: 800x800px
   - Licenses: 1200x800px

2. **Formats**: Use modern formats (WebP when possible)
   - JPEG for photos
   - PNG for transparent images
   - WebP for better compression

3. **CDN**: Cloudinary serves images from nearest CDN edge
   - Fast delivery worldwide
   - Automatic optimization
   - Responsive images

## Security Considerations

### Unsigned Upload Security

Using unsigned uploads:
- ✅ No need to expose API keys in app
- ✅ Cloudinary controls upload settings via presets
- ✅ File size and format restrictions enforced
- ✅ Folder organization prevents conflicts

### Firestore Security Rules

Ensure Firestore rules protect user data:
```
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
```

This ensures:
- Only authenticated users can access their data
- Users cannot modify other users' documents
- All images are linked to authenticated user

## Testing

### Test Sign-Up with Images

1. Open app and go to Sign-Up
2. Fill all fields including images
3. Submit form and verify phone with OTP
4. Check Firestore console
   - Navigate to `users/{userId}`
   - Verify all Cloudinary URLs are stored
5. Check Cloudinary dashboard
   - Go to Media Library
   - Verify images in `amn-app/profiles` and `amn-app/licenses`
6. Verify image display
   - Open Edit Profile or home
   - Confirm images load correctly

## Troubleshooting

### Images Not Uploading

**Check list**:
1. ✅ Internet connection available
2. ✅ Upload presets created in Cloudinary
3. ✅ Preset names match exactly (case-sensitive)
4. ✅ Cloud name is correct: `dtzibvsvj`
5. ✅ Presets set to "Unsigned"
6. ✅ Image file size within limits

### Images Not Displaying

**Check list**:
1. ✅ URLs stored correctly in Firestore
2. ✅ URLs are valid HTTPS (start with `https://`)
3. ✅ Internet connection available
4. ✅ Image not deleted from Cloudinary
5. ✅ Firestore security rules allow read access

### Slow Upload

**Solutions**:
1. Check file size - compress if > 5MB
2. Check internet speed
3. Use faster network (WiFi vs mobile data)
4. Retry upload

## Next Steps

1. ✅ Create unsigned upload presets in Cloudinary
2. ✅ Run `flutter pub get`
3. ✅ Test sign-up with images
4. ✅ Verify images in Firestore & Cloudinary
5. ✅ Test image display in app
6. ✅ Deploy to production

---

**Cloudinary Cloud Name**: dtzibvsvj
**Upload Presets**: amn_profile_upload, amn_license_upload
**Status**: ✅ Ready to use
