import '../domain/models/payment.dart';
import '../domain/payment_status_transition.dart';
import 'payment_repository.dart';

/// Local/in-memory stand-in for [FirestorePaymentRepository], matching
/// [MockBookingRepository]'s role — no Firestore call involved, used by test
/// harnesses only (the running app always uses [FirestorePaymentRepository]).
class MockPaymentRepository implements PaymentRepository {
  MockPaymentRepository({required this.bookingAmounts});

  /// bookingReference -> authoritative amount, standing in for what a real
  /// booking's stored `price.total` would be — this repository never
  /// accepts an amount from a caller, matching the Firestore
  /// implementation's own contract.
  final Map<String, double> bookingAmounts;

  final Map<String, Payment> _payments = {};

  @override
  Future<Payment?> fetchPayment({required String bookingReference}) async => _payments[bookingReference];

  @override
  Future<Payment> submitPayment({
    required String bookingReference,
    required PaymentStatus status,
    required String method,
    required String transactionId,
  }) async {
    final amount = bookingAmounts[bookingReference];
    if (amount == null) {
      throw StateError('Booking $bookingReference not found');
    }

    final existing = _payments[bookingReference];
    if (existing?.status == PaymentStatus.paid) {
      return existing!;
    }
    if (!canSubmitPayment(current: existing?.status, target: status)) {
      throw InvalidPaymentStatusTransitionException(from: existing?.status ?? PaymentStatus.pending, to: status);
    }

    final now = DateTime.now();
    final payment = Payment(
      bookingReference: bookingReference,
      amount: amount,
      currency: 'SAR',
      status: status,
      method: method,
      transactionId: transactionId,
      createdAt: existing?.createdAt ?? now,
      statusUpdatedAt: now,
    );
    _payments[bookingReference] = payment;
    return payment;
  }
}
