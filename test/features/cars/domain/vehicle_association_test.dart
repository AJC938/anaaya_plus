import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/cars/domain/vehicle_association.dart';

void main() {
  test('a vehicle with no association can be deleted', () {
    expect(canDeleteVehicle(VehicleAssociationStatus.none), isTrue);
  });

  test('a vehicle with only historical activity can be deleted', () {
    expect(canDeleteVehicle(VehicleAssociationStatus.historicalOnly), isTrue);
  });

  test('an upcoming booking blocks deletion', () {
    expect(canDeleteVehicle(VehicleAssociationStatus.upcomingBooking), isFalse);
  });

  test('an active service blocks deletion', () {
    expect(canDeleteVehicle(VehicleAssociationStatus.activeService), isFalse);
  });
}
