import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// "What's included" — a short bulleted list, not a wall of text.
class IncludedItemsList extends StatelessWidget {
  const IncludedItemsList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.includedTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final item in items)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}
