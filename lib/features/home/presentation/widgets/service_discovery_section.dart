import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_states.dart';

/// Guided entry point for a user who isn't sure which service they need.
/// The real discovery flow doesn't exist yet, so its action is a stub.
class ServiceDiscoverySection extends StatelessWidget {
  const ServiceDiscoverySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.discoveryTitle,
                  style: theme.textTheme.titleMedium?.copyWith(color: AppColors.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.discoverySubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.onPrimary.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.onPrimary, foregroundColor: AppColors.primary),
            onPressed: () => showComingSoonSnackBar(context),
            child: Text(l10n.discoveryCta),
          ),
        ],
      ),
    );
  }
}
