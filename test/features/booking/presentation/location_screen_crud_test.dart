import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/location_screen.dart';
import 'package:anaaya_plus/features/location/application/current_location_controller.dart';
import 'package:anaaya_plus/features/location/data/location_repository.dart';
import 'package:anaaya_plus/features/location/data/location_service.dart';
import 'package:anaaya_plus/features/location/domain/gps_coordinates.dart';
import 'package:anaaya_plus/features/location/domain/location_permission_status.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/location/domain/reverse_geocode_result.dart';
import 'package:anaaya_plus/features/location/presentation/screens/map_location_picker_screen.dart';
import 'package:anaaya_plus/features/location/presentation/widgets/location_preview_card.dart';

import '../../../support/booking_screen_harness.dart';

const _draft = BookingDraft(serviceId: testServiceId, serviceOptionId: 'opt-mineral', vehicleId: 'v1');

/// A no-latency, no-platform-channel [LocationService] stand-in — the map
/// picker's `_confirmLocation` calls this directly (not through
/// [CurrentLocationController]), so every test in this file that opens the
/// picker needs it overridden, exactly like `location_screen_test.dart`'s
/// own `_FakeLocationService`.
class _FakeLocationService implements LocationService {
  @override
  Future<LocationPermissionStatus> getPermissionStatus() async => LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async => LocationPermissionStatus.granted;

  @override
  Future<GpsCoordinates> getCurrentPosition() async => const GpsCoordinates(latitude: 21.5433, longitude: 39.1728);

  @override
  Future<ReverseGeocodeResult?> reverseGeocode({required double latitude, required double longitude}) async {
    return const ReverseGeocodeResult(
      cityAr: 'Jeddah',
      cityEn: 'Jeddah',
      districtAr: 'Al Rawdah',
      districtEn: 'Al Rawdah',
      addressLineAr: 'Prince Saud Al Faisal St.',
      addressLineEn: 'Prince Saud Al Faisal St.',
    );
  }

  @override
  Future<bool> openAppSettings() async => true;
}

/// A genuinely mutable [LocationRepository] fake — the shared harness's own
/// default fake deliberately throws on every mutation (see its own doc
/// comment), so the save/edit/delete flows exercised here need their own
/// richer fake, wired in via `pumpBookingScreen`'s `locationRepository`
/// parameter rather than stretching the harness's simple fetch-only
/// mechanism.
class _MutableLocationRepository implements LocationRepository {
  _MutableLocationRepository(List<BookingLocation> seed) : _locations = List.of(seed);

  final List<BookingLocation> _locations;
  bool failNextMutation = false;
  int _nextId = 0;

  @override
  Future<List<BookingLocation>> fetchSavedLocations() async => List.unmodifiable(_locations);

  @override
  Future<BookingLocation> addLocation(BookingLocation location) async {
    if (failNextMutation) {
      failNextMutation = false;
      throw Exception('mock add failure');
    }
    final created = BookingLocation(
      id: 'loc-new-${_nextId++}',
      labelAr: location.labelAr,
      labelEn: location.labelEn,
      cityAr: location.cityAr,
      cityEn: location.cityEn,
      districtAr: location.districtAr,
      districtEn: location.districtEn,
      addressLineAr: location.addressLineAr,
      addressLineEn: location.addressLineEn,
      latitude: location.latitude,
      longitude: location.longitude,
      isSimulatedCurrentLocation: false,
    );
    _locations.add(created);
    return created;
  }

  @override
  Future<BookingLocation> updateLocation(BookingLocation location) async {
    if (failNextMutation) {
      failNextMutation = false;
      throw Exception('mock update failure');
    }
    final index = _locations.indexWhere((l) => l.id == location.id);
    if (index == -1) throw StateError('Location ${location.id} not found');
    _locations[index] = location;
    return location;
  }

