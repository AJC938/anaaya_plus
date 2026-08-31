import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/firestore_location_repository.dart';
import '../data/location_repository.dart';
import '../domain/models/booking_location.dart';

/// Backed by the signed-in user's `users/{uid}/locations` subcollection —
/// see [FirestoreLocationRepository]. Depends on [authStateChangesProvider]
/// (the single source of truth for auth state), never a separately-tracked
/// UID, so this rebuilds automatically on sign-in and sign-out — same
/// pattern as `carsRepositoryProvider`/`bookingRepositoryProvider`.
///
/// No authenticated user (signed out, or auth still resolving) throws
/// rather than returning a placeholder repository, matching every other
/// repository provider in this app.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;
  if (uid == null) {
    throw StateError('locationRepositoryProvider requires an authenticated user.');
  }
  return FirestoreLocationRepository(uid: uid);
});

/// The saved-locations list plus its own mutations (add/update/delete) —
/// each mutation re-fetches so the list stays consistent with the
/// repository's own state, exactly matching `CarsController`'s pattern.
///
/// Real, per-account saved locations only — the old mock "Current Location"
/// entry never lives here (or anywhere as static data). The real
/// current-location flow (permission → GPS → reverse geocoding) is a
/// separate concern with its own provider — see
/// `application/current_location_controller.dart` — since it's an
/// on-demand device action, not something to fetch alongside the saved
/// list. `LocationScreen` deliberately never lets a failure here block that
/// one — see its own doc comment.
class SavedLocationsController extends AsyncNotifier<List<BookingLocation>> {
  @override
  Future<List<BookingLocation>> build() async {
    // Waits for authStateChangesProvider's first emission before ever
    // touching locationRepositoryProvider — otherwise, on a fresh app
    // launch, Firebase Auth still restoring its session (uid not yet
    // available) is indistinguishable from a genuine sign-out, and
    // locationRepositoryProvider throws prematurely. Same reasoning as
    // carsControllerProvider's own doc comment.
    await ref.watch(authStateChangesProvider.future);
    return ref.watch(locationRepositoryProvider).fetchSavedLocations();
  }

  /// Returns the newly created location (with its real Firestore document
  /// id) so a caller — e.g. the map picker's Save action — can immediately
  /// select it for the current booking without waiting for a second fetch.
  Future<BookingLocation> addLocation(BookingLocation location) async {
    final repository = ref.read(locationRepositoryProvider);
    late BookingLocation created;
    state = await AsyncValue.guard(() async {
      created = await repository.addLocation(location);
      return repository.fetchSavedLocations();
    });
    _rethrowIfError();
    return created;
  }

  Future<void> updateLocation(BookingLocation location) async {
    final repository = ref.read(locationRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repository.updateLocation(location);
      return repository.fetchSavedLocations();
    });
    _rethrowIfError();
  }

  /// [repository.deleteLocation] is called *outside* [AsyncValue.guard],
  /// unlike [addLocation]/[updateLocation] — a failed delete must never
  /// overwrite [state] with an error, or the whole saved-locations section
  /// would replace its list with a generic error, hiding every location
  /// including the one that just failed to delete. Only the refetch after a
  /// successful delete goes through the guard. Matches `CarsController
  /// .deleteVehicle`'s exact same reasoning.
  Future<void> deleteLocation(String id) async {
    final repository = ref.read(locationRepositoryProvider);
    await repository.deleteLocation(id);
    state = await AsyncValue.guard(repository.fetchSavedLocations);
    _rethrowIfError();
  }

  /// [AsyncValue.guard] captures a failed mutation into [state] but doesn't
  /// propagate it to the caller — callers like the map picker rely on a
  /// thrown exception to know a save/update/delete failed, so surface it
  /// here too rather than only updating state silently.
  void _rethrowIfError() {
    final current = state;
    if (current is AsyncError) {
      Error.throwWithStackTrace(current.error ?? current, current.stackTrace ?? StackTrace.current);
    }
  }
}

final savedLocationsControllerProvider = AsyncNotifierProvider<SavedLocationsController, List<BookingLocation>>(
  SavedLocationsController.new,
);
