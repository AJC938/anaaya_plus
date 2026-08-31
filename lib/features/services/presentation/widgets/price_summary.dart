import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/pricing.dart';

/// "Base + option = total" — a clear summary, not a checkout screen.
/// Rendered by the screen only for services where a selection can actually
/// change the price.
class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.breakdown, this.optionName});

  final PriceBreakdown breakdown;

  /// Localized display name of the selected option, if any.
  final String? optionName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriceRow(
            label: l10n.priceSummaryBaseLabel,
            value: l10n.priceSar(breakdown.basePrice.toStringAsFixed(0)),
          ),
          if (optionName != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6),
              child: _PriceRow(label: optionName!, value: '+${l10n.priceSar(breakdown.optionPrice.toStringAsFixed(0))}'),
            ),
          const Padding(padding: EdgeInsetsDirectional.symmetric(vertical: 10), child: Divider(height: 1)),
          _PriceRow(
            label: l10n.priceSummaryTotalLabel,
            value: l10n.priceSar(breakdown.total.toStringAsFixed(0)),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style?.copyWith(color: emphasize ? AppColors.primary : null)),
      ],
    );
  }
}
