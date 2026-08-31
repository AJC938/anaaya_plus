import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/full_screen_message.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/pricing.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/tracking_screen.dart';
import 'package:anaaya_plus/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:anaaya_plus/features/services/presentation/screens/services_screen.dart';

import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart';

final _route = AppRoutes.bookings;

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(BookingsScreen)));

Booking _booking({required String id, required BookingStatus status, required DateTime scheduledAt}) {
  return Booking(
    id: id,
    serviceId: 's1',
    serviceName: 'Oil Change',
    serviceImageAsset: 'oil_change',
    vehicleId: 'v1',
    vehicleName: 'Toyota Camry',
    vehicleYear: 2023,
    plateNumber: 'ABC 1234',
    location: testLocation,
    scheduledAt: scheduledAt,
    price: calculateBookingPrice(basePrice: 89),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      bookingRepository: FakeBookingRepository(onGetBookings: () => Completer<List<Booking>>().future),
    );

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    var attempt = 0;
    final repository = FakeBookingRepository(
      onGetBookings: () async {
        attempt++;
        if (attempt == 1) throw Exception('mock bookings failure');
        return [_booking(id: 'AN-1', status: BookingStatus.upcoming, scheduledAt: DateTime(2026, 5, 1))];
      },
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
    final l10n = _l10n(tester);

    expect(find.byType(FullScreenMessage), findsOneWidget);
    expect(find.text(l10n.unableToLoadBookingsMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Oil Change'), findsOneWidget);
  });

  testWidgets('an empty booking list shows the empty state', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: FakeBookingRepository(onGetBookings: () async => const []));
    final l10n = _l10n(tester);

    expect(find.text(l10n.noBookingsTitle), findsOneWidget);
  });

  testWidgets('tapping the empty-state CTA navigates to the Services catalog, the real booking entry point', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: FakeBookingRepository(onGetBookings: () async => const []));
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.bookServiceCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Lands on Services itself (where Service → Vehicle → Option selection
    // actually starts), not just back on the Home dashboard — a bare
    // `context.go(AppRoutes.home)` would leave the user needing an extra tap.
    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.byType(BookingsScreen), findsNothing);
  });

  testWidgets('active, completed, and cancelled bookings render in their own sections', (tester) async {
    final repository = FakeBookingRepository(
      onGetBookings: () async => [
        _booking(id: 'AN-active', status: BookingStatus.upcoming, scheduledAt: DateTime(2026, 5, 1)),
        _booking(id: 'AN-done', status: BookingStatus.completed, scheduledAt: DateTime(2026, 4, 1)),
        _booking(id: 'AN-cancelled', status: BookingStatus.cancelled, scheduledAt: DateTime(2026, 3, 1)),
      ],
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
    final l10n = _l10n(tester);

    expect(find.text(l10n.activeBookingsSectionTitle), findsOneWidget);
    expect(find.text(l10n.completedBookingsSectionTitle), findsOneWidget);
    expect(find.text(l10n.cancelledBookingsSectionTitle), findsOneWidget);
    expect(find.text('Oil Change'), findsNWidgets(3));
  });

  testWidgets('an empty status group has no section header', (tester) async {
    final repository = FakeBookingRepository(
      onGetBookings: () async => [_booking(id: 'AN-active', status: BookingStatus.upcoming, scheduledAt: DateTime(2026, 5, 1))],
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: repository);
    final l10n = _l10n(tester);

    expect(find.text(l10n.activeBookingsSectionTitle), findsOneWidget);
    expect(find.text(l10n.completedBookingsSectionTitle), findsNothing);
    expect(find.text(l10n.cancelledBookingsSectionTitle), findsNothing);
  });

  testWidgets('tapping a booking navigates to Tracking', (tester) async {
    final repository = FakeBookingRepository(
      onGetBookings: () async => [_booking(id: 'AN-active', status: BookingStatus.upcoming, scheduledAt: DateTime(2026, 5, 1))],
    );
    await pumpBookingScreen(tester, route: _route, bookingRepository: repository);

    await tester.tap(find.text('Oil Change'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TrackingScreen), findsOneWidget);
  });
}
