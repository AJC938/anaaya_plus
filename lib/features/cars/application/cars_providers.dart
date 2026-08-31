import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/cars_repository.dart';
import '../data/firestore_cars_repository.dart';
import '../domain/models/vehicle.dart';
import '../domain/vehicle_association.dart';

/// Backed by the signed-in user's `users/{uid}/cars` subcollection — see
/// [FirestoreCarsRepository]. Depends on [authStateChangesProvider] (the
/// single source of truth for auth state), never a separately-tracked UID,
/// so this rebuilds automatically on sign-in and sign-out — same pattern as
/// `profileRepositoryProvider`.
///
/// No authenticated user (signed out, or auth still resolving) throws
/// rather than returning a placeholder repository — [CarsController] is an
/// [AsyncNotifier], so Riverpod catches this and surfaces it as the same
/// [AsyncError] state its screen already renders, matching every other
/// repository failure.
final carsRepositoryProvider = Provider<CarsRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;
  if (uid == null) {
    throw StateError('carsRepositoryProvider requires an authenticated user.');
  }
  return FirestoreCarsRepository(uid: uid);
});

/// The vehicle list plus its own mutations (add/update/delete/set-default) —
/// each mutation re-fetches so the list, default flags, and any dependent
/// UI stay consistent with the repository's own business rules
/// (first-vehicle-is-default, default-promotion-after-deletion, ...).
///
/// Mutations don't emit an intermediate [AsyncLoading] state: the screen
/// tracks its own per-action "busy" flag for CTA/card-level feedback, so
/// there's no need to flip the whole list to a loading state mid-mutation —
/// callers just keep seeing the previous data until the new data arrives.
class CarsController extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    // Waits for authStateChangesProvider's first emission before ever
    // reading carsRepositoryProvider — otherwise, on a fresh app launch,
    // Firebase Auth still restoring its session (uid not yet available) is
    // indistinguishable from a genuine sign-out, and carsRepositoryProvider
    // throws prematurely. `.future` resolves immediately if auth has
    // already settled (no meaningful delay), so this is always safe to
    // await unconditionally. Tests must provide a working
    // authRepositoryProvider override (even one that never emits) for this
    // reason — see FakeAuthRepository.
    await ref.watch(authStateChangesProvider.future);
    return ref.watch(carsRepositoryProvider).getVehicles();
  }

  Future<void> addVehicle({
    required String make,
    required String model,
    required int year,
    required String plateNumber,
  }) async {
    final repository = ref.read(carsRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.addVehicle(make: make, model: model, year: year, plateNumber: plateNumber);
      return repository.getVehicles();
    });
    _rethrowIfError();
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final repository = ref.read(carsRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.updateVehicle(vehicle);
      return repository.getVehicles();
    });
    _rethrowIfError();
  }

  /// Rethrows [VehicleDeleteBlockedException] without touching [state], so
  /// the caller can show the "can't delete" message rather than a generic
  /// failure.
  Future<void> deleteVehicle(String id) async {
    final repository = ref.read(carsRepositoryProvider);
    await repository.deleteVehicle(id);
    state = await AsyncValue.guard(repository.getVehicles);
    _rethrowIfError();
  }

  Future<void> setDefaultVehicle(String id) async {
    final repository = ref.read(carsRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.setDefaultVehicle(id);
      return repository.getVehicles();
    });
    _rethrowIfError();
  }

  /// [AsyncValue.guard] captures a failed mutation into [state] but doesn't
  /// propagate it to the caller — callers like the vehicle form rely on a
  /// thrown exception to know a save/update/set-default failed, so surface
  /// it here too rather than only updating state silently.
  void _rethrowIfError() {
    final current = state;
    if (current is AsyncError) {
      Error.throwWithStackTrace(current.error ?? current, current.stackTrace ?? StackTrace.current);
    }
  }
}

final carsControllerProvider = AsyncNotifierProvider<CarsController, List<Vehicle>>(CarsController.new);

/// Whether a specific vehicle can currently be deleted — the UI checks this
/// *before* opening the confirm dialog, so a blocked vehicle never shows a
/// confirmation it can't honor.
final vehicleAssociationProvider = FutureProvider.family<VehicleAssociationStatus, String>((ref, vehicleId) {
  return ref.watch(carsRepositoryProvider).fetchAssociationStatus(vehicleId);
});
