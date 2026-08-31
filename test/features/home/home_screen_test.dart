import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/tracking_screen.dart';
import 'package:anaaya_plus/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/cars_screen.dart';
import 'package:anaaya_plus/features/home/application/home_providers.dart';
import 'package:anaaya_plus/core/countdown.dart';
import 'package:anaaya_plus/features/home/domain/models/home_booking_summary.dart';
import 'package:anaaya_plus/features/home/domain/models/home_user.dart';
import 'package:anaaya_plus/features/home/domain/models/offer.dart';
import 'package:anaaya_plus/features/home/domain/models/service_item.dart';
import 'package:anaaya_plus/features/home/domain/models/vehicle_summary.dart';
import 'package:anaaya_plus/features/home/presentation/widgets/booking_status_card.dart';
import 'package:anaaya_plus/features/services/presentation/screens/service_details_screen.dart';
import 'package:anaaya_plus/features/services/presentation/screens/services_screen.dart';

import '../../support/auth_fixtures.dart';

// Mock content is authored in plain English here (not copied from the .arb
// files) so string-equality assertions never depend on Arabic transcription
// matching exactly — only genuine UI-chrome strings are compared, and those
// are always read back through AppLocalizations rather than retyped.
const _vehicle = VehicleSummary(
  id: 'v1',
  make: 'Toyota',
  model: 'Camry',
  year: 2023,
  plateNumber: 'ABC 1234',
  imageAsset: 'vehicle_sedan',
);

const _services = [
  ServiceItem(id: 's1', name: 'Oil Change', category: 'maintenance', startingPrice: 89, imageAsset: 'oil_change'),
  ServiceItem(id: 's2', name: 'Tires', category: 'tires', startingPrice: 99, imageAsset: 'tires'),
];

const _offers = [
  Offer(
    id: 'o1',
    title: 'Free Car Wash',
    description: 'Get a free wash.',
    imageAsset: 'car_wash',
    badgeLabel: 'Free',
    ctaLabel: 'Book Now',
  ),
];

/// Pumps the real app with Home's data providers overridden to known mock
/// values — none of which touch the live countdown ticker unless a test
/// explicitly asks for an upcoming/on-the-way booking.
Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  HomeUser? user,
  List<VehicleSummary>? vehicles,
  HomeBookingSummary? Function()? booking,
  List<ServiceItem>? services,
  List<Offer>? offers,
  Future<List<ServiceItem>> Function(Ref ref)? servicesOverride,
}) async {
  final container = ProviderContainer(
    // Riverpod auto-retries a failed FutureProvider a few times with
    // backoff; disabled here so a mock failure stays observable until the
    // test (or the app's own Retry button) explicitly invalidates it.
    retry: (retryCount, error) => null,
    overrides: [
      homeUserProvider.overrideWith((ref) async => user ?? const HomeUser(id: 'u1', name: 'Sara')),
      homeVehiclesProvider.overrideWith((ref) async => vehicles ?? const [_vehicle]),
      homeActiveBookingProvider.overrideWith((ref) async => booking?.call()),
      homeServicesProvider.overrideWith(servicesOverride ?? (ref) async => services ?? _services),
      homeOffersProvider.overrideWith((ref) async => offers ?? _offers),
    ],
  );
  addTearDown(container.dispose);
  await _useTallViewport(tester);
  final router = createAppRouter(authRepository: FakeAuthRepository(uid: testUid));
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  // appRouter is a process-wide singleton, so normalize to Home regardless
  // of where a previous test in this file left it. Each container defaults
  // to Arabic, so the nav label is always 'الرئيسية' at this point.
  await tester.tap(find.text('الرئيسية'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

/// Home is a full scrollable dashboard, taller than the default 800x600 test
/// surface. Rather than driving scroll gestures in every test, give the
/// surface enough height to lay out (and thus build) the whole screen —
/// `ListView` only builds children within the viewport + cache extent.
Future<void> _useTallViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Reads localized UI-chrome strings from the currently mounted app, so
/// assertions never rely on retyped Arabic/English literals staying in
/// sync with the .arb source by hand.
AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.text('Oil Change')));
}

