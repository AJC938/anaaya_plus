import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/availability_day.dart';
import '../domain/models/time_slot.dart';
import 'scheduling_repository.dart';

/// A realistic full-day spread, morning through evening, with a lunch gap
/// at 12 — matches [MockSchedulingRepository]'s own operating hours so
/// switching between the two never changes what a "day" looks like.
const _operatingHours = [9, 10, 11, 13, 14, 15, 16, 17];

const _daysAhead = 10;

/// The deterministic document ID for the slot `{serviceId}` occupies at
/// `{scheduledAt}` inside `serviceSlots` — deliberately NOT an
/// auto-generated ID. Two clients racing to claim "the 9am slot for
/// service s1 on 2026-01-05" always resolve to this exact same document,
/// so claiming a slot is just "does this document already exist", with no
/// query needed inside the claiming transaction.
///
/// [serviceId] is length-prefixed (`"<length>~<serviceId>~..."`) rather than
/// joined with a plain delimiter — a bare `id + "_" + date` join would let a
/// [serviceId] that itself contains `_` or `-` shift where the boundary
/// falls, risking two logically different (serviceId, date, hour) triples
/// formatting to the same string. Knowing [serviceId]'s exact byte length
/// up front makes its extent unambiguous regardless of what characters it
/// contains, without needing to escape anything. The date/hour portion
/// stays a fixed-width, human-readable block (not `Timestamp` or
/// `toIso8601String`) so the ID remains stable and debuggable in the
/// Firestore console regardless of timezone/formatting concerns.
String scheduleSlotDocumentId({required String serviceId, required DateTime scheduledAt}) {
  final y = scheduledAt.year.toString().padLeft(4, '0');
  final m = scheduledAt.month.toString().padLeft(2, '0');
  final d = scheduledAt.day.toString().padLeft(2, '0');
  final h = scheduledAt.hour.toString().padLeft(2, '0');
  return '${serviceId.length}~$serviceId~$y$m$d~$h';
}

/// The claim-record fields written to `serviceSlots/{slotId}` at the moment
/// a booking successfully claims a time slot. Pulled out as a standalone
/// function — rather than inlined in [FirestoreBookingRepository] — so its
/// shape is unit-testable without a real or fake Firestore instance,
/// matching `locationToFirestoreFields`'s pattern.
///
/// Deliberately excludes `claimedAt` — the caller (inside the claiming
/// transaction) always stamps that with `FieldValue.serverTimestamp()`
/// separately, the same way `addLocation`/booking `createdAt` do.
Map<String, dynamic> slotClaimFields({
  required String serviceId,
  required DateTime scheduledAt,
  required String claimedByUid,
  required String bookingReference,
}) {
  return {
    'serviceId': serviceId,
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'claimedByUid': claimedByUid,
    'bookingReference': bookingReference,
  };
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Availability
/// is read from a single, global `serviceSlots` collection — deliberately
/// NOT nested under `users/{uid}` like Cars/Locations/Bookings, since a
/// slot's availability is a shared resource every user's read needs to see
/// the same view of, not per-user data.
///
/// A slot document's mere existence means "claimed" — there are no
/// pre-created "available" documents to seed or keep in sync; the absence
/// of a document for a given [scheduleSlotDocumentId] IS the available
/// state. The actual atomic claim happens inside
/// `FirestoreBookingRepository.createBooking`'s transaction, not here —
/// this repository is read-only (matches [SchedulingRepository]'s existing
/// read-only abstraction; adding a write method to it would leak Firestore
/// transaction types into an interface [MockSchedulingRepository] also
/// implements).
class FirestoreSchedulingRepository implements SchedulingRepository {
  FirestoreSchedulingRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _slotsRef => _firestore.collection('serviceSlots');

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Claimed-slot document IDs for [serviceId] on [date] out of the fixed
  /// candidate hours — a single `whereIn` on the document ID itself, which
  /// needs no composite index (unlike a `scheduledAt` range query would).
  Future<Set<String>> _claimedIdsFor(String serviceId, DateTime date) async {
    final candidateIds = [
      for (final hour in _operatingHours)
        scheduleSlotDocumentId(serviceId: serviceId, scheduledAt: DateTime(date.year, date.month, date.day, hour)),
    ];
    final snapshot = await _slotsRef.where(FieldPath.documentId, whereIn: candidateIds).get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  @override
  Future<List<AvailabilityDay>> fetchAvailableDates({required String serviceId}) async {
    final today = _dateOnly(DateTime.now());
    final days = [for (var i = 1; i <= _daysAhead; i++) today.add(Duration(days: i))];

    final claimedCounts = await Future.wait(days.map((day) => _claimedIdsFor(serviceId, day)));

    return [
      for (var i = 0; i < days.length; i++)
        AvailabilityDay(date: days[i], hasAvailability: claimedCounts[i].length < _operatingHours.length),
    ];
  }

  @override
  Future<List<TimeSlot>> fetchTimeSlots({required String serviceId, required DateTime date}) async {
    final claimedIds = await _claimedIdsFor(serviceId, date);

    final slots = <TimeSlot>[];
    for (final hour in _operatingHours) {
      final start = DateTime(date.year, date.month, date.day, hour);
      final id = scheduleSlotDocumentId(serviceId: serviceId, scheduledAt: start);
      slots.add(TimeSlot(id: id, start: start, isAvailable: !claimedIds.contains(id)));
    }
    return slots;
  }
}
