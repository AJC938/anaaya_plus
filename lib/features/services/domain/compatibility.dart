import 'models/service_option.dart';

/// Options available and compatible with [vehicleId], in catalog order.
/// Returns an empty list when no vehicle is selected yet — callers should
/// gate this on vehicle selection first rather than relying on the result.
List<ServiceOption> compatibleOptions(List<ServiceOption> options, String? vehicleId) {
  if (vehicleId == null) return const [];
  return options.where((option) => option.isAvailable && option.isCompatibleWith(vehicleId)).toList();
}
