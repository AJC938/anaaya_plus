import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_states.dart';

/// One compact settings-style row — an icon, a label, an optional current
/// value, and a trailing control. Deliberately not a card: rows are grouped
/// into a single bordered [ProfileMenuSection] instead, so a settings list
/// reads as one scannable block rather than a stack of separate cards.
class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.valueText,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// The current value shown before the trailing control, e.g. the active
  /// language name.
  final String? valueText;

  /// Overrides the default trailing chevron — used for the notifications
  /// [Switch].
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Sign Out reads as an alert action, not a neutral navigation row.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = destructive ? AppColors.error : AppColors.textPrimary;
    final iconColor = destructive ? AppColors.error : AppColors.primary;

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: labelColor))),
            if (valueText != null) ...[
              Text(valueText!, style: theme.textTheme.bodyMedium),
              const SizedBox(width: 6),
            ],
            trailing ?? (onTap != null ? const ForwardChevron() : const SizedBox.shrink()),
          ],
        ),
      ),
    );

    // A custom trailing control (e.g. the notifications Switch) carries its
    // own meaningful semantics (on/off state) — collapsing the row into one
    // label+button node would hide that from a screen reader, so only rows
    // using the default chevron get the collapsed "whole row is one button"
    // treatment.
    if (trailing != null) return row;

    return Semantics(button: onTap != null, label: label, excludeSemantics: true, child: row);
  }
}

/// Groups related [ProfileMenuRow]s into one bordered, low-decoration
/// surface with a subtle divider between each — the "compact settings rows,
/// not giant cards" structure the whole screen follows.
class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({super.key, this.title, required this.rows});

  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[SectionHeader(title: title!), const SizedBox(height: 10)],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i != rows.length - 1) const Divider(height: 1, indent: 50),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