  @override
  Future<void> deleteLocation(String id) async {
    if (failNextMutation) {
      failNextMutation = false;
      throw Exception('mock delete failure');
    }
    _locations.removeWhere((l) => l.id == id);
  }
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(LocationScreen)));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('save flow: pick a point on the map, name it, and it appears in the saved list', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation]);
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.selectOnMapTitle));
    await _settle(tester);
    expect(find.byType(MapLocationPickerScreen), findsOneWidget);

    await tester.tap(find.text(l10n.confirmLocationCta));
    await _settle(tester);
    expect(find.byType(LocationPreviewCard), findsOneWidget);

    await tester.enterText(find.byType(TextField), "Friend's House");
    await tester.tap(find.text(l10n.saveLocationCta));
    await tester.pumpAndSettle();

    expect(find.byType(MapLocationPickerScreen), findsNothing);
    expect(find.text("Friend's House"), findsWidgets);
    expect(repo._locations.any((loc) => loc.labelEn == "Friend's House"), isTrue);
  });

  testWidgets('save flow: an empty label is rejected before saving', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation]);
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.selectOnMapTitle));
    await _settle(tester);
    await tester.tap(find.text(l10n.confirmLocationCta));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text(l10n.saveLocationCta));
    await tester.pump();

    expect(find.text(l10n.locationLabelRequiredError), findsOneWidget);
    expect(find.byType(MapLocationPickerScreen), findsOneWidget);
    expect(repo._locations, hasLength(1));
  });

  testWidgets('save flow: a repository failure keeps the picker open with a controlled error, not a crash', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation])..failNextMutation = true;
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.selectOnMapTitle));
    await _settle(tester);
    await tester.tap(find.text(l10n.confirmLocationCta));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Somewhere');
    await tester.tap(find.text(l10n.saveLocationCta));
    await _settle(tester);

    expect(find.text(l10n.saveLocationErrorMessage), findsOneWidget);
    expect(find.byType(MapLocationPickerScreen), findsOneWidget);
    expect(repo._locations, hasLength(1));
  });

  testWidgets('edit flow: opening edit prefills the existing label, and saving updates the same document', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation, testWorkLocation]);
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editAction).first);
    await _settle(tester);

    expect(find.byType(MapLocationPickerScreen), findsOneWidget);

    // Edit mode still starts on the picking phase (centered on the existing
    // point) — the label field only appears after confirming, same as a
    // brand-new pick.
    await tester.tap(find.text(l10n.confirmLocationCta));
    await _settle(tester);
    final labelField = tester.widget<TextField>(find.byType(TextField));
    expect(labelField.controller!.text, 'Home');

    await tester.enterText(find.byType(TextField), 'Home Sweet Home');
    await tester.tap(find.text(l10n.saveChangesLocationCta));
    await tester.pumpAndSettle();

    expect(find.byType(MapLocationPickerScreen), findsNothing);
    expect(repo._locations, hasLength(2));
    expect(repo._locations.firstWhere((loc) => loc.id == 'loc-home').labelEn, 'Home Sweet Home');
    // The document id is preserved — edit never creates a second document.
    expect(repo._locations.map((loc) => loc.id), containsAll(['loc-home', 'loc-work']));
  });

  testWidgets('delete flow: requires confirmation, and cancelling leaves the location untouched', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation, testWorkLocation]);
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteAction).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.deleteLocationTitle), findsOneWidget);

    await tester.tap(find.text(l10n.cancelAction));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(repo._locations, hasLength(2));
  });

  testWidgets('delete flow: confirming removes the item from the list without a restart', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation, testWorkLocation]);
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteAction).last);
    await tester.pumpAndSettle();

    expect(find.text(l10n.locationDeletedMessage), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
    expect(repo._locations.map((loc) => loc.id), ['loc-work']);
  });

  testWidgets('delete flow: a repository failure keeps the item visible with a controlled error', (tester) async {
    final repo = _MutableLocationRepository([testHomeLocation, testWorkLocation])..failNextMutation = true;
    await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.deleteAction).last);
    await _settle(tester);

    expect(find.text(l10n.deleteLocationErrorMessage), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(repo._locations, hasLength(2));
  });

  testWidgets('a newly saved map location can be selected and carried through to the draft', (tester) async {
    final repo = _MutableLocationRepository([]);
    final container = await pumpBookingScreen(
      tester,
      route: AppRoutes.bookingLocation(testServiceId),
      draft: _draft,
      locationRepository: repo,
      extraOverrides: [locationServiceProvider.overrideWithValue(_FakeLocationService())],
    );
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.selectOnMapTitle));
    await _settle(tester);
    await tester.tap(find.text(l10n.confirmLocationCta));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'New Spot');
    await tester.tap(find.text(l10n.saveLocationCta));
    await _settle(tester);

    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.location!.labelEn, 'New Spot');
    expect(find.text(l10n.continueCta), findsOneWidget);
  });
}
