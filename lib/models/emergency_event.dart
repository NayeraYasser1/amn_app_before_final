class EmergencyEvent {
  final String id;
  final String type; // e.g. sos, contact_call, hospital_call
  final String title;
  final String? description;
  final String? location;
  final String status; // e.g. Resolved, Cancelled, In Progress
  final DateTime timestamp;

  EmergencyEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.timestamp,
    this.description,
    this.location,
  });

  factory EmergencyEvent.fromMap(String id, Map<String, dynamic> data) {
    // timestamp may be a DateTime (Firestore) or an ISO String (local JSON).
    // Use an `is` check — a hard `as DateTime?` cast throws on a String.
    final rawTimestamp = data['timestamp'];
    final DateTime timestamp = rawTimestamp is DateTime
        ? rawTimestamp
        : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now();

    return EmergencyEvent(
      id: id,
      type: data['type'] as String? ?? 'unknown',
      title: data['title'] as String? ?? 'Emergency',
      status: data['status'] as String? ?? 'Resolved',
      description: data['description'] as String?,
      location: data['location'] as String?,
      timestamp: timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'location': location,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
