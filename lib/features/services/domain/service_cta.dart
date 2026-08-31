import 'models/service.dart';
import 'models/service_selection_state.dart';

/// What the Service Details primary CTA should communicate right now.
/// Purely derived from the service's requirements and the current
/// selection — never stored, so it can't drift out of sync.
enum ServiceCtaState { unavailable, selectVehicle, selectOption, ready }

ServiceCtaState resolveCtaState({required Service service, required ServiceSelectionState selection}) {
  if (!service.isActive) return ServiceCtaState.unavailable;
  if (service.requiresVehicle && selection.selectedVehicleId == null) return ServiceCtaState.selectVehicle;
  if (service.requiresProductSelection && selection.selectedOptionId == null) return ServiceCtaState.selectOption;
  return ServiceCtaState.ready;
}
