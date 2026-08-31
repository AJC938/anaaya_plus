import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/booking_location.dart';
import 'location_repository.dart';

/// Maps a `users/{uid}/locations/{locationId}` document's data onto
/// [BookingLocation]. Pulled out as a standalone function — rather than
/// inlined in [FirestoreLocationRepository] — so its null-handling is
/// unit-testable without a real or fake Firestore instance, matching
/// `vehicleFromFirestoreData`'s pattern for Cars.
///
/// [id] is always the Firestore document ID, never read from [data] — a
/// document can't carry an `id` field that overrides its own identity.
///
/// `isSimulatedCurrentLocation` is always `false` here: a saved Firestore
/// document is, by definition, never the mock "Current Location" entry —
/// that concept stays entirely local (see [FirestoreLocationRepository]'s
/// own doc comment) and is never written to or read from Firestore.
///
/// `createdAt` is deliberately not mapped onto anything — [BookingLocation]
/// has no such field. It exists in the stored document purely as
/// record-keeping (matching the approved schema), not as domain data.
BookingLocation locationFromFirestoreData(Map<String, dynamic>? data, {required String id}) {
  final labelAr = data?['labelAr'] as String?;
  final labelEn = data?['labelEn'] as String?;
  final cityAr = data?['cityAr'] as String?;
  final cityEn = data?['cityEn'] as String?;
  final districtAr = data?['districtAr'] as String?;
  final districtEn = data?['districtEn'] as String?;
  final coordinates = data?['coordinates'] as GeoPoint?;

  return BookingLocation(
    id: id,
    labelAr: labelAr ?? '',
    labelEn: labelEn ?? '',
    cityAr: cityAr ?? '',
    cityEn: cityEn ?? '',
    districtAr: districtAr ?? '',
    districtEn: districtEn ?? '',
    addressLineAr: data?['addressLineAr'] as String?,
    addressLineEn: data?['addressLineEn'] as String?,
    latitude: coordinates?.latitude ?? 0,
    longitude: coordinates?.longitude ?? 0,
    isSimulatedCurrentLocation: false,
  );
}

/// The inverse of [locationFromFirestoreData]: the user-editable fields
/// shared by create and update, as a plain Firestore field map. Pulled out
/// as a standalone function for the same reason as
/// [locationFromFirestoreData] — unit-testable without a real or fake
/// Firestore instance.
///
/// Deliberately excludes `createdAt` (each call site in
/// [FirestoreLocationRepository] decides whether to set it — `addLocation`
/// stamps it with `FieldValue.serverTimestamp()`, `updateLocation` leaves
/// it out entirely so Firestore's `.update()` never touches it, preserving
/// the original value) and never includes an `id` field — the Firestore
/// document ID is the only identity this schema uses (see
/// [locationFromFirestoreData]'s own doc comment); a stray `id` field
/// inside the document data would be meaningless and is never written.
Map<String, dynamic> locationToFirestoreFields(BookingLocation location) {
  return {
    'labelAr': location.labelAr,
    'labelEn': location.labelEn,
    'cityAr': location.cityAr,
    'cityEn': location.cityEn,
    'districtAr': location.districtAr,
    'districtEn': location.districtEn,
    'addressLineAr': location.addressLineAr,
    'addressLineEn': location.addressLineEn,
    'coordinates': GeoPoint(location.latitude, location.longitude),
  };
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Scopes every
/// saved location to the given [uid]'s `users/{uid}/locations/{locationId}`
/// subcollection — the Firestore document ID is the [BookingLocation.id];
/// no separate `id` field is ever stored.
///
/// The mock "Current Location (simulated)" entry is never read from or
/// written to this collection — it's a local-only concept (there is no
/// real GPS integration yet) that the presentation/provider layer
/// synthesizes and prepends to whatever this repository returns. This
/// repository only ever knows about the user's real saved locations.
class FirestoreLocationRepository implements LocationRepository {
  // `uid` is kept as the public parameter name — `this._uid` would make the
  // named parameter private and unusable from outside this library (see
  // FirestoreCarsRepository's `_uid` field for the same tradeoff).
  FirestoreLocationRepository({required String uid, FirebaseFirestore? firestore})
    // ignore: prefer_initializing_formals
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _locationsRef =>
      _firestore.collection('users').doc(_uid).collection('locations');

  @override
  Future<List<BookingLocation>> fetchSavedLocations() async {
    final snapshot = await _locationsRef.get();
    return [for (final doc in snapshot.docs) locationFromFirestoreData(doc.data(), id: doc.id)];
  }

  @override
  Future<BookingLocation> addLocation(BookingLocation location) async {
    final docRef = _locationsRef.doc();
    final data = locationToFirestoreFields(location)..['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    // locationFromFirestoreData never reads createdAt (see its own doc
    // comment), so the unresolved FieldValue sentinel in this local echo is
    // harmless — it's never looked at.
    return locationFromFirestoreData(data, id: docRef.id);
  }

  @override
  Future<BookingLocation> updateLocation(BookingLocation location) async {
    final docRef = _locationsRef.doc(location.id);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Location ${location.id} not found');
    }

    // createdAt is deliberately left out of this update — Firestore's
    // .update() only touches the fields present in the map, so the
    // document's original createdAt survives untouched, matching the
    // approved schema's "preserve createdAt on edit" requirement.
    await docRef.update(locationToFirestoreFields(location));

    final updated = await docRef.get();
    return locationFromFirestoreData(updated.data(), id: location.id);
  }

  @override
  Future<void> deleteLocation(String id) async {
    await _locationsRef.doc(id).delete();
  }
}
