class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String? email;
  final String? relationship;

  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.email,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString().trim();
    final relationship = json['relationship']?.toString().trim();

    return EmergencyContact(
      name: (json['name'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      email: email == null || email.isEmpty ? null : email,
      relationship: relationship == null || relationship.isEmpty
          ? null
          : relationship,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
    };
  }
}
