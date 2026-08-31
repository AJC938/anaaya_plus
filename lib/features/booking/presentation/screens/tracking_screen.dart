import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/countdown.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../payment/application/payment_providers.dart';
import '../../../payment/domain/models/payment.dart';
import '../../application/booking_status_controller.dart';
import '../../domain/models/booking.dart';
import '../widgets/booking_status_visuals.dart';
import '../widgets/booking_summary_card.dart';
import '../widgets/cancel_booking_dialog.dart';
import '../widgets/status_timeline.dart';

/// Tracking is entirely state-driven off [BookingStatus] — no hardcoded
/// paragraph, no widget-level business logic. Route: /bookings/:bookingId/tracking.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  /// Kept separately from the provider's own `AsyncValue` so the booking
  /// stays on screen while a "simulate advance" request is in flight (or
  /// after it fails) — `BookingStatusController.state` transiently loses
  /// its value during that window (see the controller's own doc comment).
  Booking? _lastKnownBooking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = bookingStatusControllerProvider(widget.bookingId);
    final bookingAsync = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      // Checked in this order deliberately: Riverpod's AsyncNotifier
      // framework automatically carries the previous value forward onto a
      // later AsyncError (so a failed advance's `next` can have
      // `hasValue == true` AND `hasError == true` at once) — `hasError`
      // must be checked first, or this would misread a failed advance as
      // a successful one and never show the snackbar below.
      if (next.hasError) {
        if (_lastKnownBooking != null) {
          // A booking was already showing, so this error can only be from
          // a failed "simulate advance" or a failed cancellation (see
          // _SimulateProgressSection/_CancelBookingSection) — the
          // initial-load error case (no booking ever shown yet) is handled
          // by the full-screen error state below instead.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.statusUpdateFailedMessage)));
        }
      } else if (next.hasValue) {
        // A transition specifically INTO cancelled — as opposed to any
        // other successful status change — gets its own success snackbar:
        // cancellation is a deliberate, destructive user action (unlike the
        // forward "simulate advance" steps, whose success is already
        // obvious from the UI changing shape), so it earns an explicit
        // confirmation. Deliberately requires `previous` to have ALREADY
        // carried a real (non-null) booking value — not just "previous
        // wasn't cancelled" — because on the screen's very first load,
        // `previous` is the provider's initial `AsyncLoading` state, which
        // has no booking value at all, NOT `null` itself as an earlier
        // version of this check assumed. Without this, opening an
        // already-cancelled booking fresh (e.g. from My Bookings, or after
        // a cold restart) would incorrectly show the success snackbar on
        // every visit — confirmed live during BE-06 verification.
        final previousBooking = previous?.value;
        if (next.value?.status == BookingStatus.cancelled && previousBooking != null && previousBooking.status != BookingStatus.cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bookingCancelledSuccessMessage)));
        }
        setState(() => _lastKnownBooking = next.value);
      }
    });

    final booking = _lastKnownBooking;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackServiceCta)),
      body: SafeArea(
        child: booking == null
            ? bookingAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  // Either an exception, or a successful fetch that simply
                  // found no such booking — both are "nothing to show" once
                  // there's no in-flight request left to wait on.
                  : FullScreenMessage(
                      icon: Icons.error_outline,
                      iconColor: AppColors.error,
                      message: l10n.sectionErrorMessage,
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(provider),
                    )
            : booking.status == BookingStatus.cancelled
            ? _CancelledView(booking: booking)
            : _ActiveTrackingView(bookingId: widget.bookingId, booking: booking, isUpdating: bookingAsync.isLoading),
      ),
    );
  }
}

class _ActiveTrackingView extends StatelessWidget {
  const _ActiveTrackingView({required this.bookingId, required this.booking, required this.isUpdating});

  final String bookingId;
  final Booking booking;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusHero(booking: booking),
        const SizedBox(height: 24),
        StatusTimeline(status: booking.status),
        const SizedBox(height: 8),
        BookingSummaryCard(booking: booking),
        _CompletePaymentSection(booking: booking),
        _SimulateProgressSection(bookingId: bookingId, status: booking.status, isUpdating: isUpdating),
        _CancelBookingSection(bookingId: bookingId, status: booking.status, isUpdating: isUpdating),
      ],
    );
  }
}

