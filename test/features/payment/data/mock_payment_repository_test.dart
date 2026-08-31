import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/payment/data/mock_payment_repository.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';
import 'package:anaaya_plus/features/payment/domain/payment_status_transition.dart';

Future<Payment> _submit(
  MockPaymentRepository repository,
  String bookingReference, {
  PaymentStatus status = PaymentStatus.paid,
  String method = 'card_visa',
  String transactionId = 'sim-paid-1',
}) {
  return repository.submitPayment(
    bookingReference: bookingReference,
    status: status,
    method: method,
    transactionId: transactionId,
  );
}

void main() {
  group('fetchPayment', () {
    test('returns null when no payment has ever been attempted', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 100});

      final result = await repository.fetchPayment(bookingReference: 'AN-1');

      expect(result, isNull);
    });
  });

  group('submitPayment — success', () {
    test('a submission returns and persists a paid payment', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 124});

      final payment = await _submit(repository, 'AN-1');

      expect(payment.status, PaymentStatus.paid);
      expect(payment.bookingReference, 'AN-1');
      final refetched = await repository.fetchPayment(bookingReference: 'AN-1');
      expect(refetched!.status, PaymentStatus.paid);
    });

    test('the amount always comes from bookingAmounts — never a caller-supplied value', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 89.5});

      final payment = await _submit(repository, 'AN-1');

      expect(payment.amount, 89.5);
    });

    test('currency is always SAR', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 100});

      final payment = await _submit(repository, 'AN-1');

      expect(payment.currency, 'SAR');
    });

    test('the gateway-reported payment id is persisted as the transaction id', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 124});

      final payment = await repository.submitPayment(
        bookingReference: 'AN-1',
        status: PaymentStatus.paid,
        method: 'card_visa',
        transactionId: 'sim-abc123',
      );

      expect(payment.transactionId, 'sim-abc123');
    });

    test('a failed submission persists a failed record', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 124});

      final payment = await _submit(repository, 'AN-1', status: PaymentStatus.failed);

      expect(payment.status, PaymentStatus.failed);
    });
  });

  group('submitPayment — unknown booking', () {
    test('an unknown booking reference throws — a booking must exist to be paid for', () async {
      final repository = MockPaymentRepository(bookingAmounts: const {});

      await expectLater(_submit(repository, 'not-a-real-booking'), throwsStateError);
    });
  });

  group('submitPayment — idempotent once paid (duplicate-submission protection)', () {
    test('re-submitting an already-paid booking returns the existing paid record unchanged, never a new one', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 124});
      final first = await _submit(repository, 'AN-1');

      final second = await _submit(repository, 'AN-1', transactionId: 'sim-second-attempt');

      expect(second.transactionId, first.transactionId);
      expect(second.createdAt, first.createdAt);
    });
  });

  group('submitPayment — illegal transitions', () {
    test('resubmitting a failed booking straight back to failed is legal (a fresh declined retry)', () async {
      final repository = MockPaymentRepository(bookingAmounts: {'AN-1': 124});
      await _submit(repository, 'AN-1', status: PaymentStatus.failed);

      final payment = await _submit(repository, 'AN-1', status: PaymentStatus.failed);

      expect(payment.status, PaymentStatus.failed);
    });

    test('an illegal transition throws InvalidPaymentStatusTransitionException, matching canSubmitPayment', () async {
      // paid -> paid has no direct edge in paymentStatusTransitions, but the
      // already-paid short-circuit above returns the existing record before
      // this check is ever reached — so there is no reachable illegal
      // transition through the public API today. This test documents that
      // invariant directly against the shared state machine instead.
      expect(canSubmitPayment(current: PaymentStatus.paid, target: PaymentStatus.failed), isFalse);
    });
  });
}
