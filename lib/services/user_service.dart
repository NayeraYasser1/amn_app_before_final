import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:amn_app/models/user_profile.dart';

class UserService {
  UserService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Get current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Reference to users collection
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Reference to current user document
  DocumentReference<Map<String, dynamic>> get _currentUserDoc {
    if (currentUser == null) {
      throw Exception('No authenticated user found');
    }
    return _usersCollection.doc(currentUser!.uid);
  }

  /// Create a new user profile in Firestore
  /// Called after successful authentication
  Future<void> createUserProfile({
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final userProfile = UserProfile(
        userId: currentUser!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        profilePictureUrl: null,
        carDetails: CarDetails.empty(),
      );

      await _currentUserDoc.set(userProfile.toMap(), SetOptions(merge: true));
      debugPrint(
        'UserService.createUserProfile: Profile created for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.createUserProfile failed: $e');
      rethrow;
    }
  }

  /// Get user profile from Firestore
  Future<UserProfile?> getUserProfile({String? userId}) async {
    try {
      final uid = userId ?? currentUser?.uid;
      if (uid == null) {
        throw Exception('No user ID provided and no authenticated user');
      }

      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        return null;
      }

      return UserProfile.fromSnapshot(doc);
    } catch (e) {
      debugPrint('UserService.getUserProfile failed: $e');
      rethrow;
    }
  }

  /// Stream of user profile changes
  Stream<UserProfile?> userProfileStream({String? userId}) {
    try {
      final uid = userId ?? currentUser?.uid;
      if (uid == null) {
        throw Exception('No user ID provided and no authenticated user');
      }

      return _usersCollection.doc(uid).snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        return UserProfile.fromSnapshot(doc);
      });
    } catch (e) {
      debugPrint('UserService.userProfileStream failed: $e');
      rethrow;
    }
  }

  /// Upload profile picture to Firebase Storage
  /// Returns the download URL
  Future<String> uploadProfilePicture(File imageFile) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final userId = currentUser!.uid;
      final fileName =
          'profile_pictures/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final reference = _storage.ref().child(fileName);

      // Upload file
      await reference.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': userId},
        ),
      );

      // Get download URL
      final downloadUrl = await reference.getDownloadURL();

      debugPrint('UserService.uploadProfilePicture: Uploaded to $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('UserService.uploadProfilePicture failed: $e');
      rethrow;
    }
  }

  /// Update user profile with profile picture URL
  Future<void> updateProfilePictureUrl(String downloadUrl) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _currentUserDoc.update({
        'profilePictureUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'UserService.updateProfilePictureUrl: Updated for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.updateProfilePictureUrl failed: $e');
      rethrow;
    }
  }

  /// Update user's first name and last name
  Future<void> updateUserNames({
    required String firstName,
    required String lastName,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _currentUserDoc.update({
        'firstName': firstName,
        'lastName': lastName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'UserService.updateUserNames: Updated for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.updateUserNames failed: $e');
      rethrow;
    }
  }

  /// Update car details
  Future<void> updateCarDetails(CarDetails carDetails) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _currentUserDoc.update({
        'carDetails': carDetails.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'UserService.updateCarDetails: Updated for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.updateCarDetails failed: $e');
      rethrow;
    }
  }

  /// Update individual car detail field
  Future<void> updateCarDetailField({
    required String field,
    required String value,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _currentUserDoc.update({
        'carDetails.$field': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'UserService.updateCarDetailField: Updated $field for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.updateCarDetailField failed: $e');
      rethrow;
    }
  }

  /// Update entire user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      await _currentUserDoc.set(profile.toMap(), SetOptions(merge: true));

      debugPrint(
        'UserService.updateUserProfile: Updated for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.updateUserProfile failed: $e');
      rethrow;
    }
  }

  /// Delete profile picture from Storage
  Future<void> deleteProfilePicture(String pictureUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(pictureUrl);
      final pathSegments = uri.pathSegments;

      // Find the index where 'o' appears (the path starts after that)
      final startIndex = pathSegments.indexWhere((segment) => segment == 'o');
      if (startIndex == -1) {
        debugPrint('UserService.deleteProfilePicture: Could not parse URL');
        return;
      }

      final filePath = pathSegments
          .skip(startIndex + 1)
          .join('/')
          .split('?')
          .first;
      final decodedPath = Uri.decodeComponent(filePath);

      await _storage.ref(decodedPath).delete();
      debugPrint('UserService.deleteProfilePicture: Deleted $decodedPath');
    } catch (e) {
      debugPrint('UserService.deleteProfilePicture failed: $e');
      // Don't rethrow as this is a cleanup operation
    }
  }

  /// Delete entire user profile
  Future<void> deleteUserProfile() async {
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Delete profile picture if it exists
      final profile = await getUserProfile();
      if (profile?.profilePictureUrl != null) {
        await deleteProfilePicture(profile!.profilePictureUrl!);
      }

      // Delete user document
      await _currentUserDoc.delete();

      debugPrint(
        'UserService.deleteUserProfile: Deleted for ${currentUser!.uid}',
      );
    } catch (e) {
      debugPrint('UserService.deleteUserProfile failed: $e');
      rethrow;
    }
  }

  /// Check if user profile exists
  Future<bool> userProfileExists({String? userId}) async {
    try {
      final uid = userId ?? currentUser?.uid;
      if (uid == null) {
        return false;
      }

      final doc = await _usersCollection.doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('UserService.userProfileExists failed: $e');
      return false;
    }
  }
}
