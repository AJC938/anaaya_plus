import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/payment/application/payment_controller.dart';
import 'package:anaaya_plus/features/payment/application/payment_providers.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/payment_fixtures.dart';

const _bookingRef = 'AN-00001';

/// Waits for the controller's initial `build()` (its `fetchPayment` load) to
/// settle before a test starts calling `submitPayment()` — mirrors
/// `booking_status_controller_test.dart`'s own `_containerLoaded` exactly.
Future<ProviderContainer> _containerLoaded({required FakePaymentRepository repository}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      paymentRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(paymentControllerProvider(_bookingRef), (previous, next) {});
  await container.read(paymentControllerProvider(_bookingRef).future);
  return container;
}

Future<void> _submitPaid(
  PaymentController notifier, {
  String transactionId = 'sim-paid-1',
}) {
  return notifier.submitPayment(status: PaymentStatus.paid, method: 'card_visa', transactionId: transactionId);
}

Future<void> _submitFailed(
  PaymentController notifier, {
  String transactionId = 'sim-failed-1',
}) {
  return notifier.submitPayment(status: PaymentStatus.failed, method: 'card_visa', transactionId: transactionId);
}

void main() {
  group('initial load', () {
    test('no prior payment resolves to null, not an error', () async {
      final repository = FakePaymentRepository()..bookingAmounts[_bookingRef] = 124;
      final container = await _containerLoaded(repository: repository);

      expect(container.read(paymentControllerProvider(_bookingRef)).value, isNull);
    });
  });

  group('submitPayment — success', () {
    test('a paid gateway result resolves to a paid record', () async {
      final repository = FakePaymentRepository()..bookingAmounts[_bookingRef] = 124;
      final container = await _containerLoaded(repository: repository);

      await _submitPaid(container.read(paymentControllerProvider(_bookingRef).notifier));

      final state = container.read(paymentControllerProvider(_bookingRef));
      expect(state.value?.status, PaymentStatus.paid);
      expect(state.value?.amount, 124);
    });

    test('a successful payment invalidates paymentByBookingProvider so Tracking refreshes', () async {
      final repository = FakePaymentRepository()..bookingAmounts[_bookingRef] = 124;
      final container = await _containerLoaded(repository: repository);
      // Prime the cache once so invalidation has something to mark stale.
      await container.read(paymentByBookingProvider(_bookingRef).future);
      expect(container.read(paymentByBookingProvider(_bookingRef)).value, isNull);

      await _submitPaid(container.read(paymentControllerProvider(_bookingRef).notifier));
      await container.read(paymentByBookingProvider(_bookingRef).future);

      expect(container.read(paymentByBookingProvider(_bookingRef)).value?.status, PaymentStatus.paid);
    });
  });

  group('submitPayment — failure', () {
    test('a failed gateway result resolves to a failed record, never paid', () async {
      final repository = FakePaymentRepository()..bookingAmounts[_bookingRef] = 124;
      final container = await _containerLoaded(repository: repository);

      await _submitFailed(container.read(paymentControllerProvider(_bookingRef).notifier));

      final state = container.read(paymentControllerProvider(_bookingRef));
      expect(state.value?.status, PaymentStatus.failed);
    });
  });

  group('submitPayment — retry', () {
    test('retrying after a failure can succeed', () async {
      final repository = FakePaymentRepository()..bookingAmounts[_bookingRef] = 124;
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(paymentControllerProvider(_bookingRef).notifier);

      await _submitFailed(notifier);
      await _submitPaid(notifier, transactionId: 'sim-retry-1');

      final state = container.read(paymentControllerProvider(_bookingRef));
      expect(state.value?.status, PaymentStatus.paid);
    });
  });

  group('submitPayment — double-submission protection', () {
    test('a second call while the first is still in flight never reaches the repository a second time', () async {
      final completer = Completer<Payment>();
      var submitCalls = 0;
      final repository = FakePaymentRepository(
        onSubmit: (bookingReference, status, method, transactionId) {
          submitCalls++;
          return completer.future;
        },
      );
      final container = await _containerLoaded(repository: repository);
      final notifier = container.read(paymentControllerProvider(_bookingRef).notifier);

      final first = _submitPaid(notifier);
      final second = _submitPaid(notifier);

      expect(submitCalls, 1);
      expect(container.read(paymentControllerProvider(_bookingRef)).isLoading, isTrue);

      completer.complete(
        Payment(
          bookingReference: _bookingRef,
          amount: 124,
          currency: 'SAR',
          status: PaymentStatus.paid,
          method: 'card_visa',
          transactionId: 'sim-paid-1',
          createdAt: DateTime.now(),
          statusUpdatedAt: DateTime.now(),
        ),
      );
      await first;
      await second;

      expect(submitCalls, 1);
    });
  });

  group('submitPayment — booking/payment consistency and error handling', () {
    test('a repository failure surfaces as an error, never a false paid state', () async {
      final repository = FakePaymentRepository(
        onSubmit: (bookingReference, status, method, transactionId) async => throw Exception('Gateway unavailable'),
      );
      final container = await _containerLoaded(repository: repository);

      await _submitPaid(container.read(paymentControllerProvider(_bookingRef).notifier));

      final state = container.read(paymentControllerProvider(_bookingRef));
      expect(state.hasError, isTrue);
      expect(state.value?.status == PaymentStatus.paid, isNot(isTrue));
    });

    test('an unknown/never-created booking cannot be paid for', () async {
      final repository = FakePaymentRepository(); // no bookingAmounts seeded at all
      final container = await _containerLoaded(repository: repository);

      await _submitPaid(container.read(paymentControllerProvider(_bookingRef).notifier));

      final state = container.read(paymentControllerProvider(_bookingRef));
      expect(state.hasError, isTrue);
    });
  });
}
