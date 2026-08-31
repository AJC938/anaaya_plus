import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// One editable fact on Booking Review: a visual, a label, the selected
/// value, optional secondary detail, and an Edit action. Every section uses
/// this so Review reads as one consistent list, not a text summary.
class ReviewSectionCard extends StatelessWidget {
  const ReviewSectionCard({
    super.key,
    required this.leading,
    required this.label,
    required this.title,
    this.subtitle,
    required this.onEdit,
  });

  final Widget leading;
  final String label;
  final String title;
  final String? subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          // Visible label stays a plain "Edit"; the semantic label spells out
          // what it edits (e.g. "Edit Vehicle") so it's unambiguous with a
          // screen reader, where several of these buttons exist on one page.
          Semantics(
            label: '${l10n.editAction} $label',
            excludeSemantics: true,
            button: true,
            child: TextButton(onPressed: onEdit, child: Text(l10n.editAction)),
          ),
        ],
      ),
    );
  }
}
