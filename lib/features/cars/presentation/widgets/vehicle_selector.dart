import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/vehicle.dart';

/// Generic, reusable vehicle-selection list — no Services/Booking/Checkout
/// logic. Future features that need to pick a vehicle import this directly
/// rather than reimplementing selection UI.
class VehicleSelector extends StatelessWidget {
  const VehicleSelector({
    super.key,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.onSelect,
    this.showTitle = true,
  });

  final List<Vehicle> vehicles;
  final String? selectedVehicleId;
  final ValueChanged<String> onSelect;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (vehicles.isEmpty) {
      return Container(
        padding: const EdgeInsetsDirectional.all(16),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(l10n.noVehiclesToSelectMessage, style: theme.textTheme.bodyMedium),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(l10n.selectVehicleTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
        ],
        for (final vehicle in vehicles)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: _SelectableVehicleTile(
              vehicle: vehicle,
              selected: vehicle.id == selectedVehicleId,
              onTap: () => onSelect(vehicle.id),
            ),
          ),
      ],
    );
  }
}

class _SelectableVehicleTile extends StatelessWidget {
  const _SelectableVehicleTile({required this.vehicle, required this.selected, required this.onTap});

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      label: selected ? '${vehicle.displayName} — ${l10n.selectedLabel}' : vehicle.displayName,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                AssetVisual(assetKey: vehicle.imageAsset, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(vehicle.displayName, style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      Text('${vehicle.year} • ${vehicle.plateNumber}', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
