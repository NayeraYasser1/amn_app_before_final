// Unit tests for the SOS-critical contact/hospital selection logic. These lock
// in the C1 fix: the repository must NEVER invent a seed number and must reject
// voice-only hospital short codes.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amn_app/services/emergency_contacts_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String encode(List<Map<String, dynamic>> list) => jsonEncode(list);

  group('defaultContact', () {
    test('returns null when no contacts are saved (never a seed stranger)',
        () async {
      SharedPreferences.setMockInitialValues({});
      expect(await EmergencyContactsRepository.defaultContact(), isNull);
    });

    test('returns the contact flagged as default', () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.contactsKey: encode([
          {'name': 'A', 'phone': '01000000001', 'relationship': 'Friend'},
          {
            'name': 'B',
            'phone': '01000000002',
            'relationship': 'Mom',
            'default': true,
          },
        ]),
      });
      final c = await EmergencyContactsRepository.defaultContact();
      expect(c?['name'], 'B');
      expect(c?['phone'], '01000000002');
    });

    test('falls back to the first contact when none is flagged default',
        () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.contactsKey: encode([
          {'name': 'A', 'phone': '01000000001'},
          {'name': 'B', 'phone': '01000000002'},
        ]),
      });
      final c = await EmergencyContactsRepository.defaultContact();
      expect(c?['name'], 'A');
    });

    test('returns null when the chosen contact has a blank phone', () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.contactsKey: encode([
          {'name': 'A', 'phone': '', 'default': true},
        ]),
      });
      expect(await EmergencyContactsRepository.defaultContact(), isNull);
    });
  });

  group('defaultHospital', () {
    test('returns null when no hospitals are saved', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await EmergencyContactsRepository.defaultHospital(), isNull);
    });

    test('rejects a voice-only short code (<= 6 digits)', () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.hospitalsKey: encode([
          {'name': 'El Salam', 'phone': '19885', 'default': true},
        ]),
      });
      expect(await EmergencyContactsRepository.defaultHospital(), isNull);
    });

    test('returns a hospital with a real (long) number', () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.hospitalsKey: encode([
          {'name': 'General', 'phone': '01555555555', 'default': true},
        ]),
      });
      final h = await EmergencyContactsRepository.defaultHospital();
      expect(h?['name'], 'General');
      expect(h?['phone'], '01555555555');
    });
  });

  group('loadContacts', () {
    test('returns an empty list on missing/garbage data (never seeds)',
        () async {
      SharedPreferences.setMockInitialValues({
        EmergencyContactsRepository.contactsKey: 'not valid json',
      });
      expect(await EmergencyContactsRepository.loadContacts(), isEmpty);
    });
  });
}
