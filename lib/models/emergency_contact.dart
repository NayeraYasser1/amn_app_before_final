/// A Safety Hub emergency contact. Extracted from safety_hub_screen.dart so the
/// model (and its single-default SOS invariant) is standalone and unit-testable.
class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  /// The default contact is the one the SOS button sends the emergency SMS to.
  /// Exactly one contact is default at any time (see [ensureSingleDefault]).
  final bool isDefault;

  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relationship,
    this.isDefault = false,
  });

  EmergencyContact copyWith({bool? isDefault}) => EmergencyContact(
    name: name,
    phone: phone,
    relationship: relationship,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'default': isDefault,
  };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      relationship: (map['relationship'] ?? '').toString(),
      isDefault: map['default'] == true,
    );
  }

  /// Enforces exactly one default in [contacts] (the SOS target): the first
  /// flagged one wins; if none is flagged, the first entry becomes default.
  /// Mutates the list in place.
  static void ensureSingleDefault(List<EmergencyContact> contacts) {
    if (contacts.isEmpty) return;
    var idx = contacts.indexWhere((c) => c.isDefault);
    if (idx < 0) idx = 0;
    for (var i = 0; i < contacts.length; i++) {
      if (contacts[i].isDefault != (i == idx)) {
        contacts[i] = contacts[i].copyWith(isDefault: i == idx);
      }
    }
  }
}
