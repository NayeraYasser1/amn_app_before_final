/// A Safety Hub hospital. Extracted from safety_hub_screen.dart so the model
/// (and its single-default SOS invariant) is standalone and unit-testable.
class Hospital {
  final String name;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;

  /// The default hospital is the one the SOS button sends the emergency SMS to.
  /// Exactly one hospital is default at any time (see [ensureSingleDefault]).
  final bool isDefault;

  const Hospital({
    required this.name,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  Hospital copyWith({bool? isDefault}) => Hospital(
    name: name,
    phone: phone,
    address: address,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'default': isDefault,
  };

  factory Hospital.fromMap(Map<String, dynamic> map) {
    return Hospital(
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isDefault: map['default'] == true,
    );
  }

  /// Enforces exactly one default in [hospitals]: the first flagged one wins;
  /// if none is flagged, the first entry becomes default. Mutates in place.
  static void ensureSingleDefault(List<Hospital> hospitals) {
    if (hospitals.isEmpty) return;
    var idx = hospitals.indexWhere((h) => h.isDefault);
    if (idx < 0) idx = 0;
    for (var i = 0; i < hospitals.length; i++) {
      if (hospitals[i].isDefault != (i == idx)) {
        hospitals[i] = hospitals[i].copyWith(isDefault: i == idx);
      }
    }
  }
}
