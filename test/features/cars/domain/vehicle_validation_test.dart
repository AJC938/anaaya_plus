import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/cars/domain/vehicle_validation.dart';

void main() {
  group('isValidYear', () {
    test('accepts a recent model year', () {
      expect(isValidYear(2023), isTrue);
    });

    test('accepts next year (upcoming model year)', () {
      expect(isValidYear(DateTime.now().year + 1), isTrue);
    });

    test('rejects years before 1980', () {
      expect(isValidYear(1975), isFalse);
    });

    test('rejects years further than one year in the future', () {
      expect(isValidYear(DateTime.now().year + 5), isFalse);
    });
  });

  group('validateVehicleForm', () {
    test('a fully valid form has no errors', () {
      final errors = validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: '2023', plateNumber: 'ABC 1234');
      expect(errors.isValid, isTrue);
    });

    test('missing make and model are flagged as required', () {
      final errors = validateVehicleForm(make: null, model: null, yearText: '2023', plateNumber: 'ABC 1234');
      expect(errors.make, VehicleFieldError.required);
      expect(errors.model, VehicleFieldError.required);
      expect(errors.isValid, isFalse);
    });

    test('empty year is required, non-numeric or out-of-range year is invalid', () {
      expect(
        validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: '', plateNumber: 'ABC 1234').year,
        VehicleFieldError.required,
      );
      expect(
        validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: 'abcd', plateNumber: 'ABC 1234').year,
        VehicleFieldError.invalidYear,
      );
      expect(
        validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: '1900', plateNumber: 'ABC 1234').year,
        VehicleFieldError.invalidYear,
      );
    });

    test('empty plate is required, malformed plate is invalid', () {
      expect(
        validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: '2023', plateNumber: '').plateNumber,
        VehicleFieldError.required,
      );
      expect(
        validateVehicleForm(make: 'Toyota', model: 'Camry', yearText: '2023', plateNumber: '1234567').plateNumber,
        VehicleFieldError.invalidPlate,
      );
    });
  });
}
