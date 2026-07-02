import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _storage = storage ?? const FlutterSecureStorage();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _storage;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signIn failed: ${e.code} ${e.message}');
      return _mapSignInError(e.code);
    } catch (e) {
      debugPrint('AuthService.signIn unexpected error: $e');
      return 'Unable to sign in. Please try again later.';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.register failed: ${e.code} ${e.message}');
      return _mapRegisterError(e.code);
    } catch (e) {
      debugPrint('AuthService.register unexpected error: $e');
      return 'Unable to create account right now. Please try again later.';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return 'Google sign-in was cancelled.';
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (accessToken == null || idToken == null) {
        return 'Google sign-in failed. Please try again.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.signInWithGoogle failed: ${e.code} ${e.message}');
      return 'Unable to sign in with Google. Please try again later.';
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle unexpected error: $e');
      return 'Unable to sign in with Google. Please try again later.';
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut GoogleSignIn signOut failed: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService.signOut FirebaseAuth.signOut failed: $e');
    }

    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('AuthService.signOut secure storage deleteAll failed: $e');
    }
  }

  Future<String?> getValidToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      return await user.getIdToken(true);
    } catch (e) {
      debugPrint('AuthService.getValidToken failed: $e');
      return null;
    }
  }

  String _mapSignInError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Account temporarily locked. Try again later.';
      case 'invalid-email':
        return 'The email address is invalid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support if you need help.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Unable to sign in. Please check your credentials and try again.';
    }
  }

  String _mapRegisterError(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password is too weak. Please choose a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is invalid. Please check and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is currently disabled. Contact support.';
      default:
        return 'Unable to create the account. Please try again later.';
    }
  }
}
