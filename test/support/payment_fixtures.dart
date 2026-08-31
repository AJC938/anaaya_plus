import 'package:anaaya_plus/features/payment/data/payment_repository.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';
import 'package:anaaya_plus/features/payment/domain/payment_status_transition.dart';

/// A [PaymentRepository] with no artificial latency and controllable
/// outcomes — matches [FakeBookingRepository]'s exact role (widget/
/// controller tests that only care about the app's reaction to success/
/// failure use this instead of the real Mock, whose own behavior is
/// exercised directly in mock_payment_repository_test.dart).
class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({this.onSubmit});

  /// Overrides [submitPayment] entirely — a throwing/delaying closure for a
  /// generic repository-failure or in-flight test. Defaults to a real
  /// in-memory mutation that enforces [canSubmitPayment] the same way the
  /// real repositories do.
  Future<Payment> Function(String bookingReference, PaymentStatus status, String method, String transactionId)?
  onSubmit;

  final Map<String, Payment> payments = {};
  final Map<String, double> bookingAmounts = {};

  @override
  Future<Payment?> fetchPayment({required String bookingReference}) async => payments[bookingReference];

  @override
  Future<Payment> submitPayment({
    required String bookingReference,
    required PaymentStatus status,
    required String method,
    required String transactionId,
  }) {
    if (onSubmit != null) return onSubmit!(bookingReference, status, method, transactionId);
    return _defaultSubmit(bookingReference, status, method, transactionId);
  }

  Future<Payment> _defaultSubmit(String bookingReference, PaymentStatus status, String method, String transactionId) async {
    final amount = bookingAmounts[bookingReference];
    if (amount == null) {
      throw StateError('Booking $bookingReference not found');
    }

    final existing = payments[bookingReference];
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
    payments[bookingReference] = payment;
    return payment;
  }
}
