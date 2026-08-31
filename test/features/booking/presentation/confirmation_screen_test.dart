import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/full_screen_message.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/confirmation_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/tracking_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/widgets/booking_summary_card.dart';

import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart';

const _bookingId = 'AN-00001';

final _booking = Booking(
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
  scheduledAt: testSlot.start,
  price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 25, fees: 10, total: 124),
  status: BookingStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

final _route = AppRoutes.bookingConfirmation(testServiceId, _bookingId);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ConfirmationScreen)));

FakeBookingRepository _repoWith(Booking booking) => FakeBookingRepository()..bookings[booking.id] = booking;

void main() {
  testWidgets('shows a loading indicator while the booking resolves', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: _NeverResolvingRepository());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders the booking reference, success message, and summary', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(_booking));
    final l10n = _l10n(tester);

    expect(find.text(l10n.bookingConfirmedTitle), findsWidgets); // AppBar + heading
    expect(find.text(l10n.confirmationSubtitle), findsOneWidget);
    expect(find.text(_bookingId), findsOneWidget);
    expect(find.byType(BookingSummaryCard), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('never implies a payment happened', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(_booking));

    for (final term in ['SAR', 'ريال', 'paid', 'دفع', 'payment', 'دفعت']) {
      expect(find.textContaining(term), findsNothing, reason: 'unexpected payment-related text: $term');
    }
  });

  testWidgets('an unknown booking id shows an error state', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: FakeBookingRepository());

    expect(find.byType(FullScreenMessage), findsOneWidget);
  });

  testWidgets('the AppBar has no back button — the wizard is not re-enterable', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(_booking));

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Track Service navigates to Tracking', (tester) async {
    await pumpBookingScreen(tester, route: _route, bookingRepository: _repoWith(_booking));
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.trackServiceCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TrackingScreen), findsOneWidget);
  });
}

class _NeverResolvingRepository extends FakeBookingRepository {
  @override
  Future<Booking?> fetchBookingById(String id, Locale locale) => Completer<Booking?>().future;
}
