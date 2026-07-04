// Locks in the Egypt emergency numbers so a stray edit can't silently change
// which number the SOS / voice / Safety Hub paths dial.

import 'package:flutter_test/flutter_test.dart';

import 'package:amn_app/utils/emergency_numbers.dart';

void main() {
  group('EmergencyNumbers', () {
    test('Egypt service numbers are correct', () {
      expect(EmergencyNumbers.police, '122');
      expect(EmergencyNumbers.ambulance, '123');
      expect(EmergencyNumbers.fire, '180');
      expect(EmergencyNumbers.traffic, '128');
    });
  });
}
