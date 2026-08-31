import '../domain/models/vehicle.dart';
import '../domain/vehicle_association.dart';

/// Thrown by [CarsRepository.deleteVehicle] when the vehicle has an active
/// or upcoming association and can't be deleted — the repository's own
/// safety net on top of the UI's pre-check (see [canDeleteVehicle]).
class VehicleDeleteBlockedException implements Exception {
  const VehicleDeleteBlockedException();
}

/// Data seam for the Cars feature. [MockCarsRepository] is the only
/// implementation for this milestone; a Firebase-backed implementation can
/// replace it later without the Cars widgets or providers changing.
abstract class CarsRepository {
  Future<List<Vehicle>> getVehicles();

  Future<Vehicle> addVehicle({required String make, required String model, required int year, required String plateNumber});

  Future<Vehicle> updateVehicle(Vehicle vehicle);

  /// Throws [VehicleDeleteBlockedException] if [canDeleteVehicle] would
  /// reject this vehicle's current association status.
  Future<void> deleteVehicle(String id);

  Future<void> setDefaultVehicle(String id);

  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId);
}
