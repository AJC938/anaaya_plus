import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../notifications/application/notification_event_service.dart';
import '../domain/models/payment.dart';
import 'payment_providers.dart';

/// Owns a single booking's payment state — mirrors
/// `BookingStatusController`'s exact shape (manual family-notifier
/// construction, a synchronous re-entrancy guard set before the first
/// `await`, `_lastKnown` preserved across a failed attempt so the screen
/// never loses what it already knew). Kept as a fully separate controller,
/// not folded into `BookingStatusController`, because Payment is
/// deliberately independent state (see `payment_status_transition.dart`'s
/// own doc comment) — one instance per bookingReference.
class PaymentController extends AsyncNotifier<Payment?> {
  PaymentController(this.bookingReference);

  final String bookingReference;

  /// Unlike `BookingStatusController`, [submitPayment] never needs to
  /// remember "which booking" separately — [bookingReference] is already a
  /// plain constructor field. This flag only guards against a call arriving
  /// before [build] has ever resolved once.
  bool _hasLoaded = false;

  @override
  Future<Payment?> build() async {
    await ref.watch(authStateChangesProvider.future);
    final payment = await ref.watch(paymentRepositoryProvider).fetchPayment(bookingReference: bookingReference);
    _hasLoaded = true;
    return payment;
  }

  /// Records the local test payment simulation's result directly — see
  /// `payment_screen.dart`'s "Simulate Payment" button, which always calls
  /// this with `status: PaymentStatus.paid`. This controller never itself
  /// decides paid vs. failed; it only reflects whatever the repository ends
  /// up writing.
  ///
  /// The synchronous `state.isLoading` check below is the sole
  /// double-submission guard: a rapid double-tap, or a second call arriving
  /// while the first is still in flight, always observes `isLoading == true`
  /// and returns immediately as a no-op — the repository is never called
  /// twice concurrently for the same booking from this controller.
  Future<void> submitPayment({required PaymentStatus status, required String method, required String transactionId}) async {
    if (state.isLoading) return;
    // The initial load must resolve first — otherwise a call arriving
    // before build() ever finishes could race ahead of it with no
    // `_lastKnown` context yet.
    if (!_hasLoaded) return;

    state = const AsyncLoading();
    final repository = ref.read(paymentRepositoryProvider);
    final result = await AsyncValue.guard(
      () => repository.submitPayment(
        bookingReference: bookingReference,
        status: status,
        method: method,
        transactionId: transactionId,
      ),
    );
    state = result;

    if (result.hasValue) {
      // So Tracking's "Complete Payment" banner (which reads the separate,
      // fetch-only paymentByBookingProvider — see its own doc comment)
      // reflects the new status immediately instead of whatever it last
      // cached, matching BookingStatusController's own reasoning for
      // invalidating bookingsListProvider on success.
      ref.invalidate(paymentByBookingProvider(bookingReference));
      unawaited(
        ref
            .read(notificationEventServiceProvider)
            .recordPaymentStatus(status: result.value!.status, bookingReference: bookingReference),
      );
    }
  }
}

final paymentControllerProvider = AsyncNotifierProvider.family<PaymentController, Payment?, String>(PaymentController.new);
