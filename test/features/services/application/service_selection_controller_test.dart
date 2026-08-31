import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/services/application/service_selection_controller.dart';
import 'package:anaaya_plus/features/services/domain/models/service_option.dart';

const _camryOnly = ServiceOption(
  id: 'opt-camry',
  serviceId: 's1',
  nameAr: 'زيت معدني',
  nameEn: 'Mineral',
  descriptionAr: '',
  descriptionEn: '',
  price: 25,
  imageAsset: 'oil_change',
  compatibleVehicleIds: ['v1'],
  isAvailable: true,
);

const _both = ServiceOption(
  id: 'opt-both',
  serviceId: 's1',
  nameAr: 'نصف صناعي',
  nameEn: 'Semi-Synthetic',
  descriptionAr: '',
  descriptionEn: '',
  price: 40,
  imageAsset: 'oil_change',
  compatibleVehicleIds: ['v1', 'v2'],
  isAvailable: true,
);

void main() {
  test('starts with no vehicle or option selected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(serviceSelectionProvider('s1'));
    expect(state.selectedVehicleId, isNull);
    expect(state.selectedOptionId, isNull);
  });

  test('selecting a vehicle keeps a still-compatible option selected', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(serviceSelectionProvider('s1').notifier);

    notifier.selectVehicle('v1', [_camryOnly, _both]);
    notifier.selectOption('opt-both'); // compatible with both v1 and v2
    notifier.selectVehicle('v2', [_camryOnly, _both]);

    final state = container.read(serviceSelectionProvider('s1'));
    expect(state.selectedVehicleId, 'v2');
    expect(state.selectedOptionId, 'opt-both');
  });

  test('changing vehicle clears a now-incompatible option selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(serviceSelectionProvider('s1').notifier);

    notifier.selectVehicle('v1', [_camryOnly, _both]);
    notifier.selectOption('opt-camry'); // only compatible with v1
    notifier.selectVehicle('v2', [_camryOnly, _both]);

    final state = container.read(serviceSelectionProvider('s1'));
    expect(state.selectedVehicleId, 'v2');
    expect(state.selectedOptionId, isNull);
  });

  test('two different services get independent selection state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(serviceSelectionProvider('s1').notifier).selectVehicle('v1', [_camryOnly]);

    expect(container.read(serviceSelectionProvider('s1')).selectedVehicleId, 'v1');
    expect(container.read(serviceSelectionProvider('s6')).selectedVehicleId, isNull);
  });
}
