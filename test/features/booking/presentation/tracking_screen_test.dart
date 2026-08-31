import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/full_screen_message.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/tracking_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/widgets/booking_summary_card.dart';
import 'package:anaaya_plus/features/booking/presentation/widgets/status_timeline.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';
import 'package:anaaya_plus/features/payment/presentation/screens/payment_screen.dart';

import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart';
import '../../../support/payment_fixtures.dart';

const _bookingId = 'AN-00001';
final _route = AppRoutes.bookingTracking(_bookingId);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(TrackingScreen)));

Booking _bookingWith({
  required BookingStatus status,
  DateTime? scheduledAt,
  DateTime? estimatedArrival,
}) {
  return Booking(
    id: _bookingId,
    serviceId: testServiceId,
    serviceName: 'Oil Change',
    serviceImageAsset: 'oil_change',
    serviceOptionId: 'opt-mineral',
    serviceOptionName: 'Mineral',
    vehicleId: 'v1',
    vehicleName: 'Toyota Camry',
    vehicleYear: 2023,
    plateNumber: 'ABC 1234',
    location: testHomeLocation,
    scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(hours: 2)),
    price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 25, fees: 10, total: 124),
    status: status,
    estimatedArrival: estimatedArrival,
    createdAt: DateTime(2026, 1, 1),
  );
}

FakeBookingRepository _repoWith(Booking booking) => FakeBookingRepository()..bookings[booking.id] = booking;

