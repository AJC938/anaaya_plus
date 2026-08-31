import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/firestore_payment_repository.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment.dart';

/// Mirrors `bookingRepositoryProvider`'s exact shape — scoped to the signed-in
/// user's uid, rebuilds on sign-in/sign-out, throws rather than returning a
/// placeholder when signed out.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;

  if (uid == null) {
    throw StateError('paymentRepositoryProvider requires an authenticated user.');
  }

  return FirestorePaymentRepository(uid: uid);
});

/// Fetch-only read of a booking's current payment — `null` means no payment
/// has ever been attempted yet. Mirrors `bookingByIdProvider`'s own
/// auth-restoration startup-race guard.
final paymentByBookingProvider = FutureProvider.family<Payment?, String>((ref, bookingReference) async {
  await ref.watch(authStateChangesProvider.future);
  return ref.watch(paymentRepositoryProvider).fetchPayment(bookingReference: bookingReference);
});
