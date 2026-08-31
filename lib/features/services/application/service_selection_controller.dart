import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/compatibility.dart';
import '../domain/models/service_option.dart';
import '../domain/models/service_selection_state.dart';

/// Selection state for one Service Details screen, scoped per [serviceId] —
/// `.autoDispose.family` gives every service its own fresh controller and
/// discards it when the screen is left, so selections never leak between
/// services.
class ServiceSelectionController extends Notifier<ServiceSelectionState> {
  ServiceSelectionController(this.serviceId);

  final String serviceId;

  @override
  ServiceSelectionState build() => const ServiceSelectionState();

  /// Changing vehicle must never leave an incompatible option selected —
  /// see the Vehicle Selection Behavior spec. [allOptions] is passed in
  /// (rather than fetched here) so this stays a pure state transition,
  /// independent of the repository/providers and easy to unit test.
  void selectVehicle(String vehicleId, List<ServiceOption> allOptions) {
    final stillValid = compatibleOptions(
      allOptions,
      vehicleId,
    ).any((option) => option.id == state.selectedOptionId);
    state = ServiceSelectionState(
      selectedVehicleId: vehicleId,
      selectedOptionId: stillValid ? state.selectedOptionId : null,
    );
  }

  void selectOption(String optionId) {
    state = state.copyWith(selectedOptionId: optionId);
  }
}

final serviceSelectionProvider =
    NotifierProvider.autoDispose.family<ServiceSelectionController, ServiceSelectionState, String>(
      ServiceSelectionController.new,
    );
