import 'dart:math';

/// Generates a user-friendly booking reference like "AN-20481-4732" — never
/// a raw UUID in the UI.
///
/// The first segment is the original time-derived value (kept unchanged, so
/// references stay roughly chronological and the visible "AN-" style is
/// preserved). On its own that segment repeats deterministically every
/// ~100 seconds (`millisecondsSinceEpoch % 100000`), so two bookings
/// created in the same window were previously GUARANTEED to collide, not
/// just unlikely to — [FirestoreBookingRepository.fetchBookingById] looks
/// bookings up by exact match on this field, so a collision could make one
/// of the two bookings unreachable by id. The second, random segment
/// removes that guarantee: a collision now additionally requires the same
/// 4-digit draw (a 1-in-10,000 chance) on top of landing in the same
/// 100-second window, which is practically sufficient here since
/// `fetchBookingById` only ever searches a single user's own `bookings`
/// subcollection, not the whole app.
///
/// [random] is exposed only so tests can inject a seeded [Random] for
/// deterministic assertions — production call sites never pass it.
String generateBookingReference({DateTime? now, Random? random}) {
  final effectiveNow = now ?? DateTime.now();
  final timeSeed = effectiveNow.millisecondsSinceEpoch % 100000;
  final randomSuffix = (random ?? Random()).nextInt(10000);
  return 'AN-${timeSeed.toString().padLeft(5, '0')}-${randomSuffix.toString().padLeft(4, '0')}';
}
