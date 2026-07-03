// Unit tests for the password validator used by the sign-up / reset flows.
//
// The previous file here was the default Flutter counter template, which
// referenced widgets that do not exist in this app, so `flutter test` failed.
// These are real, fast, dependency-free tests of the validation rules.

import 'package:flutter_test/flutter_test.dart';

import 'package:amn_app/services/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    test('accepts a strong password', () {
      expect(PasswordValidator.validate('Str0ng!Pass').isValid, isTrue);
    });

    test('rejects null or empty', () {
      expect(PasswordValidator.validate(null).isValid, isFalse);
      expect(PasswordValidator.validate('').isValid, isFalse);
    });

    test('rejects too-short passwords', () {
      expect(PasswordValidator.validate('Ab1!c').isValid, isFalse);
    });

    test('rejects common weak passwords', () {
      expect(PasswordValidator.validate('password').isValid, isFalse);
      expect(PasswordValidator.validate('12345678').isValid, isFalse);
    });

    test('requires an uppercase letter', () {
      expect(PasswordValidator.validate('str0ng!pass').isValid, isFalse);
    });

    test('requires a lowercase letter', () {
      expect(PasswordValidator.validate('STR0NG!PASS').isValid, isFalse);
    });

    test('requires a digit', () {
      expect(PasswordValidator.validate('Strong!Pass').isValid, isFalse);
    });

    test('requires a special character', () {
      expect(PasswordValidator.validate('Str0ngPass').isValid, isFalse);
    });
  });
}
