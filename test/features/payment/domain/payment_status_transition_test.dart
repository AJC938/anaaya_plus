import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/payment/domain/models/payment.dart';
import 'package:anaaya_plus/features/payment/domain/payment_status_transition.dart';

void main() {
  group('isValidPaymentStatusTransition — the happy path', () {
    test('pending -> paid is allowed', () {
      expect(isValidPaymentStatusTransition(from: PaymentStatus.pending, to: PaymentStatus.paid), isTrue);
    });

    test('pending -> failed is allowed', () {
      expect(isValidPaymentStatusTransition(from: PaymentStatus.pending, to: PaymentStatus.failed), isTrue);
    });

    test('failed -> pending is allowed (retrying re-opens a fresh attempt)', () {
      expect(isValidPaymentStatusTransition(from: PaymentStatus.failed, to: PaymentStatus.pending), isTrue);
    });
  });

  group('isValidPaymentStatusTransition — rejected transitions', () {
    const invalidPairs = [
      (PaymentStatus.paid, PaymentStatus.pending),
      (PaymentStatus.paid, PaymentStatus.failed),
      (PaymentStatus.failed, PaymentStatus.failed),
      (PaymentStatus.pending, PaymentStatus.pending),
    ];

    for (final (from, to) in invalidPairs) {
      test('$from -> $to is rejected', () {
        expect(isValidPaymentStatusTransition(from: from, to: to), isFalse);
      });
    }

    test('a status can never transition to itself', () {
      for (final status in PaymentStatus.values) {
        expect(isValidPaymentStatusTransition(from: status, to: status), isFalse, reason: '$status -> $status must be rejected');
      }
    });
  });

  group('terminal statuses', () {
    test('paid has no outgoing edges at all', () {
      expect(paymentStatusTransitions[PaymentStatus.paid], isEmpty);
    });
  });

  group('canSubmitPayment', () {
    test('a fresh booking with no prior payment can always submit', () {
      expect(canSubmitPayment(current: null, target: PaymentStatus.paid), isTrue);
      expect(canSubmitPayment(current: null, target: PaymentStatus.failed), isTrue);
    });

    test('a failed payment can be resubmitted to either outcome', () {
      expect(canSubmitPayment(current: PaymentStatus.failed, target: PaymentStatus.paid), isTrue);
      expect(canSubmitPayment(current: PaymentStatus.failed, target: PaymentStatus.failed), isTrue);
    });

    test('an already-paid payment can never be resubmitted — paid is terminal', () {
      expect(canSubmitPayment(current: PaymentStatus.paid, target: PaymentStatus.paid), isFalse);
      expect(canSubmitPayment(current: PaymentStatus.paid, target: PaymentStatus.failed), isFalse);
    });

    test('a payment somehow stuck in pending can still be resubmitted (crash-recovery case)', () {
      expect(canSubmitPayment(current: PaymentStatus.pending, target: PaymentStatus.paid), isTrue);
      expect(canSubmitPayment(current: PaymentStatus.pending, target: PaymentStatus.failed), isTrue);
    });
  });

  group('InvalidPaymentStatusTransitionException', () {
    test('carries the exact from/to that was rejected', () {
      const exception = InvalidPaymentStatusTransitionException(from: PaymentStatus.paid, to: PaymentStatus.pending);

      expect(exception.from, PaymentStatus.paid);
      expect(exception.to, PaymentStatus.pending);
      expect(exception.toString(), contains('paid'));
      expect(exception.toString(), contains('pending'));
    });
  });
}
