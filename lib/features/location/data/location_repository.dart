import '../domain/models/booking_location.dart';

/// Data seam for the Location feature. [MockLocationRepository] is a
/// test-oriented in-memory stand-in; [FirestoreLocationRepository] is the
/// real implementation.
abstract class LocationRepository {
  Future<List<BookingLocation>> fetchSavedLocations();

  /// Persists a new saved location. [location.id] is ignored — Firestore
  /// assigns a real auto-generated document id, returned on the created
  /// [BookingLocation].
  Future<BookingLocation> addLocation(BookingLocation location);

  /// Updates the saved location at [location.id] in place — never creates a
  /// second document. Any field the caller didn't intend to touch should
  /// already be carried over on [location] (typically via `copyWith`-style
  /// construction upstream), since this always overwrites the full set of
  /// user-editable fields.
  Future<BookingLocation> updateLocation(BookingLocation location);

  Future<void> deleteLocation(String id);
}
