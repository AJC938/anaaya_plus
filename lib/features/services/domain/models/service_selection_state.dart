/// The user's in-progress selection on a Service Details screen: which
/// vehicle (if the service requires one) and which product option (if the
/// service requires one). Scoped per service — see
/// `ServiceSelectionController` in the application layer.
class ServiceSelectionState {
  const ServiceSelectionState({this.selectedVehicleId, this.selectedOptionId});

  final String? selectedVehicleId;
  final String? selectedOptionId;

  ServiceSelectionState copyWith({String? selectedVehicleId, String? selectedOptionId}) {
    return ServiceSelectionState(
      selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    );
  }
}
