import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/section_states.dart';
import '../../../cars/application/cars_providers.dart';
import '../../../cars/presentation/widgets/vehicle_selector.dart';

/// Lets Review's Vehicle section be edited without leaving Booking — reuses
/// Cars' own generic [VehicleSelector] rather than duplicating vehicle
/// picking logic. Returns the newly selected vehicle id, or null if
/// dismissed without a change.
Future<String?> showVehicleEditSheet(BuildContext context, {required String currentVehicleId}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VehicleEditSheet(currentVehicleId: currentVehicleId),
  );
}

class _VehicleEditSheet extends ConsumerWidget {
  const _VehicleEditSheet({required this.currentVehicleId});

  final String currentVehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(carsControllerProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            vehiclesAsync.when(
              loading: () => const LoadingPlaceholder(height: 160),
              error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(carsControllerProvider)),
              data: (vehicles) => VehicleSelector(
                vehicles: vehicles,
                selectedVehicleId: currentVehicleId,
                onSelect: (vehicleId) => Navigator.of(context).pop(vehicleId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
