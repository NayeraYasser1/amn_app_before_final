import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for the Safety Hub emergency contacts and hospitals
/// that the SOS flow, the active-emergency screen and the voice assistant all
/// read. It owns the SharedPreferences keys, the JSON decode, and the
/// default-selection policy so the same data can never be decoded — or seeded —
/// inconsistently across screens.
///
/// Critically: this layer NEVER injects placeholder/seed contacts. An empty
/// list means the user has saved none, and the SOS/voice paths must treat that
/// as "no contact configured" rather than dialing or texting a made-up number
/// that could belong to a real stranger.
class EmergencyContactsRepository {
  const EmergencyContactsRepository._();

  static const String contactsKey = 'safety_hub_contacts_json';
  static const String hospitalsKey = 'safety_hub_hospitals_json';

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// All saved contacts as raw maps. Never seeded — an empty list is truthful.
  static Future<List<Map<String, dynamic>>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(contactsKey));
  }

  /// All saved hospitals as raw maps. Never seeded.
  static Future<List<Map<String, dynamic>>> loadHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(hospitalsKey));
  }

  /// The contact marked as the SOS default (falling back to the first saved
  /// contact). Returns null when none are saved, so callers never invent a
  /// number.
  static Future<Map<String, String>?> defaultContact() async {
    final contacts = await loadContacts();
    if (contacts.isEmpty) return null;
    final chosen = contacts.firstWhere(
      (c) => c['default'] == true,
      orElse: () => contacts.first,
    );
    final phone = (chosen['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    return {
      'name': (chosen['name'] ?? '').toString(),
      'phone': phone,
      'relationship': (chosen['relationship'] ?? '').toString(),
    };
  }

  /// The hospital marked as the SOS default (falling back to the first saved).
  /// Returns null when none are saved, or when the number is a short code
  /// (<= 6 digits) — Egyptian hospital hotlines like 19885 are voice-only and
  /// cannot receive an SMS, so we never pretend to text one.
  static Future<Map<String, String>?> defaultHospital() async {
    final hospitals = await loadHospitals();
    if (hospitals.isEmpty) return null;
    final chosen = hospitals.firstWhere(
      (h) => h['default'] == true,
      orElse: () => hospitals.first,
    );
    final phone = (chosen['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 6) return null;
    return {'name': (chosen['name'] ?? '').toString(), 'phone': phone};
  }
}