void main() {
  testWidgets('Home renders correctly with its main sections', (tester) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);

    expect(find.textContaining('Sara'), findsOneWidget);
    expect(find.text('Oil Change'), findsOneWidget);
    expect(find.text('Free Car Wash'), findsOneWidget);
    expect(find.text(l10n.quickAccessCarsSubtitle), findsOneWidget);
    expect(find.text(l10n.quickAccessBookingsSubtitle), findsOneWidget);
  });

  testWidgets('Arabic is the default locale and renders RTL', (tester) async {
    await _pumpHome(tester);
    expect(Directionality.of(tester.element(find.text('Oil Change'))), TextDirection.rtl);
  });

  testWidgets('English renders LTR once selected', (tester) async {
    final container = await _pumpHome(tester);
    container.read(localeProvider.notifier).set(const Locale('en'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(Directionality.of(tester.element(find.text('Oil Change'))), TextDirection.ltr);
  });

  testWidgets('Services render from structured mock data', (tester) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);
    expect(find.text('Oil Change'), findsOneWidget);
    expect(find.text('Tires'), findsOneWidget);
    expect(find.text(l10n.startingFromPrice('89')), findsOneWidget);
  });

  testWidgets('Upcoming booking appears when a booking exists', (tester) async {
    final scheduledAt = DateTime.now().add(const Duration(hours: 2));
    await _pumpHome(
      tester,
      booking: () => HomeBookingSummary(
        id: 'b1',
        serviceName: 'Oil Change',
        serviceImageAsset: 'oil_change',
        vehicleName: 'Toyota Camry',
        vehicleYear: 2023,
        scheduledAt: scheduledAt,
        status: HomeBookingStatus.upcoming,
      ),
    );
    final l10n = _l10n(tester);

    expect(find.byType(BookingStatusCard), findsOneWidget);
    expect(find.text(l10n.upcomingServiceTitle), findsOneWidget);
  });

  testWidgets('Track Service navigates to the real Tracking screen, not a dead end', (tester) async {
    // 'demo-upcoming' is one of MockBookingRepository's fixed demo bookings
    // — a real, resolvable booking, not just a Home-local id.
    await _pumpHome(
      tester,
      booking: () => HomeBookingSummary(
        id: 'demo-upcoming',
        serviceName: 'Oil Change',
        serviceImageAsset: 'oil_change',
        vehicleName: 'Toyota Camry',
        vehicleYear: 2023,
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        status: HomeBookingStatus.upcoming,
      ),
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.trackServiceCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TrackingScreen), findsOneWidget);
  });

  testWidgets('Booking card is absent when there is no active booking', (tester) async {
    await _pumpHome(tester, booking: () => null);
    final l10n = _l10n(tester);

    expect(find.byType(BookingStatusCard), findsNothing);
    expect(find.text(l10n.upcomingServiceTitle), findsNothing);
  });

  testWidgets('No-vehicle state prompts to add a vehicle and navigates to Cars', (tester) async {
    await _pumpHome(tester, vehicles: const []);
    final l10n = _l10n(tester);

    expect(find.text(l10n.addVehiclePrompt), findsOneWidget);
    expect(find.byType(BookingStatusCard), findsNothing);

    await tester.tap(find.text(l10n.addVehicleCta));
    await tester.pump();
    // Lands on the real Cars screen, backed by the real (unoverridden) mock
    // repository — give its latency time to flush so no timer is left
    // pending when the test tears down.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CarsScreen), findsOneWidget);
  });

  testWidgets('Quick access My Cars navigates to the Cars destination', (tester) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);

    // Tap the card via its unique subtitle to avoid the ambiguity with the
    // bottom-nav label, which intentionally shares the same title text.
    await tester.tap(find.text(l10n.quickAccessCarsSubtitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CarsScreen), findsOneWidget);
  });

  testWidgets('Quick access My Bookings navigates to the Bookings destination', (tester) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.quickAccessBookingsSubtitle));
    // A bare pump first so BookingsScreen actually mounts (and its mock
    // repository call starts) before the clock is advanced — otherwise the
    // duration-pump below elapses time before the 400ms timer even exists.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BookingsScreen), findsOneWidget);
  });

  testWidgets('A section error renders without destroying the rest of Home, and retry recovers it', (
    tester,
  ) async {
    var attempt = 0;
    await _pumpHome(
      tester,
      servicesOverride: (ref) async {
        attempt++;
        if (attempt == 1) {
          throw Exception('mock services failure');
        }
        return _services;
      },
    );
    final l10n = AppLocalizations.of(tester.element(find.text('Free Car Wash')));

    // Services failed, but the rest of Home (offers, quick access) is fine.
    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);
    expect(find.text('Free Car Wash'), findsOneWidget);
    expect(find.text(l10n.quickAccessCarsSubtitle), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.sectionErrorMessage), findsNothing);
    expect(find.text('Oil Change'), findsOneWidget);
  });

  testWidgets('View All Services navigates to the Services list', (tester) async {
    await _pumpHome(tester);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.viewAll));
    // Lands on the real Services screen, backed by the real (unoverridden)
    // mock repository. A fresh Future.delayed timer started mid-build isn't
    // captured by an elapse that already began, so each async stage needs
    // its own bare pump() before the duration-pump that flushes it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ServicesScreen), findsOneWidget);
  });

  testWidgets('A Home service card navigates directly to its Service Details', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Oil Change'));
    // Service Details fetches sequentially: the service itself first, then
    // (once it's known to require one) its options and compatible vehicles
    // — each stage's timer is only created once the previous stage's
    // rebuild happens, so it needs its own pump() + duration-pump pair.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ServiceDetailsScreen), findsOneWidget);
  });

  group('countdown never shows negative time', () {
    test('remainingUntil clamps a past target to zero', () {
      final past = DateTime.now().subtract(const Duration(hours: 3));
      expect(remainingUntil(past), Duration.zero);
    });

    test('formatCountdown never produces a negative string', () {
      expect(formatCountdown(Duration.zero), '0m');
      expect(formatCountdown(const Duration(minutes: -5)), '0m');
      expect(formatCountdown(const Duration(hours: 2, minutes: 18)), '2h 18m');
    });
  });
}
