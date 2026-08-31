import '../domain/default_vehicle.dart';
import '../domain/models/vehicle.dart';
import '../domain/plate.dart';
import '../domain/vehicle_association.dart';
import 'cars_repository.dart';

/// Local/in-memory stand-in for a future Cars repository backed by
/// Firestore. Booking associations (used only for the delete-protection
/// rule) live here as mock state since Booking doesn't exist yet — never as
/// a field on [Vehicle] itself.
///
/// The artificial delay is only so the loading/skeleton states are visible
/// when running the app manually.
class MockCarsRepository implements CarsRepository {
  /// [seedVehicles] and [seedAssociations] default to the app's normal
  /// demo data; tests override them to exercise edge cases (an empty
  /// starting list, a vehicle with an active service, ...) against the
  /// real mock implementation instead of a parallel fake.
  MockCarsRepository({List<Vehicle>? seedVehicles, Map<String, VehicleAssociationStatus>? seedAssociations})
    : _vehicles = List.of(seedVehicles ?? _defaultVehicles),
      _associations = Map.of(seedAssociations ?? _defaultAssociations);

  static const _latency = Duration(milliseconds: 400);

  static const _defaultVehicles = [
    Vehicle(
      id: 'v1',
      make: 'Toyota',
      model: 'Camry',
      year: 2023,
      plateNumber: 'ABC 1234',
      imageAsset: 'vehicle_sedan',
      isDefault: true,
    ),
    Vehicle(
      id: 'v2',
      make: 'Hyundai',
      model: 'Tucson',
      year: 2024,
      plateNumber: 'XYZ 5678',
      imageAsset: 'vehicle_suv',
      isDefault: false,
    ),
  ];

  // v2 has an upcoming booking, so My Cars can demonstrate the delete
  // protection rule without a real Booking feature.
  static const _defaultAssociations = {'v1': VehicleAssociationStatus.none, 'v2': VehicleAssociationStatus.upcomingBooking};

  int _nextId = 3;
  final List<Vehicle> _vehicles;
  final Map<String, VehicleAssociationStatus> _associations;

  @override
  Future<List<Vehicle>> getVehicles() async {
    await Future.delayed(_latency);
    return List.unmodifiable(_vehicles);
  }

  @override
  Future<Vehicle> addVehicle({
    required String make,
    required String model,
    required int year,
    required String plateNumber,
  }) async {
    await Future.delayed(_latency);
    final vehicle = Vehicle(
      id: 'v${_nextId++}',
      make: make,
      model: model,
      year: year,
      plateNumber: normalizePlate(plateNumber),
      // No photo capture in this milestone — a plausible default visual.
      imageAsset: 'vehicle_sedan',
      isDefault: _vehicles.isEmpty,
    );
    _vehicles.add(vehicle);
    _associations[vehicle.id] = VehicleAssociationStatus.none;
    return vehicle;
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    await Future.delayed(_latency);
    final index = _vehicles.indexWhere((existing) => existing.id == vehicle.id);
    if (index == -1) {
      throw StateError('Vehicle ${vehicle.id} not found');
    }
    // Default status only ever changes via setDefaultVehicle.
    final updated = vehicle.copyWith(plateNumber: normalizePlate(vehicle.plateNumber), isDefault: _vehicles[index].isDefault);
    _vehicles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await Future.delayed(_latency);
    final status = _associations[id] ?? VehicleAssociationStatus.none;
    if (!canDeleteVehicle(status)) {
      throw const VehicleDeleteBlockedException();
    }
    _vehicles.removeWhere((vehicle) => vehicle.id == id);
    _associations.remove(id);

    final promoted = resolveDefaultAfterDeletion(_vehicles);
    if (promoted != null) {
      final index = _vehicles.indexWhere((vehicle) => vehicle.id == promoted.id);
      _vehicles[index] = promoted.copyWith(isDefault: true);
    }
  }

  @override
  Future<void> setDefaultVehicle(String id) async {
    await Future.delayed(_latency);
    for (var i = 0; i < _vehicles.length; i++) {
      _vehicles[i] = _vehicles[i].copyWith(isDefault: _vehicles[i].id == id);
    }
  }

  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) async {
    await Future.delayed(_latency);
    return _associations[vehicleId] ?? VehicleAssociationStatus.none;
  }
}
