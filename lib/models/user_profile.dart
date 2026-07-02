import 'package:cloud_firestore/cloud_firestore.dart';

class CarDetails {
  final String? model;
  final String? plateNumber;
  final String? color;

  CarDetails({this.model, this.plateNumber, this.color});

  /// Convert CarDetails to Map for Firestore
  Map<String, dynamic> toMap() {
    return {'model': model, 'plateNumber': plateNumber, 'color': color};
  }

  /// Create CarDetails from Firestore Map
  factory CarDetails.fromMap(Map<String, dynamic> map) {
    return CarDetails(
      model: map['model'] as String?,
      plateNumber: map['plateNumber'] as String?,
      color: map['color'] as String?,
    );
  }

  /// Create an empty CarDetails instance
  factory CarDetails.empty() {
    return CarDetails(model: null, plateNumber: null, color: null);
  }

  /// Copy with method for updating specific fields
  CarDetails copyWith({String? model, String? plateNumber, String? color}) {
    return CarDetails(
      model: model ?? this.model,
      plateNumber: plateNumber ?? this.plateNumber,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'CarDetails(model: $model, plateNumber: $plateNumber, color: $color)';
  }
}

class UserProfile {
  final String userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final CarDetails carDetails;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.userId,
    this.email,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    required this.carDetails,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert UserProfile to Map for Firestore
  Map<String, dynamic> toMap() {
    final url = profilePictureUrl?.trim();
    final hasProfilePhoto = url != null && url.isNotEmpty;
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profilePictureUrl': hasProfilePhoto ? url : null,
      if (hasProfilePhoto) 'profileImageUrl': url,
      'carDetails': carDetails.toMap(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// Create UserProfile from Firestore Map
  factory UserProfile.fromMap(Map<String, dynamic> map, String userId) {
    final picture =
        (map['profilePictureUrl'] as String?)?.trim().isNotEmpty == true
        ? map['profilePictureUrl'] as String
        : (map['profileImageUrl'] as String?)?.trim();
    return UserProfile(
      userId: userId,
      email: map['email'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      profilePictureUrl: picture?.isNotEmpty == true ? picture : null,
      carDetails: map['carDetails'] != null
          ? CarDetails.fromMap(map['carDetails'] as Map<String, dynamic>)
          : CarDetails.empty(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create UserProfile from Firestore DocumentSnapshot
  factory UserProfile.fromSnapshot(DocumentSnapshot snapshot) {
    return UserProfile.fromMap(
      snapshot.data() as Map<String, dynamic>,
      snapshot.id,
    );
  }

  /// Copy with method for updating specific fields
  UserProfile copyWith({
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? profilePictureUrl,
    CarDetails? carDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      carDetails: carDetails ?? this.carDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get full name
  String getFullName() {
    final first = firstName ?? '';
    final last = lastName ?? '';
    return '$first $last'.trim();
  }

  @override
  String toString() {
    return 'UserProfile(userId: $userId, email: $email, firstName: $firstName, lastName: $lastName, '
        'profilePictureUrl: $profilePictureUrl, carDetails: $carDetails)';
  }
}
