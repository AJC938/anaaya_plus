import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/booking_price_breakdown.dart';

/// "Base + option + fees = total" — the Total row gets strong visual
/// hierarchy, everything else is secondary. Never computes anything itself.
class PriceBreakdownCard extends StatelessWidget {
  const PriceBreakdownCard({super.key, required this.breakdown, this.optionLabel});

  final BookingPriceBreakdown breakdown;

  /// The selected option's display name, if any — null (and the row
  /// omitted) when the service has no option.
  final String? optionLabel;

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
          _PriceRow(label: l10n.priceSummaryBaseLabel, value: l10n.priceSar(breakdown.basePrice.toStringAsFixed(0))),
          if (optionLabel != null) ...[
            const SizedBox(height: 6),
            _PriceRow(label: optionLabel!, value: l10n.priceSar(breakdown.optionPrice.toStringAsFixed(0))),
          ],
          const SizedBox(height: 6),
          _PriceRow(label: l10n.priceSummaryFeesLabel, value: l10n.priceSar(breakdown.fees.toStringAsFixed(0))),
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
    final style = emphasize ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style?.copyWith(color: emphasize ? AppColors.primary : null, fontWeight: emphasize ? FontWeight.w700 : null)),
      ],
    );
  }
}
