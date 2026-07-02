# AMN App Sign-Up System - Quick Reference Guide

## Updated Sign-Up Flow (2026-04-24)

```
User Registration
    ↓
[SignUpScreen] - User enters details + license documents
    ↓ (validates form, phone format, password strength)
[VerifyCodeScreen] - Phone OTP verification (6 digits)
    ↓ (user receives SMS with code)
Firebase Auth User Created (phone + email linked)
    ↓
User data saved to Firestore users/{uid}
    ↓
Verification email sent to user
    ↓
[EmailVerificationScreen] - User clicks email link to verify
    ↓ (auto-detects verification every 3 seconds)
email_verified = true in Firestore
    ↓
[HomePage] - User gains full app access
```

## Key Features Implemented

### 1. Email Verification ✅
- **What**: Email must be verified before user can access app
- **When**: After phone OTP verification, user is redirected to verify email
- **How**: User clicks verification link in email, screen auto-detects
- **Timeout**: 10 minutes (then user must re-login)

### 2. Phone OTP Verification ✅
- **What**: 6-digit code sent via SMS for phone verification
- **When**: During sign-up process
- **How**: Firebase SMS gateway delivers OTP, user enters in app
- **Resend**: Available after 60-second countdown

### 3. User Data Storage ✅
**Stored in Firestore:**
```
users/{userId}/
├── Basic Info: firstName, lastName, email, phone
├── Verification: email_verified, phone_verified, email_verified_at
├── Profile: profilePictureUrl, carDetails
├── Licenses: driver_license_url, car_license_url
└── Metadata: createdAt, updatedAt
```

**Stored in Firebase Storage:**
```
profile_pictures/{userId}/...      [User's profile image]
driver_license/{userId}/...        [Driver license photo]
car_license/{userId}/...           [Car registration photo]
```

### 4. Data Security ✅
- Each user can ONLY access their own data
- Firestore rules: `allow read/write if request.auth.uid == userId`
- Storage rules: Path-based access control by userId
- AuthGuard prevents access unless email verified

### 5. Edit Profile ✅
- Shows all user's stored data
- Allows updating profile info, uploading new images
- Real-time sync with Firestore
- Auto-fills with existing data on open

## User Data Isolation

### How It Works
1. **Authentication**: FirebaseAuth.currentUser provides uid
2. **Firestore Access**: All queries use `users/{currentUser.uid}`
3. **Storage Access**: File paths include userId (only owner can access)
4. **Authorization**: Rules verify request.auth.uid matches document/path uid

### Testing Isolation
```
Test: User A and User B should NOT see each other's data

Step 1: User A logs in
  → App shows User A's profile from Firestore
  
Step 2: User A logs out
  
Step 3: User B logs in
  → App shows ONLY User B's profile
  → User B CANNOT access User A's Firestore document
  → User B CANNOT see User A's storage files
```

## Firestore Structure

```json
{
  "users": {
    "uid_user_a": {
      "userId": "uid_user_a",
      "email": "usera@example.com",
      "firstName": "Ahmed",
      "lastName": "Ali",
      "phone": "+201234567890",
      "phone_verified": true,
      "email_verified": true,
      "email_verified_at": timestamp,
      "profilePictureUrl": "https://storage.googleapis.com/.../profile_picture.jpg",
      "carDetails": {
        "model": "Toyota",
        "plateNumber": "ABC-123",
        "color": "Black"
      },
      "driver_license_url": "https://storage.googleapis.com/.../driver_license.jpg",
      "car_license_url": "https://storage.googleapis.com/.../car_license.jpg",
      "bloodType": "O+",
      "dateOfBirth": "05/05/1995",
      "country": "Egypt",
      "allergies": "None",
      "hospitalInsurance": "ABC Insurance",
      "createdAt": timestamp,
      "updatedAt": timestamp
    },
    "uid_user_b": {
      "userId": "uid_user_b",
      "email": "userb@example.com",
      ...
    }
  }
}
```

## Code Examples

### Loading User Data
```dart
// This automatically scopes to current user only
final userService = UserService();
final profile = await userService.getUserProfile();
// Returns null if uid is null, preventing cross-user access
```

### Checking Email Verification
```dart
// In AuthGuard or after login
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)  // Scoped to current user
    .get();
final isEmailVerified = doc['email_verified'] == true;
```

