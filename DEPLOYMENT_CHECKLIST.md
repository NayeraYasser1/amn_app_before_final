# Firebase Deployment Checklist

Complete this checklist before deploying the updated sign-up system to production.

## Pre-Deployment Verification

### Code Changes Reviewed
- [ ] `lib/screens/email_verification_screen.dart` - Email verification UI and logic
- [ ] `lib/screens/verify_code_screen.dart` - Phone OTP to email verification flow
- [ ] `lib/widgets/auth_guard.dart` - Email verification requirement added
- [ ] `lib/main.dart` - Email verification route added
- [ ] All imports are correct and no compilation errors

### Local Testing Complete
- [ ] ✓ Sign-up flow with phone OTP works
- [ ] ✓ Email verification screen appears after OTP
- [ ] ✓ Resend verification email works
- [ ] ✓ Email verification auto-detects completion
- [ ] ✓ User cannot access app without email verification
- [ ] ✓ Edit profile loads user data correctly
- [ ] ✓ Profile updates save to Firestore
- [ ] ✓ No console errors or warnings

### Build Verification
- [ ] App compiles without errors: `flutter clean && flutter pub get && flutter build apk`
- [ ] No compilation warnings
- [ ] All dependencies are correct versions

## Firebase Console Configuration

### Authentication Setup
- [ ] Email/Password method enabled
- [ ] Phone authentication method enabled
- [ ] SMS provider configured (for OTP delivery)
  - [ ] Provider credentials entered
  - [ ] SMS template configured (or using default)
- [ ] Email action links configured
  - [ ] Email verification link URL is correct
  - [ ] Link points to your app (deep link configured)
- [ ] Email templates set (optional, can use Firebase default)

### Firestore Setup
- [ ] Firestore database created in production mode (NOT test mode)
- [ ] Database location selected (recommended: same as app region)
- [ ] Backup enabled (optional but recommended)

### Storage Setup
- [ ] Storage bucket created
- [ ] Storage location selected (recommended: same as Firestore region)
- [ ] Versioning disabled (not needed for this app)

## Security Rules Deployment (CRITICAL ⚠️)

### Firestore Rules

1. Open Firebase Console → Firestore Database → Rules
2. Copy rules below and replace existing rules
3. Click "Publish"

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
    
    // Users collection - strict UID-based access control
    match /users/{userId} {
      // Only authenticated users can read their own document
      allow read: if isUserAuthenticated() && isOwner(userId);
      
      // Only authenticated users can write to their own document
      allow write: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Deny all other collections/documents by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] Rules pasted
- [ ] Rules syntax is valid (no red errors shown)
- [ ] Clicked "Publish"
- [ ] ✓ Confirmation: "Rules publishing completed successfully"

### Storage Rules

