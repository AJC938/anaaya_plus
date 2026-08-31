import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/app.dart';
import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/cars/application/cars_providers.dart';
import 'package:anaaya_plus/features/cars/data/mock_cars_repository.dart';
import 'package:anaaya_plus/features/services/application/services_providers.dart';
import 'package:anaaya_plus/features/services/domain/models/service.dart';
import 'package:anaaya_plus/features/services/domain/models/service_option.dart';
import 'package:anaaya_plus/features/services/presentation/screens/service_details_screen.dart';
import 'package:anaaya_plus/features/services/presentation/screens/services_screen.dart';

import '../../support/auth_fixtures.dart';
import '../../support/instant_home_overrides.dart';

// Both language fields are the same plain-English string here (matching
// Home's own fixture convention) so string-equality assertions never depend
// on Arabic transcription matching — the default test locale is Arabic.
const _oilChange = Service(
  id: 's1',
  nameAr: 'Oil Change',
  nameEn: 'Oil Change',
  descriptionAr: 'Oil change description',
  descriptionEn: 'Oil change description',
  category: 'maintenance',
  startingPrice: 89,
  estimatedDuration: Duration(minutes: 40),
  imageAsset: 'oil_change',
  isActive: true,
  requiresVehicle: true,
  requiresProductSelection: true,
  includedItemsAr: ['Item 1'],
  includedItemsEn: ['Item 1'],
);

const _tires = Service(
  id: 's5',
  nameAr: 'Tires',
  nameEn: 'Tires',
  descriptionAr: 'Tires description',
  descriptionEn: 'Tires description',
  category: 'tires',
  startingPrice: 99,
  estimatedDuration: Duration(minutes: 45),
  imageAsset: 'tires',
  isActive: true,
  requiresVehicle: true,
  requiresProductSelection: false,
  includedItemsAr: [],
  includedItemsEn: [],
);

Future<ProviderContainer> _pumpServicesScreen(
  WidgetTester tester, {
  Future<List<Service>> Function(Ref ref)? servicesOverride,
}) async {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      ...instantHomeOverrides(),
      // Details isn't under test here, but a tap can navigate into it — give
      // it harmless instant data so no real repository timer is created.
      serviceByIdProvider.overrideWith((ref, id) async => null),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: testUid)),
      carsRepositoryProvider.overrideWithValue(MockCarsRepository(seedVehicles: const [])),
      serviceOptionsProvider.overrideWith((ref, id) async => const <ServiceOption>[]),
      if (servicesOverride != null) servicesListProvider.overrideWith(servicesOverride),
    ],
  );
  addTearDown(container.dispose);
  // A fresh router per test — the shared appRouter singleton retains nested
  // branch state (by design, for real navigation), which would otherwise
  // leak a previous test's pushed route into this one.
  final router = createAppRouter(authRepository: FakeAuthRepository(uid: testUid));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: AnaayaPlusApp(router: router)),
  );
  await tester.pump();
  router.go(AppRoutes.services());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ServicesScreen)));

void main() {
  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    await _pumpServicesScreen(tester, servicesOverride: (ref) => Completer<List<Service>>().future);

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders the populated catalog from structured mock data', (tester) async {
    await _pumpServicesScreen(tester, servicesOverride: (ref) async => [_oilChange, _tires]);

    expect(find.text('Oil Change'), findsOneWidget);
    expect(find.text('Tires'), findsOneWidget);
  });

  testWidgets('shows a useful empty state when there are no services', (tester) async {
    await _pumpServicesScreen(tester, servicesOverride: (ref) async => []);
    final l10n = _l10n(tester);

    expect(find.text(l10n.servicesEmptyMessage), findsOneWidget);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    var attempt = 0;
    await _pumpServicesScreen(
      tester,
      servicesOverride: (ref) async {
        attempt++;
        if (attempt == 1) throw Exception('mock services failure');
        return [_oilChange];
      },
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.sectionErrorMessage), findsNothing);
    expect(find.text('Oil Change'), findsOneWidget);
  });

  testWidgets('Arabic is the default locale and renders RTL', (tester) async {
    await _pumpServicesScreen(tester, servicesOverride: (ref) async => [_oilChange]);
    expect(Directionality.of(tester.element(find.byType(ServicesScreen))), TextDirection.rtl);
  });

  testWidgets('tapping a service navigates to its Service Details', (tester) async {
    await _pumpServicesScreen(tester, servicesOverride: (ref) async => [_oilChange]);

    await tester.tap(find.text('Oil Change'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ServiceDetailsScreen), findsOneWidget);
  });
}
