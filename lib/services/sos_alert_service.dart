import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sends real SOS alert SMS messages silently in the background through the
/// native Android SmsManager (channel `amn_app/sms`), so the emergency call
/// to 123 is never blocked by a messaging app in the foreground.
class SosAlertService {
  static const MethodChannel _channel = MethodChannel('amn_app/sms');

  /// True when SEND_SMS is already granted. When it is not, this also asks
  /// Android to show the permission dialog (result arrives asynchronously,
  /// so callers should treat `false` as "not granted yet").
  static Future<bool> ensureSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestSmsPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasSmsPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sends one SMS in the background. Returns true when the message was
  /// handed to the system SMS service (carrier delivery is not tracked).
  static Future<bool> sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'sendSms',
        {'phone': phone, 'message': message},
      );
      return result?['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// First contact from the Safety Hub list (same seed fallback the Safety
  /// Hub and voice assistant use before the user saves their own).
  static Future<Map<String, String>?> firstEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = _decodeList(prefs.getString('safety_hub_contacts_json'));
    if (contacts.isEmpty) {
      return {'name': 'Nayera', 'phone': '01012345678', 'relationship': 'Mom'};
    }
    final first = contacts.first;
    final phone = (first['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    return {
      'name': (first['name'] ?? '').toString(),
      'phone': phone,
      'relationship': (first['relationship'] ?? '').toString(),
    };
  }

  /// First hospital from the Safety Hub list (seed fallback: El Salam).
  static Future<Map<String, String>?> firstHospital() async {
    final prefs = await SharedPreferences.getInstance();
    final hospitals = _decodeList(prefs.getString('safety_hub_hospitals_json'));
    if (hospitals.isEmpty) {
      return {'name': 'El Salam Hospital', 'phone': '19885'};
    }
    final first = hospitals.first;
    final phone = (first['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    return {'name': (first['name'] ?? '').toString(), 'phone': phone};
  }
}
