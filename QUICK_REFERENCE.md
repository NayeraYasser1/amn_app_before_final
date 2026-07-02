# Quick Reference: Common User Profile Operations

## Initialization
```dart
// Create instance of UserService
final userService = UserService();

// Or with dependency injection (optional)
final userService = UserService(
  auth: FirebaseAuth.instance,
  firestore: FirebaseFirestore.instance,
  storage: FirebaseStorage.instance,
);
```

## Read Operations

### Get current user's profile
```dart
final profile = await userService.getUserProfile();
if (profile != null) {
  print('Name: ${profile.getFullName()}');
  print('Car: ${profile.carDetails.model}');
}
```

### Get specific user's profile
```dart
final profile = await userService.getUserProfile(userId: 'someUserId');
```

### Listen to real-time profile updates
```dart
userService.userProfileStream().listen((profile) {
  if (profile != null) {
    print('Profile updated at ${profile.updatedAt}');
  }
});
```

### Stream builder for UI
```dart
StreamBuilder<UserProfile?>(
  stream: userService.userProfileStream(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    final profile = snapshot.data;
    return profile != null
        ? Text('Hello, ${profile.getFullName()}!')
        : const Text('No profile found');
  },
)
```

### Check if profile exists
```dart
final exists = await userService.userProfileExists();
// or specific user
final exists = await userService.userProfileExists(userId: 'userId');
```

## Create/Write Operations

### Create profile after registration
```dart
await userService.createUserProfile(
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
);
```

### Upload profile picture and update Firestore
```dart
final imageFile = File('/path/to/image.jpg');

// Upload to storage and get URL
final downloadUrl = await userService.uploadProfilePicture(imageFile);

// Update Firestore with URL
await userService.updateProfilePictureUrl(downloadUrl);
```

### Update names
```dart
await userService.updateUserNames(
  firstName: 'Jane',
  lastName: 'Smith',
);
```

### Update car details (all at once)
```dart
final carDetails = CarDetails(
  model: 'Toyota',
  plateNumber: 'ABC123XYZ',
  color: 'Black',
);

await userService.updateCarDetails(carDetails);
```

### Update specific car field
```dart
await userService.updateCarDetailField(
  field: 'model',
  value: 'Honda',
);

// Or
await userService.updateCarDetailField(
  field: 'plateNumber',
  value: 'XYZ789',
);

await userService.updateCarDetailField(
  field: 'color',
  value: 'Silver',
);
```

### Update entire profile
```dart
final updatedProfile = UserProfile(
  userId: 'userId',
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
  profilePictureUrl: 'https://...',
  carDetails: CarDetails(
    model: 'BMW',
    plateNumber: 'BMW123',
    color: 'White',
  ),
);

await userService.updateUserProfile(updatedProfile);
```

## Delete Operations

### Delete profile picture
```dart
// If you have the URL:
await userService.deleteProfilePicture('https://storage.googleapis.com/...');

// Or automatically from current profile:
final profile = await userService.getUserProfile();
if (profile?.profilePictureUrl != null) {
  await userService.deleteProfilePicture(profile!.profilePictureUrl!);
  
  // Remove URL from profile
  await userService.updateProfilePictureUrl('');
}
```

### Delete entire user profile
```dart
await userService.deleteUserProfile();
```

## Model Operations

### Create CarDetails from scratch
```dart
final car = CarDetails(
  model: 'Mercedes-Benz',
  plateNumber: 'MB456',
  color: 'Gray',
);
```

### Create empty CarDetails
```dart
final emptyCar = CarDetails.empty();
```

### Update CarDetails with copyWith
```dart
final car = CarDetails(
  model: 'Toyota',
  plateNumber: 'ABC123',
  color: 'Black',
);

final updatedCar = car.copyWith(
  color: 'Red', // Only change color
);
```

### Get full name from UserProfile
```dart
final profile = await userService.getUserProfile();
final fullName = profile?.getFullName() ?? 'Unknown';
```

