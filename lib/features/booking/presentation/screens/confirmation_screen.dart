import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../application/booking_providers.dart';
import '../../domain/models/booking.dart';
import '../widgets/booking_summary_card.dart';

/// Step 4: a real success experience, not a plain text page — and never
/// poppable back into a wizard for a booking that already exists.
class ConfirmationScreen extends ConsumerWidget {
  const ConfirmationScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.bookingConfirmedTitle)),
        body: SafeArea(
          child: bookingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => FullScreenMessage(
              icon: Icons.error_outline,
              iconColor: AppColors.error,
              message: l10n.sectionErrorMessage,
              actionLabel: l10n.retry,
              onAction: () => ref.invalidate(bookingByIdProvider(bookingId)),
            ),
            data: (booking) => booking == null
                ? FullScreenMessage(icon: Icons.error_outline, message: l10n.sectionErrorMessage)
                : _ConfirmationBody(booking: booking),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationBody extends StatelessWidget {
  const _ConfirmationBody({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 44),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.bookingConfirmedTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          l10n.confirmationSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        BookingSummaryCard(booking: booking),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsetsDirectional.all(16),
          alignment: AlignmentDirectional.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(l10n.bookingReferenceLabel, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                booking.id,
                style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.primary, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.bookingTracking(booking.id)),
            child: Text(l10n.trackServiceCta),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: () => context.go(AppRoutes.home), child: Text(l10n.backToHomeCta)),
        ),
      ],
    );
  }
}
