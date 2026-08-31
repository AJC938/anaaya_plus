import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../app/router/app_router.dart';

class QuickAccessSection extends StatelessWidget {
  const QuickAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.directions_car_outlined,
            title: l10n.quickAccessCarsTitle,
            subtitle: l10n.quickAccessCarsSubtitle,
            // Reuses the existing shell navigation — no separate routing logic.
            onTap: () => context.go(AppRoutes.cars),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAccessCard(
            icon: Icons.calendar_month_outlined,
            title: l10n.quickAccessBookingsTitle,
            subtitle: l10n.quickAccessBookingsSubtitle,
            onTap: () => context.go(AppRoutes.bookings),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
