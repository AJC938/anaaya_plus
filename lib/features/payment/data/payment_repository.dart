import '../domain/models/payment.dart';

/// Data seam for the Payment feature — mirrors [BookingRepository]'s own
/// shape (an abstract interface, a Firestore implementation, and a Mock
/// implementation for tests/dev).
abstract class PaymentRepository {
  /// The current payment for [bookingReference], or `null` if no payment
  /// has ever been attempted for this booking yet.
  Future<Payment?> fetchPayment({required String bookingReference});

  /// Records a LOCAL TEST PAYMENT SIMULATION's outcome directly — there is
  /// no external payment gateway anywhere in this app. [status], [method],
  /// and [transactionId] are supplied by the caller (see
  /// `payment_screen.dart`'s "Simulate Payment" button), never decided by
  /// this repository. `amount` is never a parameter — it is always resolved
  /// from the booking's own stored `price.total`, never a value the UI or
  /// caller supplies.
  ///
  /// Validates the transition via [canSubmitPayment] before writing —
  /// throws [InvalidPaymentStatusTransitionException] for an illegal one.
  /// Already [PaymentStatus.paid] is idempotent: submitting again returns
  /// the existing paid record unchanged rather than creating a second
  /// successful payment or erroring.
  ///
  /// SECURITY NOTE: this is a client-authoritative write with no real
  /// payment processing behind it at all — suitable only for this project's
  /// test/portfolio purposes. A real production integration would need an
  /// actual payment gateway plus a server-side verification step, neither
  /// of which exist here.
  Future<Payment> submitPayment({
    required String bookingReference,
    required PaymentStatus status,
    required String method,
    required String transactionId,
  });
}