1. Open Firebase Console → Storage → Rules
2. Copy rules below and replace existing rules
3. Click "Publish"

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
    
    // Profile pictures - user can only manage their own
    match /profile_pictures/{userId}/{allPaths=**} {
      allow read: if isUserAuthenticated() && isOwner(userId);
      allow write: if isUserAuthenticated() && 
                      isOwner(userId) &&
                      request.resource.size < 5 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/.*');
      allow delete: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Driver licenses - user can only manage their own
    match /driver_license/{userId}/{allPaths=**} {
      allow read: if isUserAuthenticated() && isOwner(userId);
      allow write: if isUserAuthenticated() && 
                      isOwner(userId) &&
                      request.resource.size < 8 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/(jpeg|png|webp)');
      allow delete: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Car licenses - user can only manage their own
    match /car_license/{userId}/{allPaths=**} {
      allow read: if isUserAuthenticated() && isOwner(userId);
      allow write: if isUserAuthenticated() && 
                      isOwner(userId) &&
                      request.resource.size < 8 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/(jpeg|png|webp)');
      allow delete: if isUserAuthenticated() && isOwner(userId);
    }
    
    // Deny all other storage access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] Rules pasted
- [ ] Rules syntax is valid (no red errors shown)
- [ ] Clicked "Publish"
- [ ] ✓ Confirmation: "Rules publishing completed successfully"

## Pre-Production Testing (After Rules Deployment)

### Test User Registration
Create a test user to verify complete flow:

- [ ] Open app and tap "Sign Up"
- [ ] Fill in all required fields
- [ ] Submit form
- [ ] Receive SMS with OTP code
- [ ] Enter OTP successfully
- [ ] Account created and redirected to email verification screen
- [ ] Check email inbox for verification link (may take up to 5 minutes)
- [ ] Click verification link
- [ ] Screen shows "Email verified successfully!"
- [ ] Automatically redirected to home
- [ ] Home page loads successfully with test user's data

### Test Email Verification
- [ ] User cannot access home while email unverified ✓
- [ ] "Resend Verification Email" button works ✓
- [ ] Multiple verification emails can be resent ✓
- [ ] 10-minute timeout works (user logged out if not verified)
- [ ] Verification screen auto-detects when email is verified

### Test User Data Isolation
**Create 2 test users (User A and User B)**:

User A Flow:
- [ ] User A signs up and verifies email
- [ ] User A sees their profile in Edit Profile screen
- [ ] User A's car details are visible
- [ ] User A's profile picture is loaded

Switch Users:
- [ ] User A logs out
- [ ] User B signs up and verifies email
- [ ] User B opens Edit Profile
- [ ] ✓ User B ONLY sees User B's data
- [ ] ✓ User B does NOT see User A's data
- [ ] Confirm in Firebase Console that each user has separate Firestore document

### Test Profile Editing
- [ ] Load existing user profile
- [ ] Edit name fields
- [ ] Update car model and color
- [ ] Upload new profile picture
- [ ] Save changes
- [ ] Refresh screen - changes persist
- [ ] Log out and log back in - changes still visible

### Test Security Rules

**Firestore Security:**
- [ ] Authenticated user can read their own document
- [ ] Authenticated user can write to their own document
- [ ] User CANNOT read another user's document (will fail)
- [ ] User CANNOT write to another user's document (will fail)

**Storage Security:**
- [ ] User can upload to their own profile_pictures/{uid}/ folder
- [ ] User can download their own files
- [ ] User CANNOT upload to another user's folder (will fail)
- [ ] User CANNOT download another user's files (will fail)

## Android Deployment

### App Signing
- [ ] Signing key configured in `android/key.properties`
- [ ] Release keystore generated and backed up securely
- [ ] App signed with release key

### Build for Release
```bash
flutter build apk --release
# or for bundle
flutter build appbundle --release
```
- [ ] Build completes without errors
- [ ] APK/Bundle size is reasonable (~40-100MB)

### Play Store Submission
- [ ] App version incremented (1.0.0 → 1.0.1)
- [ ] App description updated with new features
- [ ] Screenshots updated showing new verification flow
- [ ] Release notes mention:
  - "Added email verification for enhanced security"
  - "Improved phone number verification process"
  - "Enhanced profile data management"
- [ ] Privacy policy updated to mention email/phone verification
- [ ] Submitted to Google Play Store

## iOS Deployment (If Applicable)

- [ ] Update version number in XCode
- [ ] Firebase iOS SDK configuration updated
- [ ] Build and test on physical iOS device
- [ ] TestFlight testing completed
- [ ] App Store Connect submission
- [ ] Wait for App Store review approval

## Post-Deployment Monitoring

### First 24 Hours
- [ ] Monitor Firebase crash logs (Crashlytics)
- [ ] Check Firestore quota usage
- [ ] Check Storage quota usage
- [ ] Monitor authentication success/failure rates
- [ ] Check SMS delivery rates (if available)

### First Week
- [ ] Review user feedback for sign-up issues
- [ ] Monitor Firebase performance metrics
- [ ] Check for any data consistency issues
- [ ] Verify email verification is working for all users

### Ongoing
- [ ] Monitor Firestore writes/reads per day
- [ ] Track storage usage growth
- [ ] Review failed authentication attempts (security issues)
- [ ] Monitor email verification completion rate

## Rollback Plan (If Issues Occur)

### If Security Rules Cause Problems
1. Go to Firebase Console → Rules
2. Click "Last published version" dropdown
3. Select previous working version
4. Click "Publish"

### If App Has Critical Bug
1. Disable production version in Play Store
2. Fix code locally
3. Deploy hotfix version
4. Re-enable in Play Store

## Sign-Off

- [ ] **Developer**: _________________ Date: _______
- [ ] **QA Lead**: _________________ Date: _______
- [ ] **Product Owner**: _________________ Date: _______
- [ ] **Security Review**: _________________ Date: _______

## Documentation Links

- IMPLEMENTATION_FIXES_GUIDE.md - Complete implementation details
- SIGNUP_SYSTEM_REFERENCE.md - Quick reference guide
- FIREBASE_SECURITY_RULES.md - Security rules documentation

---

**Last Updated**: 2026-04-24
**Status**: Ready for Deployment
