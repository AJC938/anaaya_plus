import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';
import 'package:anaaya_plus/features/payment/presentation/screens/payment_screen.dart';

import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart';
import '../../../support/payment_fixtures.dart';

const _bookingId = 'AN-00001';
final _route = AppRoutes.bookingPayment(testServiceId, _bookingId);

class _FixedLocale extends LocaleController {
  _FixedLocale(this._locale);
  final Locale _locale;
  @override
  Locale build() => _locale;
}

Booking _bookingWith({double total = 124}) {
  return Booking(
    id: _bookingId,
    serviceId: testServiceId,
    serviceName: 'Oil Change',
    serviceImageAsset: 'oil_change',
    vehicleId: 'v1',
    vehicleName: 'Toyota Camry',
    vehicleYear: 2023,
    plateNumber: 'ABC 1234',
    location: testHomeLocation,
    scheduledAt: DateTime.now().add(const Duration(hours: 2)),
    price: BookingPriceBreakdown(basePrice: total - 10, optionPrice: 0, fees: 10, total: total),
    status: BookingStatus.upcoming,
    createdAt: DateTime(2026, 1, 1),
  );
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(PaymentScreen)));

void main() {
  testWidgets('renders the booking summary, the correct amount due, and the Simulate Payment button', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final paymentRepo = FakePaymentRepository()..bookingAmounts[booking.id] = 124;
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);
    final l10n = _l10n(tester);

    expect(find.text(l10n.priceSar('124')), findsOneWidget);
    expect(find.text('Oil Change'), findsOneWidget);
    expect(find.text(l10n.simulatePaymentCta), findsOneWidget);
    expect(find.text(l10n.paymentSimulationNotice), findsOneWidget);
  });

  testWidgets('the payment screen has no Moyasar/gateway UI at all', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final paymentRepo = FakePaymentRepository()..bookingAmounts[booking.id] = 124;
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);

    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('tapping Simulate Payment shows the success state, with no false-success before it resolves', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final completer = Completer<Payment>();
    var submitCalls = 0;
    final paymentRepo = FakePaymentRepository(
      onSubmit: (bookingReference, status, method, transactionId) {
        submitCalls++;
        return completer.future;
      },
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.simulatePaymentCta));
    await tester.pump();

    // Still awaiting the (fake) repository write — never shows success
    // before the payment domain layer actually resolves it. The button
    // itself is replaced by a loading indicator while the simulation is
    // being recorded.
    expect(find.text(l10n.paymentSuccessTitle), findsNothing);
    expect(find.text(l10n.simulatePaymentCta), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(submitCalls, 1);

    completer.complete(
      Payment(
        bookingReference: booking.id,
        amount: 124,
        currency: 'SAR',
        status: PaymentStatus.paid,
        method: 'simulated',
        transactionId: 'sim-test-id',
        createdAt: DateTime.now(),
        statusUpdatedAt: DateTime.now(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.paymentSuccessTitle), findsOneWidget);
    expect(find.text(l10n.simulatePaymentCta), findsNothing);
  });

  testWidgets('the simulated payment is always submitted as paid, with a fresh transaction id', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    PaymentStatus? capturedStatus;
    String? capturedMethod;
    String? capturedTransactionId;
    final paymentRepo = FakePaymentRepository(
      onSubmit: (bookingReference, status, method, transactionId) async {
        capturedStatus = status;
        capturedMethod = method;
        capturedTransactionId = transactionId;
        return Payment(
          bookingReference: bookingReference,
          amount: 124,
          currency: 'SAR',
          status: status,
          method: method,
          transactionId: transactionId,
          createdAt: DateTime.now(),
          statusUpdatedAt: DateTime.now(),
        );
      },
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.simulatePaymentCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(capturedStatus, PaymentStatus.paid);
    expect(capturedMethod, 'simulated');
    expect(capturedTransactionId, isNotEmpty);
  });

  testWidgets('a repository failure shows a generic error and keeps the Simulate Payment button available', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final paymentRepo = FakePaymentRepository(
      onSubmit: (bookingReference, status, method, transactionId) async => throw Exception('offline'),
    )..bookingAmounts[booking.id] = 124;
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.simulatePaymentCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text(l10n.paymentSuccessTitle), findsNothing);
    expect(find.text(l10n.paymentFailedMessage), findsOneWidget);
    // The Simulate Payment button reappears for another attempt.
    expect(find.text(l10n.simulatePaymentCta), findsOneWidget);
  });

  testWidgets('repeating the simulation after a real success never creates a duplicate/broken payment', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final paymentRepo = FakePaymentRepository()..bookingAmounts[booking.id] = 124;
    await pumpBookingScreen(tester, route: _route, bookingRepository: bookingRepo, paymentRepository: paymentRepo);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.simulatePaymentCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(l10n.paymentSuccessTitle), findsOneWidget);

    final first = paymentRepo.payments[booking.id];
    expect(first, isNotNull);

    // Once paid, the success view has no Simulate Payment affordance at all
    // — there is no UI path left to resubmit through.
    expect(find.text(l10n.simulatePaymentCta), findsNothing);

    // The repository layer's own idempotency (already covered directly in
    // mock_payment_repository_test.dart / payment_controller_test.dart) is
    // what actually prevents a duplicate/broken state if something did call
    // submitPayment again — confirmed here at the data level too.
    final second = await paymentRepo.submitPayment(
      bookingReference: booking.id,
      status: PaymentStatus.paid,
      method: 'simulated',
      transactionId: 'sim-second-attempt',
    );
    expect(second.transactionId, first!.transactionId);
    expect(second.createdAt, first.createdAt);
  });

  testWidgets('renders correctly in Arabic — amount, notice, and the Simulate Payment button all remain valid', (tester) async {
    final booking = _bookingWith(total: 124);
    final bookingRepo = FakeBookingRepository()..bookings[booking.id] = booking;
    final paymentRepo = FakePaymentRepository()..bookingAmounts[booking.id] = 124;
    await pumpBookingScreen(
      tester,
      route: _route,
      bookingRepository: bookingRepo,
      paymentRepository: paymentRepo,
      extraOverrides: [localeProvider.overrideWith(() => _FixedLocale(const Locale('ar')))],
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.priceSar('124')), findsOneWidget);
    expect(find.text(l10n.simulatePaymentCta), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(PaymentScreen))), TextDirection.rtl);
  });
}
