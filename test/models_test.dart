// Unit tests for the Safety Hub models extracted out of safety_hub_screen.dart,
// including the "exactly one default" SOS invariant.

import 'package:flutter_test/flutter_test.dart';

import 'package:amn_app/models/emergency_contact.dart';
import 'package:amn_app/models/hospital.dart';

void main() {
  group('EmergencyContact', () {
    test('toMap/fromMap round-trips (including the default flag)', () {
      const c = EmergencyContact(
        name: 'Mom',
        phone: '01000000000',
        relationship: 'Mother',
        isDefault: true,
      );
      final back = EmergencyContact.fromMap(c.toMap());
      expect(back.name, 'Mom');
      expect(back.phone, '01000000000');
      expect(back.relationship, 'Mother');
      expect(back.isDefault, isTrue);
    });

    test('fromMap tolerates missing fields', () {
      final c = EmergencyContact.fromMap({'phone': '011'});
      expect(c.name, '');
      expect(c.phone, '011');
      expect(c.isDefault, isFalse);
    });

    group('ensureSingleDefault', () {
      test('empty list is left untouched', () {
        final list = <EmergencyContact>[];
        EmergencyContact.ensureSingleDefault(list);
        expect(list, isEmpty);
      });

      test('promotes the first contact when none is flagged', () {
        final list = [
          const EmergencyContact(name: 'A', phone: '1', relationship: ''),
          const EmergencyContact(name: 'B', phone: '2', relationship: ''),
        ];
        EmergencyContact.ensureSingleDefault(list);
        expect(list[0].isDefault, isTrue);
        expect(list[1].isDefault, isFalse);
      });

      test('keeps only the first flagged default when several are set', () {
        final list = [
          const EmergencyContact(name: 'A', phone: '1', relationship: ''),
          const EmergencyContact(
            name: 'B',
            phone: '2',
            relationship: '',
            isDefault: true,
          ),
          const EmergencyContact(
            name: 'C',
            phone: '3',
            relationship: '',
            isDefault: true,
          ),
        ];
        EmergencyContact.ensureSingleDefault(list);
        expect(list[0].isDefault, isFalse);
        expect(list[1].isDefault, isTrue);
        expect(list[2].isDefault, isFalse);
        expect(list.where((c) => c.isDefault).length, 1);
      });
    });
  });

  group('Hospital', () {
    test('toMap/fromMap round-trips (including coordinates)', () {
      const h = Hospital(
        name: 'General',
        phone: '01555555555',
        address: 'Cairo',
        latitude: 30.1,
        longitude: 31.2,
        isDefault: true,
      );
      final back = Hospital.fromMap(h.toMap());
      expect(back.name, 'General');
      expect(back.address, 'Cairo');
      expect(back.latitude, 30.1);
      expect(back.longitude, 31.2);
      expect(back.isDefault, isTrue);
    });

    test('ensureSingleDefault keeps exactly one default', () {
      final list = [
        const Hospital(name: 'A', phone: '1', address: ''),
        const Hospital(name: 'B', phone: '2', address: '', isDefault: true),
        const Hospital(name: 'C', phone: '3', address: '', isDefault: true),
      ];
      Hospital.ensureSingleDefault(list);
      expect(list.where((h) => h.isDefault).length, 1);
      expect(list[1].isDefault, isTrue);
    });
  });
}
