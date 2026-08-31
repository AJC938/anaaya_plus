import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/service.dart';

/// Top of Service Details: image, name, starting price, duration, and the
/// description — the parts of the hierarchy that never depend on selection.
class ServiceHero extends StatelessWidget {
  const ServiceHero({super.key, required this.service});

  final Service service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: AssetVisual(assetKey: service.imageAsset, size: 96)),
        const SizedBox(height: 16),
        Text(service.name(locale), style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              l10n.startingFromPrice(service.startingPrice.toStringAsFixed(0)),
              style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
            Text(
              l10n.estimatedDurationLabel(l10n.durationMinutesLabel(service.estimatedDuration.inMinutes.toString())),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(service.description(locale), style: theme.textTheme.bodyLarge),
      ],
    );
  }
}
