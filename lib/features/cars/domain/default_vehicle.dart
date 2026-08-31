import 'models/vehicle.dart';

/// Which vehicle should become the new default after a deletion, or null if
/// no promotion is needed (a default already exists among the remaining
/// vehicles, or none remain).
///
/// Only called with the list *after* the deletion — if some vehicle in that
/// list is still marked default, the deleted vehicle wasn't the default and
/// nothing changes. Otherwise the deleted vehicle was the default, and the
/// first remaining vehicle (repository ordering) is promoted.
Vehicle? resolveDefaultAfterDeletion(List<Vehicle> remainingVehicles) {
  if (remainingVehicles.isEmpty) return null;
  if (remainingVehicles.any((vehicle) => vehicle.isDefault)) return null;
  return remainingVehicles.first;
}
