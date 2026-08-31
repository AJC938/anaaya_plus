import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/application/booking_providers.dart';
import 'package:anaaya_plus/features/booking/data/booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_price_breakdown.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/date_time_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/location_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/review_screen.dart';
import 'package:anaaya_plus/features/payment/presentation/screens/payment_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/widgets/review_section_card.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/presentation/widgets/vehicle_selector.dart';

import '../../../support/booking_fixtures.dart';
import '../../../support/booking_screen_harness.dart';

final _completeDraft = BookingDraft(
  serviceId: testServiceId,
  serviceOptionId: 'opt-mineral',
  vehicleId: 'v1',
  location: testHomeLocation,
  date: testAvailableDate,
  timeSlot: testSlot,
);

final _completeDraftNoOption = BookingDraft(
  serviceId: testServiceId,
  vehicleId: 'v1',
  location: testHomeLocation,
  date: testAvailableDate,
  timeSlot: testSlot,
);

final _route = AppRoutes.bookingReview(testServiceId);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ReviewScreen)));

// Review re-displays info (service name, vehicle name) that Service
// Details — still mounted underneath it in the same Navigator stack — also
// renders (e.g. in its own AppBar/VehicleSelector), so text lookups that
// could plausibly match both screens are scoped to ReviewScreen only.
Finder _inReview(Finder matching) => find.descendant(of: find.byType(ReviewScreen), matching: matching);