### Convert to/from Map (for manual Firestore operations)
```dart
// UserProfile to Map
final profileMap = profile.toMap();

// Map to UserProfile
final profile = UserProfile.fromMap(mapData, 'userId');

// CarDetails to Map
final carMap = carDetails.toMap();

// Map to CarDetails
final car = CarDetails.fromMap(mapData);
```

## Error Handling

### Try-catch pattern
```dart
try {
  final profile = await userService.getUserProfile();
} on FirebaseException catch (e) {
  print('Firebase error: ${e.code} - ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

### With UI feedback
```dart
try {
  await userService.updateCarDetails(carDetails);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Car details updated!')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Display Examples

### Display profile picture
```dart
final profile = await userService.getUserProfile();

if (profile?.profilePictureUrl != null) {
  Image.network(
    profile!.profilePictureUrl!,
    width: 100,
    height: 100,
    fit: BoxFit.cover,
  );
} else {
  // Placeholder
  const Icon(Icons.account_circle, size: 100);
}
```

### Display car information
```dart
final profile = await userService.getUserProfile();
final car = profile?.carDetails;

Text('${car?.color} ${car?.model}'),
Text('Plate: ${car?.plateNumber}'),
```

### Build profile card
```dart
class ProfileCard extends StatelessWidget {
  final UserProfile profile;

  const ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (profile.profilePictureUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(profile.profilePictureUrl!),
                radius: 50,
              ),
            const SizedBox(height: 16),
            Text(
              profile.getFullName(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(profile.email ?? ''),
            const SizedBox(height: 16),
            Text('${profile.carDetails.color} ${profile.carDetails.model}'),
            Text('Plate: ${profile.carDetails.plateNumber}'),
          ],
        ),
      ),
    );
  }
}
```

## Batch Operations

### Perform multiple updates
```dart
Future<void> updateUserCompletely({
  required String firstName,
  required String lastName,
  required File profilePicture,
  required CarDetails carDetails,
}) async {
  try {
    // Step 1: Upload picture
    final pictureUrl = await userService.uploadProfilePicture(profilePicture);
    
    // Step 2: Update profile with all data
    final profile = UserProfile(
      userId: userService.currentUser!.uid,
      email: userService.currentUser!.email,
      firstName: firstName,
      lastName: lastName,
      profilePictureUrl: pictureUrl,
      carDetails: carDetails,
    );
    
    // Step 3: Save to Firestore (single write)
    await userService.updateUserProfile(profile);
  } catch (e) {
    rethrow;
  }
}
```

## Validation Examples

### Validate profile completeness
```dart
bool isProfileComplete(UserProfile? profile) {
  if (profile == null) return false;
  
  return profile.firstName != null &&
      profile.firstName!.isNotEmpty &&
      profile.lastName != null &&
      profile.lastName!.isNotEmpty &&
      profile.carDetails.model != null &&
      profile.carDetails.model!.isNotEmpty &&
      profile.carDetails.plateNumber != null &&
      profile.carDetails.plateNumber!.isNotEmpty &&
      profile.carDetails.color != null &&
      profile.carDetails.color!.isNotEmpty;
}
```

### Validate car details
```dart
String? validateCarDetails(CarDetails car) {
  if (car.model == null || car.model!.isEmpty) {
    return 'Car model is required';
  }
  if (car.plateNumber == null || car.plateNumber!.isEmpty) {
    return 'Plate number is required';
  }
  if (car.color == null || car.color!.isEmpty) {
    return 'Car color is required';
  }
  return null;
}
```

## Permissions & Authentication

### Check if user can modify profile
```dart
bool canModifyProfile(String userId) {
  return userService.currentUser?.uid == userId;
}

// Usage
if (canModifyProfile(profileUserId)) {
  // Show edit button
}
```

### Get current user info
```dart
final currentUser = userService.currentUser;
if (currentUser != null) {
  print('UID: ${currentUser.uid}');
  print('Email: ${currentUser.email}');
  print('Email verified: ${currentUser.emailVerified}');
}
```
