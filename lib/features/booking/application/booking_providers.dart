import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../cars/application/cars_providers.dart';
import '../../services/application/services_providers.dart';
import '../data/booking_repository.dart';
import '../data/firestore_booking_repository.dart';
import '../domain/models/booking.dart';

/// Backed by the signed-in user's `users/{uid}/bookings` subcollection —
/// see [FirestoreBookingRepository]. Depends on [authStateChangesProvider]
/// (the single source of truth for auth state), never a separately-tracked
/// UID, so this rebuilds automatically on sign-in and sign-out — same
/// pattern as `carsRepositoryProvider`/`profileRepositoryProvider`.
///
/// No authenticated user (signed out, or auth still resolving) throws
/// rather than returning a placeholder repository, matching every other
/// repository provider in this app.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;

  if (uid == null) {
    throw StateError('bookingRepositoryProvider requires an authenticated user.');
  }

  return FirestoreBookingRepository(
    uid: uid,
    servicesRepository: ref.watch(servicesRepositoryProvider),
    carsRepository: ref.watch(carsRepositoryProvider),
  );
});

final bookingByIdProvider = FutureProvider.family<Booking?, String>((ref, id) async {
  // Waits for authStateChangesProvider's first emission before ever reading
  // bookingRepositoryProvider — same reasoning as carsControllerProvider's
  // own doc comment: on a fresh app launch, Firebase Auth still restoring
  // its session (uid not yet available) is indistinguishable from a
  // genuine sign-out, and bookingRepositoryProvider throws prematurely.
  await ref.watch(authStateChangesProvider.future);
  final locale = ref.watch(localeProvider);
  return ref.watch(bookingRepositoryProvider).fetchBookingById(id, locale);
});

/// Backs the Bookings screen. Not `autoDispose` — it must stay cached while
/// the Bookings tab sits offstage, and is explicitly invalidated right
/// after a successful booking creation (see Review's confirm handler) so a
/// new booking appears without the user needing to pull-to-refresh.
final bookingsListProvider = FutureProvider<List<Booking>>((ref) async {
  // See bookingByIdProvider's doc comment — the same startup-race guard.
  await ref.watch(authStateChangesProvider.future);
  final locale = ref.watch(localeProvider);
  return ref.watch(bookingRepositoryProvider).getBookings(locale);
});
