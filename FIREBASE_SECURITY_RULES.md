# Firebase Security Rules & Configuration

## Firestore Security Rules

These rules ensure that each user can only access and modify their own profile data.

### Rules Configuration
```json
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - each user can only access their own profile
    match /users/{userId} {
      // Allow read if the user is authenticated and accessing their own profile
      allow read: if request.auth.uid == userId;
      
      // Allow write if the user is authenticated and modifying their own profile
      allow write: if request.auth.uid == userId;
    }
    
    // Optional: Add other collections here as needed
    match /drivers/{driverId} {
      allow read, write: if request.auth.uid == driverId;
    }
    
    // Deny access to anything else by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Advanced Rules (with validation)
```json
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isUserAuthenticated() {
      return request.auth.uid != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function hasRequiredFields() {
      let requiredFields = ['email', 'firstName', 'lastName', 'carDetails'];
      return request.resource.data.keys().hasAll(requiredFields);
    }
    
    function isValidCarDetails(carDetails) {
      return carDetails.keys().hasAll(['model', 'plateNumber', 'color']) &&
             carDetails.model is string &&
             carDetails.plateNumber is string &&
             carDetails.color is string &&
             carDetails.model.size() > 0 &&
             carDetails.plateNumber.size() > 2 &&
             carDetails.color.size() > 0;
    }
    
    // Users collection with validation
    match /users/{userId} {
      // Read: Only the user can read their profile
      allow read: if isUserAuthenticated() && isOwner(userId);
      
      // Create: User can create their profile, must have all required fields
      allow create: if isUserAuthenticated() && 
                       isOwner(userId) &&
                       hasRequiredFields() &&
                       isValidCarDetails(request.resource.data.carDetails) &&
                       request.resource.data.userId == userId;
      
      // Update: User can update their profile
      allow update: if isUserAuthenticated() && 
                       isOwner(userId) &&
                       isValidCarDetails(request.resource.data.carDetails);
      
      // Delete: User can delete their profile
      allow delete: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Deny everything else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Firebase Storage Security Rules

These rules allow users to upload and access only their own profile pictures.

### Basic Rules Configuration
```json
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures - each user can only manage their own
    match /profile_pictures/{userId}/{allPaths=**} {
      // Allow read access to user's own files
      allow read: if request.auth.uid == userId;
      
      // Allow write access to user's own files
      // Limit file size to 5MB
      // Only allow images
      allow write: if request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/.*');
      
      // Allow delete access to user's own files
      allow delete: if request.auth.uid == userId;
    }
    
    // Deny access to anything else by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### Advanced Rules (with detailed validation)
```json
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Helper functions
    function isUserAuthenticated() {
      return request.auth.uid != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isImageFile() {
      return request.resource.contentType.matches('image/(jpeg|png|webp|gif)');
    }
    
    function isValidImageSize() {
      return request.resource.size > 0 &&
             request.resource.size < 5 * 1024 * 1024; // 5MB max
    }
    
    function isValidMetadata() {
      return request.resource.metadata.get('userId') == request.auth.uid;
    }
    
    // Profile pictures storage with validation
    match /profile_pictures/{userId}/{allPaths=**} {
      // Allow authenticated users to read their own profile pictures
      allow read: if isUserAuthenticated() && isOwner(userId);
      
      // Allow authenticated users to upload to their directory
      // With strict validation
      allow write: if isUserAuthenticated() && 
                      isOwner(userId) &&
                      isImageFile() &&
                      isValidImageSize();
      
      // Allow deletion of own files
      allow delete: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Deployment Instructions

### Via Firebase Console

1. **Firestore Rules**:
   - Open [Firebase Console](https://console.firebase.google.com)
   - Select your project
   - Go to Firestore Database → Rules
   - Replace with rules above
   - Click "Publish"

2. **Storage Rules**:
   - Go to Storage → Rules
   - Replace with rules above
   - Click "Publish"

### Via Firebase CLI

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Select your project
firebase use --add

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Deploy all rules
firebase deploy --only firestore:rules,storage
```

### Create Rules Files

Create these files in your project root:

**firestore.rules**
```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

**storage.rules**
```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{userId}/{allPaths=**} {
      allow read: if request.auth.uid == userId;
      
      allow write: if request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/.*');
      
      allow delete: if request.auth.uid == userId;
    }
    
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**firebase.json**
```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "storage": [
    {
      "target": "default",
      "rules": "storage.rules"
    }
  ]
}
```

Then deploy with:
```bash
firebase deploy
```

## Testing Rules Locally

Use Firebase Emulator Suite:

```bash
# Install Firebase emulators
firebase setup:emulators:firestore
firebase setup:emulators:storage

# Start emulator
firebase emulators:start

# In your Flutter app, configure to use local emulator during testing
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
```

## Security Best Practices

### 1. Enable Firestore Backups
- Go to Firestore Database → Backups
- Create a backup schedule
- Recommended: Daily backups with 7-day retention

### 2. Enable Audit Logs
- Go to Logging/Activity (in admin console)
- Enable Cloud Audit Logs for Firestore and Storage

### 3. Data Validation
Always validate on both client and server side:

**Client Side** (Dart/Flutter):
```dart
String? validateCarDetails(CarDetails car) {
  if (car.model == null || car.model!.isEmpty) {
    return 'Car model required';
  }
  // ... more validation
  return null;
}
```

**Server Side** (Firestore Rules):
```json
isValidCarDetails(carDetails) {
  return carDetails.keys().hasAll(['model', 'plateNumber', 'color']) &&
         carDetails.model.size() > 0 &&
         carDetails.plateNumber.size() > 0 &&
         carDetails.color.size() > 0;
}
```

### 4. Image Security
- Validate file type (image only)
- Limit file size (5MB)
- Validate in both client and storage rules
- Consider running image processing functions

### 5. User Privacy
- Each user can only access their own data
- Profile pictures are user-scoped
- No cross-user queries possible
- Consider encrypting sensitive fields

### 6. Rate Limiting (Optional)
For production apps, consider adding rate limiting:

```json
// Additional rules to prevent abuse
allow write: if request.time < resource.data.lastWriteTime + duration.value(5, 's')
             && ... other conditions
```

### 7. Regular Security Audits
- Review security rules monthly
- Check access logs for suspicious activity
- Update rules based on app changes

## Monitoring & Debugging

### View Firestore Usage
- Firebase Console → Firestore Database → Usage
- Check read/write count and storage usage
- Set up billing alerts

### Monitor Storage Usage
- Firebase Console → Storage → Files
- Check upload/download bandwidth
- Monitor quota usage

### Enable Debug Logging (Development Only)
```dart
// In main.dart during development
if (kDebugMode) {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
}
```

## Troubleshooting

### Issue: "Permission denied" errors
**Solution**: 
- Verify user is authenticated: `FirebaseAuth.instance.currentUser != null`
- Check rules match your collection structure
- Ensure userId in path matches authenticated user's UID

### Issue: "Document not found" despite creating
**Solution**:
- Check Firestore rules allow create operation
- Verify data structure matches Firestore schema
- Check console for write errors

### Issue: Image upload fails
**Solution**:
- Verify file is valid image (JPEG, PNG, WebP, GIF)
- Check file size < 5MB
- Ensure Storage rules allow write operation
- Check Storage is enabled in Firebase Console

### Issue: Rules won't deploy
**Solution**:
- Check for syntax errors in rules JSON
- Verify firebase-tools is up to date
- Check you have permissions to modify rules