void main() {
  testWidgets('an unknown booking id shows an error state', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: FakeBookingRepository());

    expect(find.byType(FullScreenMessage), findsOneWidget);
  });

  testWidgets('upcoming shows the upcoming title and a "starts in" countdown that is never negative', (tester) async {
    final booking = _bookingWith(status: BookingStatus.upcoming, scheduledAt: DateTime.now().subtract(const Duration(seconds: 5)));
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.upcomingServiceTitle), findsOneWidget);
    // The target is already in the past, so remainingUntil clamps to zero.
    expect(find.text(l10n.startingNow), findsOneWidget);
    expect(find.byType(StatusTimeline), findsOneWidget);
    expect(find.byType(BookingSummaryCard), findsOneWidget);
  });

  testWidgets('technicianOnTheWay shows the on-the-way title and an ETA countdown', (tester) async {
    final booking = _bookingWith(
      status: BookingStatus.technicianOnTheWay,
      // A generous buffer past the 18-minute mark so test setup/render
      // overhead can never truncate the displayed minute count down to 17.
      estimatedArrival: DateTime.now().add(const Duration(minutes: 18, seconds: 45)),
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    // The status title also appears as this status's own node label inside
    // StatusTimeline, so at least one match (not exactly one) is expected.
    expect(find.text(l10n.technicianOnTheWayTitle), findsWidgets);
    expect(find.text(l10n.etaLabel('18m')), findsOneWidget);
  });

  testWidgets('an arrived technician (ETA already passed) shows "arrived", never a negative ETA', (tester) async {
    final booking = _bookingWith(
      status: BookingStatus.technicianOnTheWay,
      estimatedArrival: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.technicianArrivedLabel), findsOneWidget);
  });

  testWidgets('inProgress shows the in-progress title and a progress indicator, no countdown text', (tester) async {
    final booking = _bookingWith(status: BookingStatus.inProgress);
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.serviceInProgressTitle), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('completed shows the completed title with no countdown and no progress bar', (tester) async {
    final booking = _bookingWith(status: BookingStatus.completed);
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.serviceCompletedTitle), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('cancelled shows the cancelled title and skips the timeline entirely', (tester) async {
    final booking = _bookingWith(status: BookingStatus.cancelled);
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.bookingCancelledTitle), findsOneWidget);
    expect(find.byType(StatusTimeline), findsNothing);
    expect(find.byType(BookingSummaryCard), findsOneWidget);
  });

  testWidgets('opening an already-cancelled booking never shows the cancellation success snackbar', (tester) async {
    // Regression test: the initial load's own Loading -> Data transition
    // must never be mistaken for a genuine user-triggered cancellation —
    // confirmed live (a cold-launched revisit of a previously cancelled
    // booking incorrectly showed the snackbar before this was fixed).
    final booking = _bookingWith(status: BookingStatus.cancelled);
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
    await tester.pump(const Duration(milliseconds: 100));
    final l10n = _l10n(tester);

    expect(find.text(l10n.bookingCancelledSuccessMessage), findsNothing);
  });

  testWidgets('the timeline reflects technicianOnTheWay as the current step, not done or pending', (tester) async {
    final booking = _bookingWith(status: BookingStatus.technicianOnTheWay, estimatedArrival: DateTime.now().add(const Duration(minutes: 5)));
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));

    final icons = tester.widgetList<Icon>(find.descendant(of: find.byType(StatusTimeline), matching: find.byType(Icon))).toList();
    // 5 timeline nodes: Confirmed(done) / Assigned(done) / On the way(current) / In progress(pending) / Completed(pending).
    final doneCount = icons.where((icon) => icon.icon == Icons.check_circle).length;
    final currentCount = icons.where((icon) => icon.icon == Icons.radio_button_checked).length;
    final pendingCount = icons.where((icon) => icon.icon == Icons.radio_button_unchecked).length;

    expect(doneCount, 2);
    expect(currentCount, 1);
    expect(pendingCount, 2);
  });

  group('the simulate-advance demo control', () {
    testWidgets('upcoming shows a "technician on the way" simulate button; tapping it advances the status', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      expect(find.text(l10n.simulateTechnicianOnTheWayCta), findsOneWidget);

      await tester.tap(find.text(l10n.simulateTechnicianOnTheWayCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.technicianOnTheWayTitle), findsWidgets);
      expect(find.text(l10n.simulateStartServiceCta), findsOneWidget);
    });

    testWidgets('technicianOnTheWay shows a "start service" simulate button; tapping it advances to inProgress', (tester) async {
      final booking = _bookingWith(status: BookingStatus.technicianOnTheWay, estimatedArrival: DateTime.now().add(const Duration(minutes: 5)));
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.simulateStartServiceCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.serviceInProgressTitle), findsWidgets);
      expect(find.text(l10n.simulateCompleteServiceCta), findsOneWidget);
    });

    testWidgets('inProgress shows a "mark completed" simulate button; tapping it advances to completed', (tester) async {
      final booking = _bookingWith(status: BookingStatus.inProgress);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.simulateCompleteServiceCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.serviceCompletedTitle), findsWidgets);
      // completed is terminal — no further simulate button of any kind.
      expect(find.text(l10n.simulateTechnicianOnTheWayCta), findsNothing);
      expect(find.text(l10n.simulateStartServiceCta), findsNothing);
      expect(find.text(l10n.simulateCompleteServiceCta), findsNothing);
    });

    testWidgets('completed shows no simulate button — the lifecycle is terminal', (tester) async {
      final booking = _bookingWith(status: BookingStatus.completed);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      expect(find.text(l10n.simulateProgressSectionTitle), findsNothing);
    });

    testWidgets('cancelled shows no simulate button — the cancelled view has no timeline or advance controls at all', (tester) async {
      final booking = _bookingWith(status: BookingStatus.cancelled);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      expect(find.text(l10n.simulateProgressSectionTitle), findsNothing);
    });

    testWidgets('a failed advance shows an error snackbar and keeps the booking on screen', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      final repository = _repoWith(booking)
        ..onUpdateStatus = (bookingReference, newStatus) async => throw Exception('Firestore unavailable');
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.simulateTechnicianOnTheWayCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.statusUpdateFailedMessage), findsOneWidget);
      // The booking (still upcoming — the failed advance never applied)
      // must still be fully visible, not replaced by an error screen.
      expect(find.text(l10n.upcomingServiceTitle), findsWidgets);
      expect(find.byType(BookingSummaryCard), findsOneWidget);
    });

    testWidgets('a second tap while the first advance is still in flight does not fire a duplicate request', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      var updateCalls = 0;
      final completer = Completer<Booking>();
      final repository = _repoWith(booking)
        ..onUpdateStatus = (bookingReference, newStatus) {
          updateCalls++;
          return completer.future;
        };
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.simulateTechnicianOnTheWayCta));
      await tester.pump();

      expect(updateCalls, 1);
      // The button shows a spinner and is disabled while in flight — a
      // second tap must not be able to fire a second request.
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      expect(updateCalls, 1);

      completer.complete(_bookingWith(status: BookingStatus.technicianOnTheWay));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('BE-06 — the real cancel-booking action', () {
    testWidgets('upcoming shows a Cancel Booking CTA', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      expect(find.text(l10n.cancelBookingCta), findsOneWidget);
    });

    for (final status in [
      BookingStatus.technicianOnTheWay,
      BookingStatus.inProgress,
      BookingStatus.completed,
      BookingStatus.cancelled,
    ]) {
      testWidgets('$status shows no Cancel Booking CTA', (tester) async {
        final booking = _bookingWith(
          status: status,
          estimatedArrival: status == BookingStatus.technicianOnTheWay ? DateTime.now().add(const Duration(minutes: 5)) : null,
        );
        await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
        final l10n = _l10n(tester);

        expect(find.text(l10n.cancelBookingCta), findsNothing);
      });
    }

    testWidgets('tapping Cancel Booking shows a confirmation dialog; dismissing it keeps the booking upcoming', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      var cancelCalls = 0;
      final repository = _repoWith(booking)..onCancel = (bookingReference) async => throw StateError('must not be called');
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.cancelBookingCta).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.cancelBookingConfirmTitle), findsOneWidget);

      await tester.tap(find.text(l10n.keepBookingAction));
      await tester.pumpAndSettle();

      expect(cancelCalls, 0);
      expect(find.text(l10n.upcomingServiceTitle), findsWidgets);
      expect(find.text(l10n.cancelBookingCta), findsOneWidget); // still cancellable
    });

    testWidgets('confirming cancellation transitions to the cancelled view and shows a success snackbar', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.cancelBookingCta).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancelBookingCta).last);
      // Bounded pumps (not pumpAndSettle) — the dialog's own close
      // transition needs to finish before its confirm-button text stops
      // shadowing the underlying screen's, but a real advance's loading
      // state can show an indeterminate spinner, which pumpAndSettle would
      // wait on forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.bookingCancelledTitle), findsOneWidget);
      expect(find.text(l10n.bookingCancelledSuccessMessage), findsOneWidget);
      expect(find.byType(StatusTimeline), findsNothing);
      expect(find.text(l10n.cancelBookingCta), findsNothing);
    });

    testWidgets('a second tap while cancellation is in flight does not fire a duplicate request', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      var cancelCalls = 0;
      final completer = Completer<Booking>();
      final repository = _repoWith(booking)
        ..onCancel = (bookingReference) {
          cancelCalls++;
          return completer.future;
        };
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.cancelBookingCta).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancelBookingCta).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cancelCalls, 1);
      // The button shows a spinner and is disabled while in flight.
      await tester.tap(find.byType(TextButton).first);
      await tester.pump();
      expect(cancelCalls, 1);

      completer.complete(_bookingWith(status: BookingStatus.cancelled));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('a failed cancellation shows an error snackbar and keeps the booking upcoming and cancellable', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      final repository = _repoWith(booking)..onCancel = (bookingReference) async => throw Exception('Firestore unavailable');
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.cancelBookingCta).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancelBookingCta).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.statusUpdateFailedMessage), findsOneWidget);
      expect(find.text(l10n.upcomingServiceTitle), findsWidgets);
      expect(find.text(l10n.cancelBookingCta), findsOneWidget); // still there, retryable
    });

    testWidgets('cancelling and simulating an advance can never both be in flight — the simulate button is disabled too', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      final completer = Completer<Booking>();
      final repository = _repoWith(booking)..onCancel = (bookingReference) => completer.future;
      await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.cancelBookingCta).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancelBookingCta).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final simulateButton = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(simulateButton.onPressed, isNull, reason: 'simulate must be disabled while cancel is in flight');

      completer.complete(_bookingWith(status: BookingStatus.cancelled));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('BE-07 — the Complete Payment retry entry point', () {
    testWidgets('upcoming with no payment yet shows the Complete Payment banner', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      expect(find.text(l10n.completePaymentCta), findsOneWidget);
      expect(find.text(l10n.paymentPendingLabel), findsOneWidget);
    });

    testWidgets('upcoming with a paid payment hides the Complete Payment banner', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      final paymentRepo = FakePaymentRepository()
        ..payments[booking.id] = Payment(
          bookingReference: booking.id,
          amount: 124,
          currency: 'SAR',
          status: PaymentStatus.paid,
          method: 'mock_card',
          transactionId: 'MOCKPAY-1',
          createdAt: DateTime.now(),
          statusUpdatedAt: DateTime.now(),
        );
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking), paymentRepository: paymentRepo);
      final l10n = _l10n(tester);

      expect(find.text(l10n.completePaymentCta), findsNothing);
    });

    for (final status in [BookingStatus.technicianOnTheWay, BookingStatus.inProgress, BookingStatus.completed, BookingStatus.cancelled]) {
      testWidgets('$status never shows the Complete Payment banner, regardless of payment state', (tester) async {
        final booking = _bookingWith(
          status: status,
          estimatedArrival: status == BookingStatus.technicianOnTheWay ? DateTime.now().add(const Duration(minutes: 5)) : null,
        );
        await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
        final l10n = _l10n(tester);

        expect(find.text(l10n.completePaymentCta), findsNothing);
      });
    }

    testWidgets('tapping Complete Payment navigates to the Payment screen for this booking', (tester) async {
      final booking = _bookingWith(status: BookingStatus.upcoming);
      await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(booking));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.completePaymentCta));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentScreen), findsOneWidget);
    });
  });
}
