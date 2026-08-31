import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/domain/phone_number_validation.dart';

void main() {
  group('isValidSaudiLocalNumber', () {
    test('accepts a 9-digit number starting with 5', () {
      expect(isValidSaudiLocalNumber('512345678'), isTrue);
    });

    test('accepts the same number with a leading domestic 0', () {
      expect(isValidSaudiLocalNumber('0512345678'), isTrue);
    });

    test('rejects a number that does not start with 5', () {
      expect(isValidSaudiLocalNumber('412345678'), isFalse);
    });

    test('rejects a number that is too short', () {
      expect(isValidSaudiLocalNumber('51234567'), isFalse);
    });

    test('rejects a number that is too long', () {
      expect(isValidSaudiLocalNumber('5123456789'), isFalse);
    });

    test('rejects non-digit input', () {
      expect(isValidSaudiLocalNumber('51234abcd'), isFalse);
    });

    test('rejects an empty string', () {
      expect(isValidSaudiLocalNumber(''), isFalse);
    });
  });

  group('normalizeSaudiLocalNumber', () {
    test('strips a leading domestic 0', () {
      expect(normalizeSaudiLocalNumber('0512345678'), '512345678');
    });

    test('strips non-digit separators', () {
      expect(normalizeSaudiLocalNumber('51 234 5678'), '512345678');
    });

    test('leaves an already-normalized number unchanged', () {
      expect(normalizeSaudiLocalNumber('512345678'), '512345678');
    });
  });

  group('toSaudiE164', () {
    test('produces the full E.164 number Firebase expects', () {
      expect(toSaudiE164('512345678'), '+966512345678');
    });

    test('normalizes a leading 0 before prefixing', () {
      expect(toSaudiE164('0512345678'), '+966512345678');
    });
  });
}
