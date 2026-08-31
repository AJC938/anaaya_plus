import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/vehicle.dart';

enum _VehicleAction { setDefault, delete }

/// A vehicle in the My Cars list. The default vehicle gets emphasized
/// styling and a badge; secondary actions live in an overflow menu so the
/// card never needs three visible buttons — never destructive on a bare tap
/// of the card itself.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDeleteRequested,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;

  /// Null when [vehicle] is already the default (no action to offer).
  final VoidCallback? onSetDefault;

  /// The screen decides, on tap, whether this vehicle can actually be
  /// deleted (async lookup) before showing a confirm or a blocked dialog.
  final VoidCallback onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDefault = vehicle.isDefault;

    return Semantics(
      container: true,
      label: isDefault ? '${vehicle.displayName} — ${l10n.defaultVehicleBadge}' : vehicle.displayName,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsetsDirectional.all(isDefault ? 18 : 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDefault ? AppColors.primary : AppColors.border, width: isDefault ? 1.5 : 1),
          boxShadow: isDefault
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssetVisual(assetKey: vehicle.imageAsset, size: isDefault ? 64 : 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vehicle.displayName,
                        style: isDefault ? theme.textTheme.headlineMedium?.copyWith(fontSize: 20) : theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text('${vehicle.year} • ${vehicle.plateNumber}', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                PopupMenuButton<_VehicleAction>(
                  tooltip: l10n.moreActionsTooltip,
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (action) {
                    switch (action) {
                      case _VehicleAction.setDefault:
                        onSetDefault?.call();
                      case _VehicleAction.delete:
                        onDeleteRequested();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onSetDefault != null)
                      PopupMenuItem(
                        value: _VehicleAction.setDefault,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.star_outline),
                          title: Text(l10n.setAsDefaultAction),
                        ),
                      ),
                    PopupMenuItem(
                      value: _VehicleAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text(l10n.deleteAction, style: const TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isDefault) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.defaultVehicleBadge,
                      style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(onPressed: onEdit, child: Text(l10n.editAction)),
            ),
          ],
        ),
      ),
    );
  }
}
