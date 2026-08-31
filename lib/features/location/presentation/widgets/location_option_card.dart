import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/booking_location.dart';

enum _LocationCardAction { edit, delete }

/// One selectable saved/simulated location in the pick list. Selection is
/// never color-only: a filled check icon changes too.
///
/// [onEdit]/[onDeleteRequested] are both optional and independent of each
/// other — passing neither (the current-location card's own use) renders
/// exactly as before, with no menu at all. Only the saved-locations list
/// passes both, showing a `PopupMenuButton` matching `VehicleCard`'s own
/// edit/delete affordance for Cars.
class LocationOptionCard extends StatelessWidget {
  const LocationOptionCard({
    super.key,
    required this.location,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDeleteRequested,
  });

  final BookingLocation location;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Semantics(
      selected: selected,
      button: true,
      label: location.label(locale),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(
                  location.isSimulatedCurrentLocation ? Icons.my_location : Icons.location_on_outlined,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(location.label(locale), style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      Text(
                        '${location.district(locale)} • ${location.city(locale)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                if (onEdit != null || onDeleteRequested != null) _buildMenu(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_LocationCardAction>(
      tooltip: l10n.moreActionsTooltip,
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      onSelected: (action) {
        switch (action) {
          case _LocationCardAction.edit:
            onEdit?.call();
          case _LocationCardAction.delete:
            onDeleteRequested?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: _LocationCardAction.edit,
            child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.edit_outlined), title: Text(l10n.editAction)),
          ),
        if (onDeleteRequested != null)
          PopupMenuItem(
            value: _LocationCardAction.delete,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l10n.deleteAction, style: const TextStyle(color: AppColors.error)),
            ),
          ),
      ],
    );
  }
}
