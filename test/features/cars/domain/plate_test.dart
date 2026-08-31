import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/cars/domain/plate.dart';

void main() {
  group('normalizePlate', () {
    test('trims and collapses internal whitespace', () {
      expect(normalizePlate('  abc   1234  '), 'ABC 1234');
    });

    test('uppercases Latin letters', () {
      expect(normalizePlate('abc 1234'), 'ABC 1234');
    });
  });

  group('isValidPlate', () {
    test('rejects empty input', () {
      expect(isValidPlate(''), isFalse);
      expect(isValidPlate('   '), isFalse);
    });

    test('accepts a plausible Saudi-style plate', () {
      expect(isValidPlate('ABC 1234'), isTrue);
      expect(isValidPlate('abc 1234'), isTrue);
    });

    test('accepts Arabic-script plates', () {
      expect(isValidPlate('أ ب ج 1234'), isTrue);
    });

    test('rejects a plate with no digits', () {
      expect(isValidPlate('ABCDEFG'), isFalse);
    });

    test('rejects a plate with no letters', () {
      expect(isValidPlate('1234567'), isFalse);
    });

    test('rejects implausibly short or long input', () {
      expect(isValidPlate('A1'), isFalse);
      expect(isValidPlate('A1234567890123'), isFalse);
    });
  });
}
