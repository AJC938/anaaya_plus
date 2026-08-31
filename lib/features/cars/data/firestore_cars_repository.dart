import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/default_vehicle.dart';
import '../domain/models/vehicle.dart';
import '../domain/plate.dart';
import '../domain/vehicle_association.dart';
import 'cars_repository.dart';

/// Maps a `users/{uid}/cars/{carId}` document's data onto [Vehicle]. Pulled
/// out as a standalone function — rather than inlined in
/// [FirestoreCarsRepository] — so its null-handling is unit-testable
/// without a real or fake Firestore instance, matching
/// `customerProfileFromFirestoreData`'s pattern for Profile.
///
/// [id] is always the Firestore document ID, never read from [data] — a
/// document can't carry an `id` field that overrides its own identity.
Vehicle vehicleFromFirestoreData(Map<String, dynamic>? data, {required String id}) {
  final make = data?['make'] as String?;
  final model = data?['model'] as String?;
  final year = (data?['year'] as num?)?.toInt();
  final plateNumber = data?['plateNumber'] as String?;
  final imageAsset = data?['imageAsset'] as String?;
  final isDefault = data?['isDefault'] as bool?;

  return Vehicle(
    id: id,
    make: make ?? '',
    model: model ?? '',
    year: year ?? 0,
    plateNumber: plateNumber ?? '',
    // Matches MockCarsRepository's own default for a vehicle with no
    // captured photo.
    imageAsset: imageAsset ?? 'vehicle_sedan',
    isDefault: isDefault ?? false,
  );
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Scopes every
/// vehicle to the given [uid]'s `users/{uid}/cars/{carId}` subcollection —
/// the Firestore document ID is the [Vehicle.id]; no separate `id` field is
/// ever stored.
///
/// [VehicleAssociationStatus] has no Firestore-backed source yet — see
/// [fetchAssociationStatus]. That integration (Booking-derived
/// upcoming-booking/active-service status) is explicitly out of scope for
/// this step and is tracked separately.
class FirestoreCarsRepository implements CarsRepository {
  // `uid` is kept as the public parameter name — `this._uid` would make the
  // named parameter private and unusable from outside this library (see
  // FirestoreProfileRepository's `_uid` field for the same tradeoff).
  FirestoreCarsRepository({required String uid, FirebaseFirestore? firestore})
    // ignore: prefer_initializing_formals
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _carsRef => _firestore.collection('users').doc(_uid).collection('cars');

  @override
  Future<List<Vehicle>> getVehicles() async {
    final snapshot = await _carsRef.get();
    return [for (final doc in snapshot.docs) vehicleFromFirestoreData(doc.data(), id: doc.id)];
  }

  @override
  Future<Vehicle> addVehicle({
    required String make,
    required String model,
    required int year,
    required String plateNumber,
  }) async {
    // Matches MockCarsRepository: the first vehicle a user adds becomes
    // their default automatically.
    final existing = await _carsRef.limit(1).get();
    final isFirstVehicle = existing.docs.isEmpty;

    final docRef = _carsRef.doc();
    final data = {
      'make': make,
      'model': model,
      'year': year,
      'plateNumber': normalizePlate(plateNumber),
      // No photo capture in this milestone — matches MockCarsRepository's
      // same plausible default visual.
      'imageAsset': 'vehicle_sedan',
      'isDefault': isFirstVehicle,
    };
    await docRef.set(data);
    return vehicleFromFirestoreData(data, id: docRef.id);
  }

  @override
  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final docRef = _carsRef.doc(vehicle.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Vehicle ${vehicle.id} not found');
    }

    // Default status only ever changes via setDefaultVehicle, and
    // imageAsset is immutable after creation (no photo-editing UI exists)
    // — neither is touched here, matching MockCarsRepository's exact
    // contract.
    await docRef.update({
      'make': vehicle.make,
      'model': vehicle.model,
      'year': vehicle.year,
      'plateNumber': normalizePlate(vehicle.plateNumber),
    });

    final updated = await docRef.get();
    return vehicleFromFirestoreData(updated.data(), id: vehicle.id);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    final status = await fetchAssociationStatus(id);
    if (!canDeleteVehicle(status)) {
      throw const VehicleDeleteBlockedException();
    }

    await _carsRef.doc(id).delete();

    final remaining = await getVehicles();
    final promoted = resolveDefaultAfterDeletion(remaining);
    if (promoted != null) {
      await _carsRef.doc(promoted.id).update({'isDefault': true});
    }
  }

  @override
  Future<void> setDefaultVehicle(String id) async {
    final snapshot = await _carsRef.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == id});
    }
    await batch.commit();
  }

  /// Always [VehicleAssociationStatus.none] — there is no Firestore-backed
  /// source for Booking association data yet, so this never blocks a
  /// deletion. Deliberately not solved in this step (see the class-level
  /// doc comment); the delete-protection *code path* itself (the
  /// [canDeleteVehicle] check in [deleteVehicle]) is preserved so wiring in
  /// a real status later needs no structural change here.
  @override
  Future<VehicleAssociationStatus> fetchAssociationStatus(String vehicleId) async {
    return VehicleAssociationStatus.none;
  }
}
