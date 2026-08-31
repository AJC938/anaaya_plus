import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/features/cars/domain/models/vehicle.dart';
import 'package:anaaya_plus/features/cars/presentation/widgets/vehicle_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _camry = Vehicle(
  id: 'v1',
  make: 'Toyota',
  model: 'Camry',
  year: 2023,
  plateNumber: 'ABC 1234',
  imageAsset: 'vehicle_sedan',
  isDefault: true,
);
const _tucson = Vehicle(
  id: 'v2',
  make: 'Hyundai',
  model: 'Tucson',
  year: 2024,
  plateNumber: 'XYZ 5678',
  imageAsset: 'vehicle_suv',
  isDefault: false,
);

/// VehicleSelector needs real localization/theme/directionality context but
/// nothing else from the app — a bare Scaffold under the real MaterialApp
/// config keeps this test isolated from routing and other providers.
Future<void> _pumpSelector(
  WidgetTester tester, {
  required List<Vehicle> vehicles,
  String? selectedVehicleId,
  required ValueChanged<String> onSelect,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        supportedLocales: supportedLocales,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: VehicleSelector(vehicles: vehicles, selectedVehicleId: selectedVehicleId, onSelect: onSelect),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders every vehicle with unselected state', (tester) async {
    await _pumpSelector(tester, vehicles: const [_camry, _tucson], onSelect: (_) {});

    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('Hyundai Tucson'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('shows the selected state on the selected vehicle only', (tester) async {
    await _pumpSelector(tester, vehicles: const [_camry, _tucson], selectedVehicleId: 'v1', onSelect: (_) {});

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('tapping a vehicle invokes the selection callback with its id', (tester) async {
    String? selected;
    await _pumpSelector(tester, vehicles: const [_camry, _tucson], onSelect: (id) => selected = id);

    await tester.tap(find.text('Hyundai Tucson'));
    await tester.pump();

    expect(selected, 'v2');
  });

  testWidgets('shows an empty state when there are no vehicles', (tester) async {
    await _pumpSelector(tester, vehicles: const [], onSelect: (_) {});
    final l10n = AppLocalizations.of(tester.element(find.byType(VehicleSelector)));

    expect(find.text(l10n.noVehiclesToSelectMessage), findsOneWidget);
  });

  testWidgets('renders RTL by default', (tester) async {
    await _pumpSelector(tester, vehicles: const [_camry], onSelect: (_) {});
    expect(Directionality.of(tester.element(find.byType(VehicleSelector))), TextDirection.rtl);
  });
}
