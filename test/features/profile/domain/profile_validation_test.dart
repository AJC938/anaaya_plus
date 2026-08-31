import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/profile/domain/profile_validation.dart';

void main() {
  group('validateProfileForm', () {
    test('an empty full name is required', () {
      final errors = validateProfileForm(fullName: '', email: '');
      expect(errors.fullName, ProfileFieldError.required);
      expect(errors.isValid, isFalse);
    });

    test('a whitespace-only full name is treated as empty', () {
      final errors = validateProfileForm(fullName: '   ', email: '');
      expect(errors.fullName, ProfileFieldError.required);
    });

    test('a full name below the minimum length is too short', () {
      final errors = validateProfileForm(fullName: 'A', email: '');
      expect(errors.fullName, ProfileFieldError.tooShort);
    });

    test('a valid full name has no error', () {
      final errors = validateProfileForm(fullName: 'Faisal Al-Qahtani', email: '');
      expect(errors.fullName, isNull);
    });

    test('an empty email is valid — email is optional', () {
      final errors = validateProfileForm(fullName: 'Faisal', email: '');
      expect(errors.email, isNull);
      expect(errors.isValid, isTrue);
    });

    test('a malformed email is rejected', () {
      final errors = validateProfileForm(fullName: 'Faisal', email: 'not-an-email');
      expect(errors.email, ProfileFieldError.invalidEmail);
      expect(errors.isValid, isFalse);
    });

    test('a well-formed email has no error', () {
      final errors = validateProfileForm(fullName: 'Faisal', email: 'faisal@example.com');
      expect(errors.email, isNull);
    });

    test('both fields can be invalid at once', () {
      final errors = validateProfileForm(fullName: '', email: 'bad');
      expect(errors.fullName, ProfileFieldError.required);
      expect(errors.email, ProfileFieldError.invalidEmail);
    });
  });

  group('isValidEmail', () {
    test('accepts a plausible address', () => expect(isValidEmail('a.b@example.com'), isTrue));
    test('rejects text with no @', () => expect(isValidEmail('example.com'), isFalse));
    test('rejects text with no domain', () => expect(isValidEmail('a@b'), isFalse));
    test('rejects text with spaces', () => expect(isValidEmail('a b@example.com'), isFalse));
  });
}