Booking _bookingFor(BookingDraft draft) => Booking(
  id: 'AN-00001',
  serviceId: draft.serviceId,
  serviceName: 'Oil Change',
  serviceImageAsset: 'oil_change',
  serviceOptionId: draft.serviceOptionId,
  serviceOptionName: draft.serviceOptionId != null ? 'Mineral' : null,
  vehicleId: draft.vehicleId,
  vehicleName: 'Toyota Camry',
  vehicleYear: 2023,
  plateNumber: 'ABC 1234',
  location: draft.location!,
  scheduledAt: draft.timeSlot!.start,
  price: const BookingPriceBreakdown(basePrice: 89, optionPrice: 25, fees: 10, total: 124),
  status: BookingStatus.upcoming,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets('an incomplete draft (no date/time yet) redirects back to Date & Time', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: BookingDraft(serviceId: testServiceId, vehicleId: 'v1', location: testHomeLocation),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.byType(DateTimeScreen), findsOneWidget);
  });

  testWidgets('renders every selection: service, vehicle, option, location, date/time, and the price breakdown', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _completeDraft);
    final l10n = _l10n(tester);

    expect(find.text(l10n.serviceLabel), findsOneWidget);
    expect(_inReview(find.text('Oil Change')), findsOneWidget);
    expect(find.text(l10n.vehicleLabel), findsOneWidget);
    expect(_inReview(find.text('Toyota Camry')), findsOneWidget);
    expect(find.text(l10n.serviceOptionLabel), findsWidgets); // section label + price row label
    expect(find.text('Mineral'), findsOneWidget);
    expect(find.text(l10n.locationLabel), findsOneWidget);
    expect(find.text('Al Zahra District'), findsOneWidget);
    expect(find.text(l10n.dateTimeLabel), findsOneWidget);
    // Base 89 + Mineral 25 + fees 10 = 124.
    expect(find.text(l10n.priceSar('124')), findsOneWidget);
    expect(find.text(l10n.confirmBookingCta), findsOneWidget);
  });

  testWidgets('resolves a real Firestore-style vehicle id, not just ids shaped like the retired mock catalog', (tester) async {
    // A realistic Firestore auto-generated document id (the exact shape
    // Cars vehicles actually have), not 'v1' — proves Review resolves the
    // selected vehicle via carsControllerProvider regardless of id shape,
    // rather than only happening to work with the test fixtures' short ids.
    const realVehicle = Vehicle(
      id: 'iBUZvrXIH6ZJ6GGQTu5u',
      make: 'Toyota',
      model: 'Camry',
      year: 2023,
      plateNumber: 'ABC 1234',
      imageAsset: 'vehicle_sedan',
      isDefault: true,
    );
    final draft = BookingDraft(
      serviceId: testServiceId,
      serviceOptionId: 'opt-mineral',
      vehicleId: realVehicle.id,
      location: testHomeLocation,
      date: testAvailableDate,
      timeSlot: testSlot,
    );
    await pumpBookingScreen(tester, route: _route, draft: draft, carsVehicles: [realVehicle]);
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsNothing);
    expect(_inReview(find.text('Toyota Camry')), findsOneWidget);
  });

  testWidgets('a service with no option omits the option section and its price row', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _completeDraftNoOption);
    final l10n = _l10n(tester);

    expect(find.text('Mineral'), findsNothing);
    // Base 89 + fees 10 = 99, no option row.
    expect(find.text(l10n.priceSar('99')), findsOneWidget);
  });

  testWidgets('Edit Vehicle opens the shared VehicleSelector sheet and updates the review on selection', (tester) async {
    final container = await pumpBookingScreen(tester, route: _route, draft: _completeDraft);
    final l10n = _l10n(tester);

    final vehicleCard = find.ancestor(of: _inReview(find.text('Toyota Camry')), matching: find.byType(ReviewSectionCard));
    await tester.tap(find.descendant(of: vehicleCard, matching: find.text(l10n.editAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The bottom sheet mounts in the root Overlay, not inside ReviewScreen's
    // own subtree — Service Details underneath also has its own
    // VehicleSelector, so at least 2 exist while the sheet is open; the
    // sheet's own "Hyundai Tucson" is the most recently inserted, i.e. last.
    expect(find.byType(VehicleSelector), findsWidgets);
    await tester.tap(find.text('Hyundai Tucson').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_inReview(find.text('Hyundai Tucson')), findsOneWidget);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.vehicleId, 'v2');
  });

  testWidgets('Edit Location pushes the Location screen without losing other selections', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _completeDraft);
    final l10n = _l10n(tester);

    final locationCard = find.ancestor(of: find.text(l10n.locationLabel), matching: find.byType(ReviewSectionCard));
    await tester.tap(find.descendant(of: locationCard, matching: find.text(l10n.editAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LocationScreen), findsOneWidget);
  });

  testWidgets('Edit Date & Time pushes the Date & Time screen without losing other selections', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _completeDraft);
    final l10n = _l10n(tester);

    final dateCard = find.ancestor(of: find.text(l10n.dateTimeLabel), matching: find.byType(ReviewSectionCard));
    await tester.tap(find.descendant(of: dateCard, matching: find.text(l10n.editAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DateTimeScreen), findsOneWidget);
  });

  testWidgets('confirming shows a loading state and disables duplicate submissions', (tester) async {
    final completer = Completer<Booking>();
    var createCalls = 0;
    final repository = FakeBookingRepository(
      onCreate: (draft, locale) {
        createCalls++;
        return completer.future;
      },
    );
    await pumpBookingScreen(tester, route: _route, draft: _completeDraft, bookingRepository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.confirmBookingCta));
    await tester.pump();

    expect(find.text(l10n.confirmingLabel), findsOneWidget);

    // A second tap while still confirming must not fire a second request.
    await tester.tap(find.text(l10n.confirmingLabel));
    await tester.pump();
    expect(createCalls, 1);

    completer.complete(_bookingFor(_completeDraft));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('a successful booking navigates to Payment (BE-07) and clears the draft', (tester) async {
    final booking = _bookingFor(_completeDraft);
    final repository = FakeBookingRepository(onCreate: (draft, locale) async => booking);
    final container = await pumpBookingScreen(tester, route: _route, draft: _completeDraft, bookingRepository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.confirmBookingCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(container.read(bookingDraftControllerProvider), isNull);
  });

  testWidgets(
    'reached via the real Location -> Date & Time -> Review push chain, confirming still lands on Payment',
    (tester) async {
      // Regression coverage: pumpBookingScreen's `draft:` param seeds the
      // draft directly and go()es straight to Review, so Location/Date&Time
      // are never actually pushed onto the stack — that shape can never
      // reproduce the real bug, where those screens are still mid-exit
      // animation (mounted, still reacting to bookingDraftControllerProvider)
      // when Confirm clears the draft. Only a genuine push-by-push walk like
      // a real user's puts them in the stack for this test to matter.
      final booking = _bookingFor(_completeDraft);
      final repository = FakeBookingRepository(onCreate: (draft, locale) async => booking);
      await pumpBookingScreen(
        tester,
        route: AppRoutes.bookingLocation(testServiceId),
        draft: BookingDraft(serviceId: testServiceId, serviceOptionId: 'opt-mineral', vehicleId: 'v1'),
        bookingRepository: repository,
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(LocationScreen)));
      final locale = Localizations.localeOf(tester.element(find.byType(LocationScreen)));

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(l10n.continueCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DateTimeScreen), findsOneWidget);

      await tester.tap(find.text('${testAvailableDate.day}'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(DateFormat.jm(locale.toString()).format(testSlot.start)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(l10n.continueCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ReviewScreen), findsOneWidget);

      await tester.tap(find.text(l10n.confirmBookingCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PaymentScreen), findsOneWidget);
      expect(find.byType(LocationScreen), findsNothing);
      expect(find.byType(DateTimeScreen), findsNothing);
      expect(find.byType(ReviewScreen), findsNothing);
    },
  );

  testWidgets('a successful booking is immediately visible via bookingsListProvider', (tester) async {
    final booking = _bookingFor(_completeDraft);
    final repository = FakeBookingRepository(onCreate: (draft, locale) async => booking);
    final container = await pumpBookingScreen(tester, route: _route, draft: _completeDraft, bookingRepository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.confirmBookingCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final bookings = await container.read(bookingsListProvider.future);
    expect(bookings.map((b) => b.id), contains(booking.id));
  });

  testWidgets('a generic booking failure shows an error and preserves the draft', (tester) async {
    final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw Exception('mock failure'));
    final container = await pumpBookingScreen(tester, route: _route, draft: _completeDraft, bookingRepository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.confirmBookingCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.bookingFailedMessage), findsOneWidget);
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(container.read(bookingDraftControllerProvider), isNotNull);
    // The button must be usable again, not stuck in a loading state.
    expect(find.text(l10n.confirmBookingCta), findsOneWidget);
  });

  testWidgets('a stale-slot conflict shows the slot-unavailable message and preserves the draft', (tester) async {
    final repository = FakeBookingRepository(onCreate: (draft, locale) async => throw const BookingSlotUnavailableException());
    final container = await pumpBookingScreen(tester, route: _route, draft: _completeDraft, bookingRepository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.confirmBookingCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.slotUnavailableMessage), findsOneWidget);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft, isNotNull);
    expect(draft!.timeSlot, isNull); // the stale slot is cleared, not trusted again
  });
}
