import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/date_time_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/location_screen.dart';
import 'package:anaaya_plus/features/location/application/current_location_controller.dart';
import 'package:anaaya_plus/features/location/data/location_service.dart';
import 'package:anaaya_plus/features/location/domain/current_location_failure.dart';
import 'package:anaaya_plus/features/location/domain/gps_coordinates.dart';
import 'package:anaaya_plus/features/location/domain/location_permission_status.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/location/domain/reverse_geocode_result.dart';
import 'package:anaaya_plus/features/location/presentation/screens/map_location_picker_screen.dart';
import 'package:anaaya_plus/features/location/presentation/widgets/location_preview_card.dart';
import 'package:anaaya_plus/features/services/presentation/screens/service_details_screen.dart';

import '../../../support/booking_screen_harness.dart';

const _draft = BookingDraft(serviceId: testServiceId, serviceOptionId: 'opt-mineral', vehicleId: 'v1');
final _route = AppRoutes.bookingLocation(testServiceId);

/// A fully controllable [LocationService] fake — no platform channel, no
/// real GPS/network involved. Every field defaults to the happy path so a
/// test only has to set what it actually cares about.
const _resolvedCoordinates = GpsCoordinates(latitude: 21.5433, longitude: 39.1728);

class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.permissionStatus = LocationPermissionStatus.granted,
    LocationPermissionStatus? requestResult,
    this.positionError,
    // Both language fields are the same plain-English string, matching the
    // rest of this test suite's own convention (see booking_screen_harness's
    // testHomeLocation) — so string-equality assertions never depend on
    // Arabic transcription matching; the default test locale is Arabic.
    this.geocode = const ReverseGeocodeResult(
      cityAr: 'Jeddah',
      cityEn: 'Jeddah',
      districtAr: 'Al Rawdah',
      districtEn: 'Al Rawdah',
      addressLineAr: 'Prince Saud Al Faisal St.',
      addressLineEn: 'Prince Saud Al Faisal St.',
    ),
    this.geocodeError,
  }) : requestResult = requestResult ?? permissionStatus;

  LocationPermissionStatus permissionStatus;
  LocationPermissionStatus requestResult;
  Object? positionError;
  ReverseGeocodeResult? geocode;
  Object? geocodeError;
  bool openSettingsCalled = false;

  @override
  Future<LocationPermissionStatus> getPermissionStatus() async => permissionStatus;

  @override
  Future<LocationPermissionStatus> requestPermission() async => requestResult;

  @override
  Future<GpsCoordinates> getCurrentPosition() async {
    final error = positionError;
    if (error != null) throw error;
    return _resolvedCoordinates;
  }

  @override
  Future<ReverseGeocodeResult?> reverseGeocode({required double latitude, required double longitude}) async {
    final error = geocodeError;
    if (error != null) throw error;
    return geocode;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalled = true;
    return true;
  }
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(LocationScreen)));

Future<(ProviderContainer, _FakeLocationService)> _pumpWithFakeLocationService(
  WidgetTester tester, {
  required _FakeLocationService fake,
}) async {
  final container = await pumpBookingScreen(
    tester,
    route: _route,
    draft: _draft,
    extraOverrides: [locationServiceProvider.overrideWithValue(fake)],
  );
  return (container, fake);
}

