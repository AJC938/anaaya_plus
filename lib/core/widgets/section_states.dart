import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';

/// Feedback for actions that don't have a real destination feature yet
/// (e.g. the guided discovery banner) — see the router README note in
/// app_router.dart for which destinations are actually wired.
void showComingSoonSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
}

/// A trailing chevron that points toward reading-end regardless of locale.
/// [Icon] has no built-in RTL mirroring, unlike [Image].
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: isRtl,
      child: Icon(Icons.arrow_forward_ios, size: size, color: color),
    );
  }
}

/// Shared header for a dashboard/catalog section: a title and an optional
/// "View All".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                const ForwardChevron(),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lightweight skeleton box shown while a section's data is loading.
class LoadingPlaceholder extends StatelessWidget {
  const LoadingPlaceholder({super.key, this.height = 96, this.width, this.borderRadius = 16});

  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shown in place of a single section when its data fails to load, so one
/// failure never takes down the rest of the screen.
class SectionErrorState extends StatelessWidget {
  const SectionErrorState({super.key, required this.onRetry, this.height = 110});

  final VoidCallback onRetry;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(height: 6),
          Text(l10n.sectionErrorMessage, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
