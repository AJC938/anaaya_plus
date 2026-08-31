import 'package:anaaya_plus/features/cars/data/firestore_cars_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('vehicleFromFirestoreData', () {
    const id = 'car-123';

    test('maps a fully populated document', () {
      final vehicle = vehicleFromFirestoreData({
        'make': 'Toyota',
        'model': 'Camry',
        'year': 2023,
        'plateNumber': 'ABC 1234',
        'imageAsset': 'vehicle_sedan',
        'isDefault': true,
      }, id: id);

      expect(vehicle.id, id);
      expect(vehicle.make, 'Toyota');
      expect(vehicle.model, 'Camry');
      expect(vehicle.year, 2023);
      expect(vehicle.plateNumber, 'ABC 1234');
      expect(vehicle.imageAsset, 'vehicle_sedan');
      expect(vehicle.isDefault, isTrue);
    });

    test('a document with all fields null falls back safely, without crashing', () {
      final vehicle = vehicleFromFirestoreData({
        'make': null,
        'model': null,
        'year': null,
        'plateNumber': null,
        'imageAsset': null,
        'isDefault': null,
      }, id: id);

      expect(vehicle.make, '');
      expect(vehicle.model, '');
      expect(vehicle.year, 0);
      expect(vehicle.plateNumber, '');
      expect(vehicle.imageAsset, 'vehicle_sedan');
      expect(vehicle.isDefault, isFalse);
    });

    test('a partially populated document falls back only for the missing fields', () {
      final vehicle = vehicleFromFirestoreData({'make': 'Hyundai', 'model': 'Tucson'}, id: id);

      expect(vehicle.make, 'Hyundai');
      expect(vehicle.model, 'Tucson');
      expect(vehicle.year, 0);
      expect(vehicle.plateNumber, '');
      expect(vehicle.imageAsset, 'vehicle_sedan');
      expect(vehicle.isDefault, isFalse);
    });

    test('missing document data (null map) does not crash', () {
      final vehicle = vehicleFromFirestoreData(null, id: id);

      expect(vehicle.id, id);
      expect(vehicle.make, '');
      expect(vehicle.model, '');
      expect(vehicle.year, 0);
      expect(vehicle.plateNumber, '');
      expect(vehicle.imageAsset, 'vehicle_sedan');
      expect(vehicle.isDefault, isFalse);
    });

    test('always uses the id passed in as Vehicle.id', () {
      final vehicle = vehicleFromFirestoreData({'make': 'Kia', 'model': 'Sportage'}, id: id);

      expect(vehicle.id, id);
    });

    test('data cannot override the document id, even if it contains an "id" field', () {
      final vehicle = vehicleFromFirestoreData({'id': 'someone-elses-id', 'make': 'Kia', 'model': 'Sportage'}, id: id);

      expect(vehicle.id, id);
      expect(vehicle.id, isNot('someone-elses-id'));
    });

    test('year stored as a double (possible Firestore numeric representation) is truncated to int', () {
      final vehicle = vehicleFromFirestoreData({'year': 2023.0}, id: id);

      expect(vehicle.year, 2023);
    });
  });
}
