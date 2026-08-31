import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/cars/domain/default_vehicle.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';

Vehicle _vehicle(String id, {bool isDefault = false}) {
  return Vehicle(id: id, make: 'Toyota', model: 'Camry', year: 2023, plateNumber: 'ABC 1234', imageAsset: 'vehicle_sedan', isDefault: isDefault);
}

void main() {
  test('an empty list needs no promotion', () {
    expect(resolveDefaultAfterDeletion(const []), isNull);
  });

  test('no promotion needed when a default already exists among the remaining vehicles', () {
    final remaining = [_vehicle('v1', isDefault: true), _vehicle('v2')];
    expect(resolveDefaultAfterDeletion(remaining), isNull);
  });

  test('promotes the first remaining vehicle when the deleted one was the default', () {
    final remaining = [_vehicle('v2'), _vehicle('v3')];
    final promoted = resolveDefaultAfterDeletion(remaining);
    expect(promoted?.id, 'v2');
  });
}
