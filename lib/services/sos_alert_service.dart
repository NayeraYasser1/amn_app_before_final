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

  /// The Safety Hub contact marked as the SOS default (falling back to the
  /// first contact, then to the seed used before the user saves their own).
  static Future<Map<String, String>?> firstEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = _decodeList(prefs.getString('safety_hub_contacts_json'));
    if (contacts.isEmpty) {
      return {'name': 'Nayera', 'phone': '01012345678', 'relationship': 'Mom'};
    }
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

  /// The Safety Hub hospital marked as the SOS default (falling back to the
  /// first hospital, then to the El Salam seed).
  static Future<Map<String, String>?> firstHospital() async {
    final prefs = await SharedPreferences.getInstance();
    final hospitals = _decodeList(prefs.getString('safety_hub_hospitals_json'));
    if (hospitals.isEmpty) {
      return {'name': 'El Salam Hospital', 'phone': '19885'};
    }
    final chosen = hospitals.firstWhere(
      (h) => h['default'] == true,
      orElse: () => hospitals.first,
    );
    final phone = (chosen['phone'] ?? '').toString().trim();
    if (phone.isEmpty) return null;
    return {'name': (chosen['name'] ?? '').toString(), 'phone': phone};
  }
}
