import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/countdown.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/home_booking_summary.dart';

/// The Home "hero" element while a booking exists. Its content and emphasis
/// change with [HomeBookingSummary.status] — this is what makes the booking
/// "become a high-priority dashboard element" per the Home UX principle.
class BookingStatusCard extends StatelessWidget {
  const BookingStatusCard({super.key, required this.booking});

  final HomeBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    if (booking.status == HomeBookingStatus.completed) {
      return _CompletedBookingBanner(booking: booking);
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetVisual(assetKey: booking.serviceImageAsset),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_titleFor(booking.status, l10n), style: theme.textTheme.titleMedium),
                    Text(
                      '${booking.serviceName} • ${booking.vehicleName} ${booking.vehicleYear}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BookingStatusLine(booking: booking),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              // Cross-branch navigation (Home -> Bookings), so `.go` rather
              // than `.push` — matches Confirmation's own Track Service CTA.
              onPressed: () => context.go(AppRoutes.bookingTracking(booking.id)),
              child: Text(l10n.trackServiceCta),
            ),
          ),
        ],
      ),
    );
  }

  static String _titleFor(HomeBookingStatus status, AppLocalizations l10n) => switch (status) {
    HomeBookingStatus.upcoming => l10n.upcomingServiceTitle,
    HomeBookingStatus.technicianOnTheWay => l10n.technicianOnTheWayTitle,
    HomeBookingStatus.serviceInProgress => l10n.serviceInProgressTitle,
    HomeBookingStatus.completed => l10n.serviceCompletedTitle,
  };
}

/// The status-specific line under the title: a live countdown/ETA, or a
/// progress indicator while the service is actively being performed.
class _BookingStatusLine extends StatelessWidget {
  const _BookingStatusLine({required this.booking});

  final HomeBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (booking.status) {
      case HomeBookingStatus.upcoming:
        return _CountdownText(
          target: booking.scheduledAt,
          textFor: (d) => d == Duration.zero ? l10n.startingNow : l10n.startsInLabel(formatCountdown(d)),
        );
      case HomeBookingStatus.technicianOnTheWay:
        return _CountdownText(
          target: booking.estimatedArrival ?? booking.scheduledAt,
          textFor: (d) => d == Duration.zero ? l10n.technicianArrivedLabel : l10n.etaLabel(formatCountdown(d)),
        );
      case HomeBookingStatus.serviceInProgress:
        return const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 6),
        );
      case HomeBookingStatus.completed:
        return const SizedBox.shrink();
    }
  }
}

/// Ticks once a second by watching [secondTickerProvider] so only this leaf
/// rebuilds — the rest of Home (and the rest of this card) does not.
class _CountdownText extends ConsumerWidget {
  const _CountdownText({required this.target, required this.textFor});

  final DateTime target;
  final String Function(Duration remaining) textFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secondTickerProvider);
    final remaining = remainingUntil(target);
    return Text(
      textFor(remaining),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
    );
  }
}

/// Lightweight variant for a just-completed booking — deliberately smaller
/// and CTA-free so it doesn't dominate Home the way an active booking does.
class _CompletedBookingBanner extends StatelessWidget {
  const _CompletedBookingBanner({required this.booking});

  final HomeBookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l10n.serviceCompletedTitle} • ${booking.serviceName}',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
