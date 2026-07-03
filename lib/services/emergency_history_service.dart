import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_event.dart';

class EmergencyHistoryService {
  EmergencyHistoryService._();

  static const String _localStorageKey = 'amn_history_events_json';
  // Broadcast stream of local history. localEventsStream() already seeds the
  // current value per listener, so we do NOT refresh in onListen (that caused
  // a duplicate initial emission and an extra prefs read per subscriber).
  static final StreamController<List<EmergencyEvent>> _controller =
      StreamController<List<EmergencyEvent>>.broadcast();

  // Serializes every read-modify-write so concurrent callers (e.g. an SOS
  // logEvent racing a user delete) cannot overwrite each other's changes.
  static Future<void> _writeQueue = Future<void>.value();

  // Monotonic suffix so two events created in the same microsecond get
  // distinct ids (microsecondsSinceEpoch alone can collide), keeping
  // delete/restore-by-id correct.
  static int _idCounter = 0;

  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('emergency_events');

  static Future<void> logEvent({
    required String type,
    required String title,
    String? description,
    String? location,
    String status = 'Resolved',
  }) async {
    final event = EmergencyEvent(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}',
      type: type,
      title: title,
      description: description,
      location: location,
      status: status,
      timestamp: DateTime.now(),
    );

    await _saveLocalEvent(event);

    try {
      await _collection.add({
        'type': type,
        'title': title,
        'description': description,
        'location': location,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Local history remains available even when Firestore is offline.
    }
  }

  static Future<void> refresh() async {
    _controller.add(await _loadLocalEvents());
  }

  /// Removes a single local history event by id.
  static Future<void> deleteEvent(String id) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadLocalEvents()
        ..removeWhere((event) => event.id == id);
      await prefs.setString(
        _localStorageKey,
        jsonEncode(events.map((item) => item.toMap()).toList()),
      );
      _controller.add(events);
    });
  }

  /// Re-inserts a previously deleted event (used for Undo). Events are kept
  /// sorted newest-first so the entry returns to its original position.
  static Future<void> restoreEvent(EmergencyEvent event) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadLocalEvents()..add(event);
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await prefs.setString(
        _localStorageKey,
        jsonEncode(events.map((item) => item.toMap()).toList()),
      );
      _controller.add(events);
    });
  }

  static Future<void> _saveLocalEvent(EmergencyEvent event) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final events = [event, ...await _loadLocalEvents()]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final capped = events.take(200).toList();
      // Stored as a single JSON string (setString), not a string list,
      // because getStringList proved unreliable on this platform.
      await prefs.setString(
        _localStorageKey,
        jsonEncode(capped.map((item) => item.toMap()).toList()),
      );
      _controller.add(capped);
    });
  }

  static Future<List<EmergencyEvent>> _loadLocalEvents() async {
    final prefs = await SharedPreferences.getInstance();

    String? raw;
    try {
      raw = prefs.getString(_localStorageKey);
    } catch (_) {
      // The key may still hold an old string-list value; ignore and reset.
      raw = null;
    }
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final events = decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (item) =>
                EmergencyEvent.fromMap((item['id'] ?? '').toString(), item),
          )
          .toList();
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events;
    } catch (_) {
      return [];
    }
  }

  static Stream<List<EmergencyEvent>> localEventsStream() async* {
    yield await _loadLocalEvents();
    yield* _controller.stream;
  }

  static Stream<List<EmergencyEvent>> eventsStream() {
    return localEventsStream();
  }

  static Stream<List<EmergencyEvent>> firestoreEventsStream() {
    // Bounded so a growing collection never streams every document (unbounded
    // reads + memory). The local history is the primary source; this mirror is
    // capped to the most recent 200 to match _saveLocalEvent's cap.
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'];
        DateTime ts;
        if (timestamp is Timestamp) {
          ts = timestamp.toDate();
        } else {
          ts = DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now();
        }

        return EmergencyEvent(
          id: doc.id,
          type: data['type'] as String? ?? 'unknown',
          title: data['title'] as String? ?? 'Emergency',
          description: data['description'] as String?,
          location: data['location'] as String?,
          status: data['status'] as String? ?? 'Resolved',
          timestamp: ts,
        );
      }).toList();
    });
  }
}