void main() {
  testWidgets('with no draft, redirects to Service Details instead of showing the screen', (tester) async {
    await pumpBookingScreen(tester, route: _route);
    // The guard's redirect fires from a post-frame callback, then go_router
    // needs another frame to rebuild the stack without LocationScreen — no
    // real async delay is involved here, so pumpAndSettle safely flushes it.
    await tester.pumpAndSettle();

    expect(find.byType(LocationScreen), findsNothing);
    expect(find.byType(ServiceDetailsScreen), findsOneWidget);
  });

  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draft,
      locations: () => Completer<List<BookingLocation>>().future,
    );

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the saved locations once loaded', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draft);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('an empty location list shows an explanatory empty state', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draft, locations: () async => const []);
    final l10n = _l10n(tester);

    expect(find.text(l10n.noSavedLocationsMessage), findsOneWidget);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    var attempt = 0;
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draft,
      locations: () async {
        attempt++;
        if (attempt == 1) throw Exception('mock location failure');
        return const [testHomeLocation];
      },
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('selecting a location updates the draft and shows the preview + continue button', (tester) async {
    final container = await pumpBookingScreen(tester, route: _route, draft: _draft);
    final l10n = _l10n(tester);

    expect(find.byType(LocationPreviewCard), findsNothing);
    expect(find.text(l10n.continueCta), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LocationPreviewCard), findsOneWidget);
    expect(find.text(l10n.continueCta), findsOneWidget);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.location, testHomeLocation);
  });

  testWidgets('asks explicitly where the service should happen — no assumed home location', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draft);
    final l10n = _l10n(tester);

    expect(find.text(l10n.whereToServiceQuestion), findsOneWidget);
  });

  testWidgets('Select on Map opens the real map picker', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draft);
    final l10n = _l10n(tester);

    expect(find.text(l10n.selectOnMapTitle), findsOneWidget);

    await tester.tap(find.text(l10n.selectOnMapTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MapLocationPickerScreen), findsOneWidget);
  });

  testWidgets('tapping continue navigates to Date & Time', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draft);
    final l10n = _l10n(tester);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(l10n.continueCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DateTimeScreen), findsOneWidget);
  });

  testWidgets(
    'Current Location stays usable even when the saved-locations list fails to load — one failure never blocks the other',
    (tester) async {
      await pumpBookingScreen(
        tester,
        route: _route,
        draft: _draft,
        locations: () async => throw Exception('saved-locations always fails in this test'),
        extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
      );
      final l10n = _l10n(tester);

      // The saved-locations section shows its own inline error...
      expect(find.text(l10n.sectionErrorMessage), findsOneWidget);
      // ...but the real current-location action is a completely unrelated
      // device capability and must remain fully usable regardless.
      expect(find.text(l10n.useCurrentLocationCta), findsOneWidget);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationPreviewCard), findsOneWidget);
      expect(find.text(l10n.continueCta), findsOneWidget);
    },
  );

  group('real current-location flow', () {
    testWidgets('shows a tappable "Use Current Location" prompt before anything is fetched', (tester) async {
      await _pumpWithFakeLocationService(tester, fake: _FakeLocationService());
      final l10n = _l10n(tester);

      expect(find.text(l10n.useCurrentLocationCta), findsOneWidget);
      expect(find.byType(LocationPreviewCard), findsNothing);
    });

    testWidgets('a successful fetch resolves the address, auto-selects it, and shows preview + continue', (tester) async {
      final (container, _) = await _pumpWithFakeLocationService(tester, fake: _FakeLocationService());
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // "Al Rawdah, Jeddah" legitimately appears more than once: it's the
      // resolved card's own label, and it separately matches
      // LocationPreviewCard's "district, city" subtitle line.
      expect(find.text('Al Rawdah, Jeddah'), findsWidgets);
      expect(find.byType(LocationPreviewCard), findsOneWidget);
      expect(find.text(l10n.continueCta), findsOneWidget);

      final draft = container.read(bookingDraftControllerProvider);
      expect(draft!.location!.cityEn, 'Jeddah');
      expect(draft.location!.districtEn, 'Al Rawdah');
      expect(draft.location!.latitude, 21.5433);
      expect(draft.location!.longitude, 39.1728);
      // A real GPS+geocoding result must never be flagged as the old mock
      // "simulated" entry.
      expect(draft.location!.isSimulatedCurrentLocation, isFalse);
    });

    testWidgets('permission denied shows a specific message with retry, no open-settings action', (tester) async {
      await _pumpWithFakeLocationService(
        tester,
        fake: _FakeLocationService(permissionStatus: LocationPermissionStatus.denied),
      );
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.locationPermissionDeniedMessage), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text(l10n.openLocationSettingsCta), findsNothing);
    });

    testWidgets('permanently denied permission shows its own message with an open-settings recovery action', (tester) async {
      final (_, fake) = await _pumpWithFakeLocationService(
        tester,
        fake: _FakeLocationService(permissionStatus: LocationPermissionStatus.deniedForever),
      );
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.locationPermissionDeniedForeverMessage), findsOneWidget);
      expect(find.text(l10n.openLocationSettingsCta), findsOneWidget);

      await tester.tap(find.text(l10n.openLocationSettingsCta));
      await tester.pump();

      expect(fake.openSettingsCalled, isTrue);
    });

    testWidgets('disabled location services shows a specific message', (tester) async {
      await _pumpWithFakeLocationService(
        tester,
        fake: _FakeLocationService(permissionStatus: LocationPermissionStatus.serviceDisabled),
      );
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.locationServiceDisabledMessage), findsOneWidget);
    });

    testWidgets('a GPS failure shows the generic unavailable message and allows retry', (tester) async {
      final fake = _FakeLocationService(positionError: const PositionUnavailableException());
      await _pumpWithFakeLocationService(tester, fake: fake);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.currentLocationUnavailableMessage), findsOneWidget);

      // Fixing the underlying condition and retrying must recover, exactly
      // like every other error+retry section in this app.
      fake.positionError = null;
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationPreviewCard), findsOneWidget);
    });

    testWidgets('a reverse-geocoding failure also surfaces as an error, not a silent blank location', (tester) async {
      final fake = _FakeLocationService(geocodeError: Exception('network failure'));
      await _pumpWithFakeLocationService(tester, fake: fake);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(l10n.currentLocationUnavailableMessage), findsOneWidget);
      expect(find.byType(LocationPreviewCard), findsNothing);
    });

    testWidgets('no reverse-geocoding result (a real coordinate with nothing resolvable) still resolves, not an error', (
      tester,
    ) async {
      final (container, _) = await _pumpWithFakeLocationService(tester, fake: _FakeLocationService(geocode: null));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.useCurrentLocationCta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LocationPreviewCard), findsOneWidget);
      final draft = container.read(bookingDraftControllerProvider);
      // Falls back to the raw coordinates rather than a fabricated place
      // name — see buildCurrentLocation's own doc comment.
      expect(draft!.location!.labelEn, '21.5433, 39.1728');
    });
  });
}
