import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/home_providers.dart';
import 'booking_status_card.dart';

/// Home's contextual "hero" element: the active booking when one exists, a
/// prompt to add a vehicle for a brand-new user, or nothing at all — letting
/// Services/Discovery take priority, per the Home UX principle.
class ActiveBookingSection extends ConsumerWidget {
  const ActiveBookingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(homeVehiclesProvider);
    final bookingAsync = ref.watch(homeActiveBookingProvider);

    if (vehiclesAsync.isLoading || bookingAsync.isLoading) {
      return const LoadingPlaceholder(height: 140);
    }
    if (vehiclesAsync.hasError || bookingAsync.hasError) {
      return SectionErrorState(
        height: 140,
        onRetry: () {
          ref.invalidate(homeVehiclesProvider);
          ref.invalidate(homeActiveBookingProvider);
        },
      );
    }

    if (vehiclesAsync.requireValue.isEmpty) {
      return const _NoVehiclePrompt();
    }

    final booking = bookingAsync.requireValue;
    if (booking == null) return const SizedBox.shrink();

    return BookingStatusCard(booking: booking);
  }
}

class _NoVehiclePrompt extends StatelessWidget {
  const _NoVehiclePrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.garage_outlined, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l10n.addVehiclePrompt, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          FilledButton(
            // Reuses the existing shell navigation — no separate routing logic.
            onPressed: () => context.go(AppRoutes.cars),
            child: Text(l10n.addVehicleCta),
          ),
        ],
      ),
    );
  }
}
