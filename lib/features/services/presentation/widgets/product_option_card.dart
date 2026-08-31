import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/service_option.dart';

/// A selectable product/option (e.g. an oil grade). Selection is never
/// color-only: a filled check icon and a label swap ("Select" → "Selected")
/// both change too.
class ProductOptionCard extends StatelessWidget {
  const ProductOptionCard({super.key, required this.option, required this.selected, required this.onSelect});

  final ServiceOption option;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Semantics(
      selected: selected,
      button: true,
      label: option.name(locale),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsetsDirectional.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                AssetVisual(assetKey: option.imageAsset, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.name(locale), style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        option.description(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${l10n.priceSar(option.price.toStringAsFixed(0))}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
                      const SizedBox(height: 2),
                      Text(l10n.selectedLabel, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                    ],
                  )
                else
                  OutlinedButton(onPressed: onSelect, child: Text(l10n.selectOptionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
