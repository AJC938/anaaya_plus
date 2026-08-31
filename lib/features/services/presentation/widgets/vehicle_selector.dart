import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../../cars/domain/models/vehicle.dart';

/// Vehicle picker on Service Details. Assumes [vehicles] is non-empty —
/// the screen shows a distinct "add a vehicle" prompt instead when it isn't.
///
/// Backed by the real Cars [Vehicle] model (not a Services-local catalog) —
/// this widget only owns the horizontal-card presentation, which is kept
/// separate from Cars' own [VehicleSelector] (a differently-laid-out,
/// vertical list) so integrating with real Cars data didn't change this
/// screen's existing look.
class VehicleSelector extends StatelessWidget {
  const VehicleSelector({super.key, required this.vehicles, required this.selectedVehicleId, required this.onSelect});

  final List<Vehicle> vehicles;
  final String? selectedVehicleId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.selectVehicleAction, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return _VehicleCard(
                vehicle: vehicle,
                selected: vehicle.id == selectedVehicleId,
                onTap: () => onSelect(vehicle.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.selected, required this.onTap});

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      label: vehicle.displayName,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 168,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                AssetVisual(assetKey: vehicle.imageAsset, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vehicle.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                      ),
                      Text(
                        '${vehicle.year}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
