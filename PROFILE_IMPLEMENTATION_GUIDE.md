# Sign-Up & Profile Management Implementation Guide

## Overview
This implementation provides a complete sign-up flow with user profile management, including personal information (First Name, Last Name, Profile Picture) and car details (Model, Plate Number, Color).

## Architecture

### 1. Data Models (`lib/models/user_profile.dart`)

#### `CarDetails` Class
Represents vehicle information:
- `model`: Car model (e.g., "Toyota", "Honda")
- `plateNumber`: Vehicle registration plate
- `color`: Vehicle color

#### `UserProfile` Class
Represents complete user information:
- `userId`: Unique Firebase Auth ID
- `email`: User's email address
- `firstName`: User's first name
- `lastName`: User's last name
- `profilePictureUrl`: URL to profile picture in Firebase Storage
- `carDetails`: Nested CarDetails object
- `createdAt`: Profile creation timestamp
- `updatedAt`: Last update timestamp

### 2. Firebase Service (`lib/services/user_service.dart`)

The `UserService` class handles all Firebase operations:

#### Profile Operations
- `createUserProfile()` - Create initial user profile after registration
- `getUserProfile()` - Retrieve user profile from Firestore
- `userProfileStream()` - Real-time profile updates stream
- `updateUserProfile()` - Update entire profile
- `userProfileExists()` - Check if profile exists

#### Image Operations
- `uploadProfilePicture()` - Upload image to Firebase Storage
- `updateProfilePictureUrl()` - Store URL in Firestore
- `deleteProfilePicture()` - Clean up image from Storage

#### Data Updates
- `updateUserNames()` - Update first/last names
- `updateCarDetails()` - Update all car details
- `updateCarDetailField()` - Update specific car field

#### Account Management
- `deleteUserProfile()` - Delete all user data

### 3. UI Screens

#### Complete Profile Screen (`lib/screens/complete_profile_screen.dart`)
Post-authentication screen for collecting:
- Profile picture (optional)
- First name and last name (required)
- Car details:
  - Model (dropdown with 15+ options)
  - Plate number (text input)
  - Color (dropdown with 14 color options)

## Firebase Firestore Structure

```
users/ (collection)
├── {userId}/ (document)
│   ├── userId: string
│   ├── email: string
│   ├── firstName: string
│   ├── lastName: string
│   ├── profilePictureUrl: string (optional)
│   ├── carDetails: object
│   │   ├── model: string
│   │   ├── plateNumber: string
│   │   └── color: string
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
```

## Firebase Storage Structure

```
storage
└── profile_pictures/
    └── {userId}/
        └── {timestamp}.jpg
```

## Integration Steps

### Step 1: Update Main App Routes
Add the new screen to your route configuration in `main.dart`:

```dart
routes: {
  'signup': (context) => const SignUpScreen(),
  'complete-profile': (context) {
    // Get arguments from previous screen
    final args = ModalRoute.of(context)?.settings.arguments 
        as Map<String, dynamic>;
    return CompleteProfileScreen(
      email: args['email'],
      userId: args['userId'],
    );
  },
  'home': (context) => const HomePage(),
  // ... other routes
},
```

### Step 2: Update Signup Flow
After email verification in your existing `signup_screen.dart`, navigate to the complete profile screen:

```dart
// In verify_code_screen.dart or after authentication
if (userCreated) {
  Navigator.pushNamed(
    context,
    'complete-profile',
    arguments: {
      'email': userEmail,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    },
  );
}
```

### Step 3: Set Firestore Security Rules
Add these rules to your Firebase Console:

```json
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
  }
}
```

### Step 4: Set Firebase Storage Security Rules

```json
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{userId}/{allPaths=**} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId && 
                      request.resource.size < 5 * 1024 * 1024;
    }
  }
}
```

## Usage Examples

### Example 1: Create User Profile After Authentication
```dart
final userService = UserService();

// After successful Firebase Auth registration
await userService.createUserProfile(
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
);
```

### Example 2: Retrieve User Profile
```dart
final userService = UserService();

// Get profile once
final profile = await userService.getUserProfile();
print('User: ${profile?.getFullName()}');
print('Car: ${profile?.carDetails.model}');

// Listen to real-time updates
userService.userProfileStream().listen((profile) {
  if (profile != null) {
    print('Profile updated: ${profile.updatedAt}');
  }
});
```

### Example 3: Update Car Details
```dart
final userService = UserService();

// Update all car details
await userService.updateCarDetails(
  CarDetails(
    model: 'Toyota',
    plateNumber: 'ABC123',
    color: 'Black',
  ),
);

// Or update specific field
await userService.updateCarDetailField(
  field: 'model',
  value: 'Honda',
);
```

### Example 4: Upload Profile Picture
```dart
final userService = UserService();
final File imageFile = File('/path/to/image.jpg');

// Upload and get URL
final downloadUrl = await userService.uploadProfilePicture(imageFile);

// URL is automatically saved to Firestore
await userService.updateProfilePictureUrl(downloadUrl);
```

### Example 5: Display User Profile with Real-time Updates
```dart
class UserProfileWidget extends StatelessWidget {
  final UserService userService = UserService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: userService.userProfileStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Text('Profile not found');
        }

        return Column(
          children: [
            if (profile.profilePictureUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(profile.profilePictureUrl!),
                radius: 50,
              ),
            Text(profile.getFullName()),
            Text('${profile.carDetails.model} - ${profile.carDetails.color}'),
            Text('Plate: ${profile.carDetails.plateNumber}'),
          ],
        );
      },
    );
  }
}
```

## Security Considerations

1. **Authentication Check**: All UserService methods verify that `currentUser` is authenticated
2. **Firestore Rules**: Users can only read/write their own profile data
3. **Storage Rules**: Users can only upload and access their own profile pictures
4. **File Size Limit**: 5MB max for profile pictures
5. **User ID Linkage**: All data is linked to authenticated user's UID

## Error Handling

The UserService provides comprehensive error logging via `debugPrint`:

```dart
try {
  final profile = await userService.getUserProfile();
} catch (e) {
  // Error is logged automatically
  // Handle error in UI
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Data Privacy

- Each user can only access their own profile data
- Profile pictures are stored with user-specific paths
- All Firestore documents are user-scoped
- No cross-user data sharing possible with current security rules

## Future Enhancements

1. **Profile Picture Editing**: Allow users to update/replace profile picture
2. **Car Details Validation**: Validate plate number format by country
3. **Multiple Cars**: Support multiple vehicles per user
4. **Profile Completion Status**: Track which fields are filled
5. **Image Compression**: Automatically compress images before upload
6. **Offline Support**: Cache profiles locally with Firestore offline persistence
7. **Social Integration**: Link profile with user's display name in Auth