### Saving Profile Changes
```dart
// Edit profile screen
await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)  // Only saves to current user's document
    .update({
      'firstName': newFirstName,
      'profilePictureUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
```

## Firebase Console Setup Checklist

- [ ] Firestore enabled
- [ ] Firestore security rules deployed (see below)
- [ ] Storage enabled
- [ ] Storage security rules deployed (see below)
- [ ] Authentication methods enabled:
  - [ ] Email/Password
  - [ ] Phone (SMS)
- [ ] SMS provider configured (for OTP delivery)
- [ ] Email templates configured (optional, uses default)

### Deploy Security Rules

**Firestore**:
1. Go to Firestore → Rules
2. Replace with rules from FIREBASE_SECURITY_RULES.md
3. Click Publish

**Storage**:
1. Go to Storage → Rules
2. Replace with storage rules from FIREBASE_SECURITY_RULES.md
3. Click Publish

## Common Scenarios

### Scenario 1: New User Registration
```
✓ Open app → tap "Sign Up"
✓ Fill form (personal info + car details + licenses)
✓ Submit → Firebase sends OTP via SMS
✓ Enter 6-digit code
✓ Account created, verify email prompt shown
✓ Click link in email
✓ Automatically redirected to home
✓ Can now use app with full access
```

### Scenario 2: Existing User Login
```
✓ Open app → "Login" screen
✓ Enter email & password
✓ ✓ Check: Is email verified in Firestore?
   └─ If NO: Show email verification screen
   └─ If YES: Show home
✓ If email not verified, can resend and verify
```

### Scenario 3: Switching Users on Same Device
```
User A:
✓ Logged in → sees User A's profile data
✓ Logs out

User B:
✓ Signs up or logs in
✓ Sees ONLY User B's data
✓ Cannot access any of User A's files/data
```

### Scenario 4: Edit Profile
```
✓ User opens Edit Profile
✓ Form loads with current user's data from Firestore
✓ User updates fields (name, car model, etc.)
✓ User uploads new profile picture
✓ Changes saved to Firestore
✓ Storage files updated with new images
✓ All changes propagate to other screens
```

## Important Security Rules

### Firestore Access
```
users/{userId}:
- Read: ✅ If request.auth.uid == userId
- Read: ❌ If request.auth.uid != userId
- Write: ✅ If request.auth.uid == userId
- Write: ❌ If request.auth.uid != userId
```

### Storage Access
```
profile_pictures/{userId}/*:
- Access: ✅ If request.auth.uid == userId
- Access: ❌ If request.auth.uid != userId

Same applies to:
- driver_license/{userId}/*
- car_license/{userId}/*
```

## Debugging Tips

### Check if User is Authenticated
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print('User ID: ${user.uid}');
  print('Email: ${user.email}');
  print('Email verified: ${user.emailVerified}');
} else {
  print('No user logged in');
}
```

### Check Firestore Email Verification Status
```dart
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();
print('Email verified in Firestore: ${doc['email_verified']}');
print('Phone verified: ${doc['phone_verified']}');
```

### Verify Security Rules Work
```dart
// This should succeed (user accessing own document)
final ownData = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();

// This should FAIL (user accessing another user's document)
// Uncomment to test - expect permission denied error
// final otherUserData = await FirebaseFirestore.instance
//     .collection('users')
//     .doc('some_other_uid')
//     .get();
```

## Support & Troubleshooting

### User can't receive OTP
→ Check phone number format matches country code  
→ Verify SMS provider credentials in Firebase Console  
→ Check SMS quota limits

### Email verification takes too long
→ Check email inbox and spam folder  
→ Click "Resend Verification Email" button  
→ Wait 5 minutes for Gmail delivery (normal)

### User can't log in
→ Verify email address is correct  
→ Check password is correct  
→ Verify email is verified in Firestore  
→ Check Firebase auth is working (no errors in console)

### Profile data not showing
→ Check Firestore document exists at `users/{uid}`  
→ Verify all required fields are present  
→ Check Firebase storage URLs are accessible  
→ Verify Firestore rules allow read access

---

**Quick Start**: See IMPLEMENTATION_FIXES_GUIDE.md for complete details
**Updated**: 2026-04-24
