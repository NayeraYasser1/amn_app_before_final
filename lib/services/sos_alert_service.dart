import 'package:flutter/services.dart';

import 'emergency_contacts_repository.dart';

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

  /// The Safety Hub contact marked as the SOS default. Delegates to the shared
  /// [EmergencyContactsRepository] so contact selection lives in one place;
  /// returns null when no contact is saved (never a seed).
  static Future<Map<String, String>?> firstEmergencyContact() =>
      EmergencyContactsRepository.defaultContact();

  /// The Safety Hub hospital marked as the SOS default. Delegates to the shared
  /// [EmergencyContactsRepository] (which also rejects voice-only short codes).
  static Future<Map<String, String>?> firstHospital() =>
      EmergencyContactsRepository.defaultHospital();
}