/// BE-07: the retry/first-payment entry point for a booking that either has
/// no [Payment] yet or whose last attempt [PaymentStatus.failed] —
/// [PaymentScreen] itself never blocks the user from backing out without
/// paying (see its own doc comment), so this is the durable way back into
/// it later, from wherever the booking actually lives (My Bookings ->
/// Tracking), not just the one-shot path immediately after Review.
/// Deliberately fetch-only ([paymentByBookingProvider], not the mutating
/// [paymentControllerProvider]) — this section only ever decides whether to
/// *show* a CTA, it never itself submits a payment.
class _CompletePaymentSection extends ConsumerWidget {
  const _CompletePaymentSection({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (booking.status != BookingStatus.upcoming) return const SizedBox.shrink();
    final paymentAsync = ref.watch(paymentByBookingProvider(booking.id));
    final payment = paymentAsync.value;
    if (payment?.status == PaymentStatus.paid) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsetsDirectional.all(14),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.paymentPendingLabel, style: Theme.of(context).textTheme.bodyMedium)),
            TextButton(
              onPressed: () => context.push(AppRoutes.bookingPayment(booking.serviceId, booking.id)),
              child: Text(l10n.completePaymentCta),
            ),
          ],
        ),
      ),
    );
  }
}

/// BE-06: the real (non-demo) cancellation action — only ever rendered for
/// [BookingStatus.upcoming], the state machine's only edge into
/// [BookingStatus.cancelled] (see `booking_status_transition.dart`).
/// [isUpdating] is shared with [_SimulateProgressSection] (both read the
/// same [BookingStatusController] state) so the two can never both be
/// tappable at once — a simulate-advance in flight disables Cancel too, and
/// vice versa.
class _CancelBookingSection extends ConsumerWidget {
  const _CancelBookingSection({required this.bookingId, required this.status, required this.isUpdating});

  final String bookingId;
  final BookingStatus status;
  final bool isUpdating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status != BookingStatus.upcoming) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: isUpdating
              ? null
              : () async {
                  final confirmed = await showCancelBookingDialog(context);
                  if (!confirmed || !context.mounted) return;
                  await ref.read(bookingStatusControllerProvider(bookingId).notifier).cancel();
                },
          child: isUpdating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                )
              : Text(l10n.cancelBookingCta),
        ),
      ),
    );
  }
}

/// A clearly-labeled demo control, NOT a real technician action — this
/// project has no technician app/dispatch backend (out of scope for this
/// milestone), so the customer app itself is the only available way to
/// exercise the status lifecycle end to end. Renders nothing once the
/// booking reaches a terminal status ([BookingStatus.completed]/
/// [BookingStatus.cancelled]).
class _SimulateProgressSection extends ConsumerWidget {
  const _SimulateProgressSection({required this.bookingId, required this.status, required this.isUpdating});

  final String bookingId;
  final BookingStatus status;
  final bool isUpdating;

  BookingStatus? get _nextStatus => switch (status) {
    BookingStatus.upcoming => BookingStatus.technicianOnTheWay,
    BookingStatus.technicianOnTheWay => BookingStatus.inProgress,
    BookingStatus.inProgress => BookingStatus.completed,
    BookingStatus.completed || BookingStatus.cancelled => null,
  };

  String _ctaFor(AppLocalizations l10n, BookingStatus next) => switch (next) {
    BookingStatus.technicianOnTheWay => l10n.simulateTechnicianOnTheWayCta,
    BookingStatus.inProgress => l10n.simulateStartServiceCta,
    BookingStatus.completed => l10n.simulateCompleteServiceCta,
    BookingStatus.upcoming || BookingStatus.cancelled => '',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = _nextStatus;
    if (next == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          l10n.simulateProgressSectionTitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isUpdating ? null : () => ref.read(bookingStatusControllerProvider(bookingId).notifier).advance(next),
            child: isUpdating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_ctaFor(l10n, next)),
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (icon, color, title) = bookingStatusVisual(booking.status, l10n);

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                _StatusSubtitle(booking: booking),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSubtitle extends StatelessWidget {
  const _StatusSubtitle({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    switch (booking.status) {
      case BookingStatus.upcoming:
        return _CountdownText(
          target: booking.scheduledAt,
          textFor: (d) => d == Duration.zero ? l10n.startingNow : l10n.startsInLabel(formatCountdown(d)),
        );
      case BookingStatus.technicianOnTheWay:
        return _CountdownText(
          target: booking.estimatedArrival ?? booking.scheduledAt,
          textFor: (d) => d == Duration.zero ? l10n.technicianArrivedLabel : l10n.etaLabel(formatCountdown(d)),
        );
      case BookingStatus.inProgress:
        return const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 6),
        );
      case BookingStatus.completed:
      case BookingStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}

/// Ticks once a second by watching [secondTickerProvider] so only this leaf
/// rebuilds — the rest of Tracking does not.
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
    );
  }
}

class _CancelledView extends StatelessWidget {
  const _CancelledView({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusHero(booking: booking),
        const SizedBox(height: 20),
        BookingSummaryCard(booking: booking),
      ],
    );
  }
}
