# Integration Guide: Adding Complete Profile Screen to Signup Flow

## Overview
This document shows how to integrate the new `CompleteProfileScreen` into your existing signup and verification flow.

## Current Flow
1. User enters email, phone, password, and uploads licenses
2. Phone verification is triggered
3. User enters verification code
4. Account is created

## Updated Flow
1. User enters email, phone, password, and uploads licenses (existing)
2. Phone verification is triggered (existing)
3. User enters verification code (existing)
4. **NEW: User completes profile with personal & car details**
5. User redirected to home screen

## Required Changes

### 1. Update verify_code_screen.dart

Add navigation to complete profile screen after successful verification:

```dart
// In your verify_code_screen.dart, locate the verification success handler

// BEFORE: Direct navigation to home
// Navigator.pushReplacementNamed(context, 'home');

// AFTER: Navigate to complete profile first
if (mounted) {
  Navigator.pushNamed(
    context,
    'complete-profile',
    arguments: {
      'email': widget.email,
      'userId': FirebaseAuth.instance.currentUser!.uid,
    },
  );
}
```

### 2. Update main.dart Routes

Add the new route to your named routes:

```dart
MaterialApp(
  // ... other config
  routes: {
    'signup': (context) => const SignUpScreen(),
    'verify-code': (context) {
      final args = ModalRoute.of(context)?.settings.arguments 
          as VerifyCodeArgs?;
      return VerifyCodeScreen(args: args);
    },
    // NEW ROUTE
    'complete-profile': (context) {
      final args = ModalRoute.of(context)?.settings.arguments 
          as Map<String, dynamic>;
      return CompleteProfileScreen(
        email: args['email'] as String,
        userId: args['userId'] as String,
      );
    },
    'home': (context) => const HomePage(),
    'login': (context) => const LoginScreen(),
    // ... other routes
  },
);
```

### 3. Update Material App Imports

Ensure you import the new screen:

```dart
import 'package:amn_app/screens/complete_profile_screen.dart';
```

## Example: Updated Verify Code Screen Section

Here's an example of the modification needed in `verify_code_screen.dart`:

```dart
// Locate the section that handles successful verification
// It might look something like this:

Future<void> _verifyCode() async {
  try {
    // ... verification logic ...
    
    // After successful authentication
    if (mounted) {
      // CHANGE THIS SECTION:
      
      // OLD CODE:
      // Navigator.pushReplacementNamed(context, 'home');
      
      // NEW CODE:
      Navigator.pushNamed(
        context,
        'complete-profile',
        arguments: {
          'email': widget.email, // From VerifyCodeArgs
          'userId': FirebaseAuth.instance.currentUser!.uid,
        },
      );
    }
  } catch (e) {
    // ... error handling ...
  }
}
```

## Example: Complete verify_code_screen.dart Integration

If you need to see the full context, here's how the navigation typically flows:

```dart
class VerifyCodeScreen extends StatefulWidget {
  final VerifyCodeArgs? args;
  
  const VerifyCodeScreen({Key? key, this.args}) : super(key: key);

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.args!.verificationId,
        smsCode: _codeController.text,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // After successful sign-in, complete the registration
      // by navigating to complete profile screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          'complete-profile',
          arguments: {
            'email': widget.args!.email,
            'userId': FirebaseAuth.instance.currentUser!.uid,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI code ...
  }
}
```

## Data Flow Diagram

```
┌─────────────────────┐
│   SignUp Screen     │
│ (email, phone, pwd) │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Phone Verification │
│   (SMS Code)        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Auth User Created  │
│ (in Firebase Auth)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────┐
│ Complete Profile Screen │ ◄─── NEW STEP
│ (names, picture, car)   │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────┐
│  UserProfile Saved  │
│ (in Firestore)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Home Screen       │
└─────────────────────┘
```

## Testing the Integration

### 1. Test Complete Flow
```
1. Open app
2. Tap "Sign Up"
3. Enter email, phone, password, upload licenses
4. Tap "Sign up" button
5. Receive SMS code
6. Enter SMS code
7. Should navigate to "Complete Profile Screen"
8. Fill in first name, last name
9. Optionally upload profile picture
10. Select car model
11. Enter plate number
12. Select car color
13. Tap "Complete Profile"
14. Should navigate to Home screen
```

### 2. Verify Firestore Data
After completing the profile, check Firebase Console:
- Go to Firestore Database
- Navigate to `users` collection
- Find document with user's UID
- Verify all fields are populated correctly

### 3. Verify Storage Upload
Check Firebase Storage:
- Navigate to `profile_pictures/{userId}/`
- Should contain the uploaded image

## Troubleshooting

### Issue: Navigation doesn't work
**Solution**: Ensure route name in `pushNamed()` matches exactly in `routes` map.

### Issue: Arguments not passing
**Solution**: Verify the arguments map structure matches what `CompleteProfileScreen` expects.

### Issue: Image upload fails
**Solution**: Check Firebase Storage rules and ensure user is authenticated.

### Issue: Firestore write fails
**Solution**: Check Firestore security rules and ensure user ID matches authentication UID.

## Optional: Add Progress Indicator

If you want to show progress through the signup steps:

```dart
// In complete_profile_screen.dart, add a progress indicator in AppBar
AppBar(
  backgroundColor: Colors.black,
  elevation: 0,
  title: const Text(
    'Complete Your Profile',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
  subtitle: const Text(
    'Step 2 of 2',
    style: TextStyle(color: Colors.grey, fontSize: 12),
  ),
  centerTitle: true,
)
```

## Optional: Skip Profile Completion

If you want to allow users to skip profile completion initially:

```dart
// Add a "Skip for now" button
TextButton(
  onPressed: () {
    Navigator.pushReplacementNamed(context, 'home');
  },
  child: const Text(
    'Skip for now',
    style: TextStyle(color: Colors.grey),
  ),
)
```

Then later prompt users to complete their profile from the home screen.
