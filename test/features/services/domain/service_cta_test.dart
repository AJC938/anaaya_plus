import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/services/domain/models/service.dart';
import 'package:anaaya_plus/features/services/domain/models/service_selection_state.dart';
import 'package:anaaya_plus/features/services/domain/service_cta.dart';

Service _service({bool isActive = true, bool requiresVehicle = true, bool requiresProductSelection = false}) {
  return Service(
    id: 's1',
    nameAr: 'تغيير الزيت',
    nameEn: 'Oil Change',
    descriptionAr: '',
    descriptionEn: '',
    category: 'maintenance',
    startingPrice: 89,
    estimatedDuration: const Duration(minutes: 40),
    imageAsset: 'oil_change',
    isActive: isActive,
    requiresVehicle: requiresVehicle,
    requiresProductSelection: requiresProductSelection,
    includedItemsAr: const [],
    includedItemsEn: const [],
  );
}

void main() {
  test('an inactive service is always unavailable, regardless of selection', () {
    final state = resolveCtaState(
      service: _service(isActive: false, requiresVehicle: false),
      selection: const ServiceSelectionState(),
    );
    expect(state, ServiceCtaState.unavailable);
  });

  test('requires vehicle selection first when the service needs one', () {
    final state = resolveCtaState(
      service: _service(requiresVehicle: true, requiresProductSelection: true),
      selection: const ServiceSelectionState(),
    );
    expect(state, ServiceCtaState.selectVehicle);
  });

  test('requires an option once a vehicle is selected, if the service needs one', () {
    final state = resolveCtaState(
      service: _service(requiresVehicle: true, requiresProductSelection: true),
      selection: const ServiceSelectionState(selectedVehicleId: 'v1'),
    );
    expect(state, ServiceCtaState.selectOption);
  });

  test('ready once every requirement is satisfied', () {
    final state = resolveCtaState(
      service: _service(requiresVehicle: true, requiresProductSelection: true),
      selection: const ServiceSelectionState(selectedVehicleId: 'v1', selectedOptionId: 'opt-1'),
    );
    expect(state, ServiceCtaState.ready);
  });

  test('a service with no requirements is ready with an empty selection', () {
    final state = resolveCtaState(
      service: _service(requiresVehicle: false, requiresProductSelection: false),
      selection: const ServiceSelectionState(),
    );
    expect(state, ServiceCtaState.ready);
  });
}
