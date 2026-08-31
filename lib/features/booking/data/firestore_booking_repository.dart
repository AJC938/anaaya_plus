import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../cars/data/cars_repository.dart';
import '../../cars/domain/models/vehicle.dart';
import '../../location/domain/models/booking_location.dart';
import '../../scheduling/data/firestore_scheduling_repository.dart' show scheduleSlotDocumentId, slotClaimFields;
import '../../services/data/services_repository.dart';
import '../../services/domain/models/service_option.dart';
import '../domain/booking_reference.dart';
import '../domain/booking_status_transition.dart';
import '../domain/models/booking.dart';
import '../domain/models/booking_draft.dart';
import '../domain/models/booking_price_breakdown.dart';
import '../domain/pricing.dart';
import 'booking_repository.dart';

/// Maps a `users/{uid}/bookings/{bookingId}` document's data onto [Booking].
/// Pulled out as a standalone function — rather than inlined in
/// [FirestoreBookingRepository] — so its null-handling is unit-testable
/// without a real or fake Firestore instance, matching
/// `customerProfileFromFirestoreData`/`vehicleFromFirestoreData`'s pattern.
///
/// Unlike those two, there is no external `id` parameter here: per the
/// approved schema, the Firestore *document* ID is an opaque auto-ID with
/// no meaning to the app — [Booking.id] is, and has always been (see
/// [MockBookingRepository]), the human-readable `bookingReference`, which
/// is a genuine stored field, not a duplicate of document identity. This
/// function only ever reads it from `data['bookingReference']`; it has no
/// way to substitute the Firestore document ID in its place.
Booking bookingFromFirestoreData(Map<String, dynamic>? data) {
  final bookingReference = data?['bookingReference'] as String?;

  final serviceSnapshot = data?['serviceSnapshot'] as Map<String, dynamic>?;
  final serviceOptionSnapshot = data?['serviceOptionSnapshot'] as Map<String, dynamic>?;
  final vehicleSnapshot = data?['vehicleSnapshot'] as Map<String, dynamic>?;
  final locationData = data?['location'] as Map<String, dynamic>?;
  final priceData = data?['price'] as Map<String, dynamic>?;

  final coordinates = locationData?['coordinates'] as GeoPoint?;
  // The stored snapshot keeps only one locale's text (the locale active at
  // booking time — see FirestoreBookingRepository.createBooking) — the same
  // pre-existing limitation MockBookingRepository already has for
  // serviceName/vehicleName, just now applying to location too, since
  // BookingLocation requires both language variants to construct. Both
  // slots are filled with the same stored string rather than leaving one
  // fabricated or blank.
  final locationLabel = locationData?['label'] as String? ?? '';
  final locationCity = locationData?['city'] as String? ?? '';
  final locationDistrict = locationData?['district'] as String? ?? '';
  final locationAddressLine = locationData?['addressLine'] as String?;

  final scheduledAtTimestamp = data?['scheduledAt'] as Timestamp?;
  final estimatedArrivalTimestamp = data?['estimatedArrival'] as Timestamp?;
  final createdAtTimestamp = data?['createdAt'] as Timestamp?;

  final statusName = data?['status'] as String?;
  final status = BookingStatus.values.firstWhere(
    (candidate) => candidate.name == statusName,
    // No "unknown" status exists on the enum — falling back to `upcoming`
    // is the least surprising choice for data that doesn't match any known
    // value (corruption, or a status added by a later app version).
    orElse: () => BookingStatus.upcoming,
  );

  return Booking(
    id: bookingReference ?? '',
    serviceId: data?['serviceId'] as String? ?? '',
    serviceName: serviceSnapshot?['name'] as String? ?? '',
    serviceImageAsset: serviceSnapshot?['imageAsset'] as String? ?? '',
    serviceOptionId: data?['serviceOptionId'] as String?,
    serviceOptionName: serviceOptionSnapshot?['name'] as String?,
    vehicleId: data?['vehicleId'] as String? ?? '',
    vehicleName: vehicleSnapshot?['name'] as String? ?? '',
    vehicleYear: (vehicleSnapshot?['year'] as num?)?.toInt() ?? 0,
    plateNumber: vehicleSnapshot?['plateNumber'] as String? ?? '',
    location: BookingLocation(
      id: '',
      labelAr: locationLabel,
      labelEn: locationLabel,
      cityAr: locationCity,
      cityEn: locationCity,
      districtAr: locationDistrict,
      districtEn: locationDistrict,
      addressLineAr: locationAddressLine,
      addressLineEn: locationAddressLine,
      latitude: coordinates?.latitude ?? 0,
      longitude: coordinates?.longitude ?? 0,
      isSimulatedCurrentLocation: locationData?['isSimulatedCurrentLocation'] as bool? ?? false,
    ),
    scheduledAt: scheduledAtTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    price: BookingPriceBreakdown(
      basePrice: (priceData?['basePrice'] as num?)?.toDouble() ?? 0,
      optionPrice: (priceData?['optionPrice'] as num?)?.toDouble() ?? 0,
      fees: (priceData?['fees'] as num?)?.toDouble() ?? 0,
      total: (priceData?['total'] as num?)?.toDouble() ?? 0,
    ),
    status: status,
    estimatedArrival: estimatedArrivalTimestamp?.toDate(),
    createdAt: createdAtTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// The lifecycle has no real technician dispatch/GPS behind it in this
/// milestone — [BookingStatus.technicianOnTheWay] populates the already-
/// existing `estimatedArrival` field with a fixed, simulated offset from
/// [now] (defaults to the real current time), matching the shape
/// `MockBookingRepository`'s own on-the-way demo booking already uses,
/// rather than leaving Tracking's existing ETA countdown pointed at
/// nothing. Every other transition only ever touches `status` — pulled out
/// as a standalone function, rather than inlined in
/// [FirestoreBookingRepository.updateBookingStatus], so this shape is
/// unit-testable without a real or fake Firestore instance, matching
/// `slotClaimFields`'s pattern. Deliberately excludes `statusUpdatedAt` —
/// the caller always stamps that with `FieldValue.serverTimestamp()`
/// separately, the same way `slotClaimFields` excludes `claimedAt`.
const _simulatedTechnicianEta = Duration(minutes: 15);

Map<String, dynamic> bookingStatusUpdateFields(BookingStatus newStatus, {DateTime? now}) {
  final fields = <String, dynamic>{'status': newStatus.name};
  if (newStatus == BookingStatus.technicianOnTheWay) {
    fields['estimatedArrival'] = Timestamp.fromDate((now ?? DateTime.now()).add(_simulatedTechnicianEta));
  }
  return fields;
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Scopes every
/// booking to the given [uid]'s `users/{uid}/bookings/{bookingId}`
/// subcollection — Firestore's auto-generated document ID is opaque and
/// never surfaced to the app; [Booking.id] (the `bookingReference` field,
/// e.g. "AN-20481") is what the UI actually displays and navigates with.
///
/// Mirrors [MockBookingRepository]'s resolution role — Booking is the top
/// of the dependency chain (`Cars -> Booking`, `Services -> Booking`), so
/// [createBooking] still resolves the draft's ids into real snapshots via
/// the injected Services/Cars repositories; only the persistence target
/// (Firestore instead of an in-memory map) changes.
///
/// Slot availability is no longer revalidated via a separate, non-atomic
/// read (a [SchedulingRepository] dependency is deliberately no longer
/// injected here) — [createBooking] instead atomically claims the slot
/// itself as part of the same Firestore transaction that writes the
/// booking document. See [createBooking]'s own doc comment.
class FirestoreBookingRepository implements BookingRepository {
  // `uid` is kept as the public parameter name — `this._uid` would make the
  // named parameter private and unusable from outside this library (see
  // FirestoreCarsRepository/FirestoreProfileRepository's `_uid` field for
  // the same tradeoff).
  FirestoreBookingRepository({
    required String uid,
    required this.servicesRepository,
    required this.carsRepository,
    FirebaseFirestore? firestore,
    // ignore: prefer_initializing_formals
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;
  final ServicesRepository servicesRepository;
  final CarsRepository carsRepository;

  CollectionReference<Map<String, dynamic>> get _bookingsRef =>
      _firestore.collection('users').doc(_uid).collection('bookings');

  CollectionReference<Map<String, dynamic>> get _slotsRef => _firestore.collection('serviceSlots');

  /// Resolves the draft's ids into real snapshots, then atomically claims
  /// the requested slot AND writes the booking document in a single
  /// Firestore transaction — either both happen or neither does, so a
  /// booking can never exist for a slot that wasn't (or couldn't be)
  /// claimed, and two concurrent attempts at the same slot (two users, the
  /// same user twice, two devices, a rapid repeated tap) can never both
  /// succeed: [scheduleSlotDocumentId] is deterministic, so both attempts
  /// target the exact same document, and Firestore only ever lets one
  /// transaction win a create on a given document — the loser's
  /// `transaction.get` sees the winner's document already exists (Firestore
  /// automatically retries a transaction that reads data changed by a
  /// concurrent commit) and this throws [BookingSlotUnavailableException]
  /// before any write of its own is applied.
  @override
  Future<Booking> createBooking(BookingDraft draft, Locale locale) async {
    final location = draft.location;
    final date = draft.date;
    final timeSlot = draft.timeSlot;
    if (location == null || date == null || timeSlot == null) {
      throw StateError('createBooking called with an incomplete draft');
    }

    final service = await servicesRepository.fetchServiceById(draft.serviceId);
    if (service == null) {
      throw StateError('Service ${draft.serviceId} not found');
    }

    final vehicles = await carsRepository.getVehicles();
    Vehicle? vehicle;
    for (final candidate in vehicles) {
      if (candidate.id == draft.vehicleId) {
        vehicle = candidate;
        break;
      }
    }
    if (vehicle == null) {
      throw StateError('Vehicle ${draft.vehicleId} not found');
    }

    ServiceOption? option;
    if (draft.serviceOptionId != null) {
      final options = await servicesRepository.fetchOptions(draft.serviceId);
      for (final candidate in options) {
        if (candidate.id == draft.serviceOptionId) {
          option = candidate;
          break;
        }
      }
    }

    final price = calculateBookingPrice(basePrice: service.startingPrice, optionPrice: option?.price ?? 0);
    final bookingReference = generateBookingReference();
    // The returned Booking's createdAt is a local timestamp captured here
    // (matching MockBookingRepository's own DateTime.now() behavior) — the
    // stored document's createdAt is the authoritative server-resolved
    // value (see below), which isn't available client-side until a
    // subsequent read.
    final createdAt = DateTime.now();

    final data = {
      'bookingReference': bookingReference,
      'serviceId': service.id,
      'serviceOptionId': option?.id,
      'serviceSnapshot': {'name': service.name(locale), 'imageAsset': service.imageAsset},
      'serviceOptionSnapshot': option == null ? null : {'name': option.name(locale), 'imageAsset': option.imageAsset},
      'vehicleId': vehicle.id,
      'vehicleSnapshot': {'name': vehicle.displayName, 'year': vehicle.year, 'plateNumber': vehicle.plateNumber},
      'location': {
        'label': location.label(locale),
        'city': location.city(locale),
        'district': location.district(locale),
        'addressLine': location.addressLine(locale),
        'coordinates': GeoPoint(location.latitude, location.longitude),
        'isSimulatedCurrentLocation': location.isSimulatedCurrentLocation,
      },
      'scheduledAt': Timestamp.fromDate(timeSlot.start),
      'estimatedArrival': null,
      'price': {'basePrice': price.basePrice, 'optionPrice': price.optionPrice, 'fees': price.fees, 'total': price.total},
      'status': BookingStatus.upcoming.name,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final bookingDocRef = _bookingsRef.doc();
    final slotRef = _slotsRef.doc(scheduleSlotDocumentId(serviceId: draft.serviceId, scheduledAt: timeSlot.start));

    await _firestore.runTransaction((transaction) async {
      // All reads before all writes — a Firestore transaction requirement.
      final slotSnapshot = await transaction.get(slotRef);
      if (slotSnapshot.exists) {
        throw const BookingSlotUnavailableException();
      }

      final claimData = {
        ...slotClaimFields(
          serviceId: draft.serviceId,
          scheduledAt: timeSlot.start,
          claimedByUid: _uid,
          bookingReference: bookingReference,
        ),
        'claimedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(slotRef, claimData);
      transaction.set(bookingDocRef, data);
    });

    return Booking(
      id: bookingReference,
      serviceId: service.id,
      serviceName: service.name(locale),
      serviceImageAsset: service.imageAsset,
      serviceOptionId: option?.id,
      serviceOptionName: option?.name(locale),
      vehicleId: vehicle.id,
      vehicleName: vehicle.displayName,
      vehicleYear: vehicle.year,
      plateNumber: vehicle.plateNumber,
      location: location,
      scheduledAt: timeSlot.start,
      price: price,
      status: BookingStatus.upcoming,
      createdAt: createdAt,
    );
  }

  @override
  Future<Booking?> fetchBookingById(String id, Locale locale) async {
    // `id` is the bookingReference, not the Firestore document ID — see
    // this class's doc comment.
    final snapshot = await _bookingsRef.where('bookingReference', isEqualTo: id).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return bookingFromFirestoreData(snapshot.docs.first.data());
  }

  @override
  Future<List<Booking>> getBookings(Locale locale) async {
    final snapshot = await _bookingsRef.get();
    return [for (final doc in snapshot.docs) bookingFromFirestoreData(doc.data())];
  }

  /// Ownership is enforced structurally: [_bookingsRef] is already scoped
  /// to this repository's own [_uid], so there is no separate "does this
  /// user own this booking" check to perform — the query below can only
  /// ever find documents inside this user's own subcollection.
  ///
  /// The transition itself is validated twice, deliberately: here (so a
  /// rejected request fails fast with a clear, typed exception before any
  /// network write), and again in firestore.rules using the exact same
  /// `bookingStatusTransitions` edges (so a client can never bypass the
  /// Dart-side check and write an illegal transition directly). Wrapped in
  /// a transaction so the read-current-status-then-write step is atomic —
  /// the same reasoning as the slot claim in [createBooking].
  @override
  Future<Booking> updateBookingStatus({required String bookingReference, required BookingStatus newStatus}) async {
    final snapshot = await _bookingsRef.where('bookingReference', isEqualTo: bookingReference).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Booking $bookingReference not found');
    }
    final docRef = snapshot.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(docRef);
      final currentStatusName = current.data()?['status'] as String?;
      final currentStatus = BookingStatus.values.firstWhere(
        (candidate) => candidate.name == currentStatusName,
        orElse: () => BookingStatus.upcoming,
      );

      if (!isValidBookingStatusTransition(from: currentStatus, to: newStatus)) {
        throw InvalidBookingStatusTransitionException(from: currentStatus, to: newStatus);
      }

      transaction.update(docRef, {...bookingStatusUpdateFields(newStatus), 'statusUpdatedAt': FieldValue.serverTimestamp()});
    });

    final updated = await docRef.get();
    return bookingFromFirestoreData(updated.data());
  }

  /// Whether the `serviceSlots` claim found for a booking being cancelled is
  /// actually safe to delete. Pulled out as a standalone pure function —
  /// rather than inlined in [cancelBooking] — so all three cases (claim
  /// belongs to this booking, claim belongs to a different booking, no
  /// claim was found at all) are unit-testable without a real or fake
  /// Firestore instance, matching [bookingStatusUpdateFields]/
  /// [slotClaimFields]'s own pattern. Never a blind delete-by-id: a mismatch
  /// or a missing claim both return `false`, leaving the slot untouched.
  static bool shouldReleaseSlot({required String bookingReference, required bool slotExists, required String? slotBookingReference}) {
    return slotExists && slotBookingReference == bookingReference;
  }

  /// Reconstructs the exact `serviceSlots` document this booking claimed at
  /// creation time from its own stored `serviceId`/`scheduledAt` fields —
  /// the same two inputs [scheduleSlotDocumentId] was given inside
  /// [createBooking]'s transaction, so this always resolves to the same
  /// document, with no separate slot-id bookkeeping required.
  ///
  /// Never a blind delete: the claim is only released if it still exists
  /// AND its own stored `bookingReference` matches this booking. Slot
  /// claiming is atomic and exclusive (a claim's mere existence blocks every
  /// other attempt at the same document), so in the normal case this can
  /// only ever be this booking's own claim — the check is defense-in-depth
  /// against ever deleting a claim that isn't provably this booking's,
  /// rather than trusting the reconstructed id alone. If the claim is
  /// missing or doesn't match, cancellation still proceeds (the booking's
  /// own lifecycle status is authoritative on its own) but the slot is left
  /// untouched rather than guessed at.
  ///
  /// Wrapped in the exact same transaction as the status write for the same
  /// reason [updateBookingStatus] validates inside its own transaction: a
  /// concurrent transition on another device (e.g. to technicianOnTheWay)
  /// must never be silently overwritten by a stale cancellation — Firestore
  /// retries this whole callback on a conflicting concurrent write, so the
  /// status re-read on retry is always the latest one.
  @override
  Future<Booking> cancelBooking({required String bookingReference}) async {
    final snapshot = await _bookingsRef.where('bookingReference', isEqualTo: bookingReference).limit(1).get();
    if (snapshot.docs.isEmpty) {
      throw StateError('Booking $bookingReference not found');
    }
    final docRef = snapshot.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      // All reads before all writes — a Firestore transaction requirement.
      final current = await transaction.get(docRef);
      final currentStatusName = current.data()?['status'] as String?;
      final currentStatus = BookingStatus.values.firstWhere(
        (candidate) => candidate.name == currentStatusName,
        orElse: () => BookingStatus.upcoming,
      );

      if (!isValidBookingStatusTransition(from: currentStatus, to: BookingStatus.cancelled)) {
        throw InvalidBookingStatusTransitionException(from: currentStatus, to: BookingStatus.cancelled);
      }

      final serviceId = current.data()?['serviceId'] as String?;
      final scheduledAtTimestamp = current.data()?['scheduledAt'] as Timestamp?;
      DocumentReference<Map<String, dynamic>>? slotRef;
      DocumentSnapshot<Map<String, dynamic>>? slotSnapshot;
      if (serviceId != null && scheduledAtTimestamp != null) {
        slotRef = _slotsRef.doc(scheduleSlotDocumentId(serviceId: serviceId, scheduledAt: scheduledAtTimestamp.toDate()));
        slotSnapshot = await transaction.get(slotRef);
      }

      transaction.update(docRef, {'status': BookingStatus.cancelled.name, 'statusUpdatedAt': FieldValue.serverTimestamp()});

      final shouldRelease = shouldReleaseSlot(
        bookingReference: bookingReference,
        slotExists: slotSnapshot?.exists ?? false,
        slotBookingReference: slotSnapshot?.data()?['bookingReference'] as String?,
      );
      if (slotRef != null && shouldRelease) {
        transaction.delete(slotRef);
      }
    });

    final updated = await docRef.get();
    return bookingFromFirestoreData(updated.data());
  }
}
