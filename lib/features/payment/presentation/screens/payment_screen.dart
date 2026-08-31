import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../booking/application/booking_providers.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../booking/presentation/widgets/booking_summary_card.dart';
import '../../application/payment_controller.dart';
import '../../domain/models/payment.dart';
import '../../domain/payment_attempt_id.dart';

/// Step: Review -> **Payment** -> Booking Confirmation. Reached only for a
/// booking that already exists (created by `BookingSubmissionController`,
/// unchanged by this milestone) — Payment never creates or claims a
/// booking/slot itself, it only attaches a [Payment] record to one that
/// already exists. The amount shown always comes from the booking's own
/// [Booking.price] (the Booking Engine's own authoritative computation),
/// never a value re-entered or re-derived here.
///
/// This app has NO external payment gateway — payment is a LOCAL TEST
/// SIMULATION. Pressing "Simulate Payment" immediately marks the booking as
/// paid; no card details, gateway credentials, or network call are ever
/// involved. This is intentional for this test/portfolio project and must
/// never be represented as a real payment system.
///
/// Also reachable from Tracking for a booking whose payment isn't
/// [PaymentStatus.paid] yet (see `tracking_screen.dart`'s
/// `_CompletePaymentSection`) — backing out of Payment (system back / AppBar
/// back) is a fully legitimate action here: nothing is written to Firestore
/// unless the user actually presses "Simulate Payment", so leaving this
/// screen without paying can never produce a false-success state, and the
/// booking remains reachable to retry payment later.
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.serviceId, required this.bookingId});

  final String serviceId;
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentTitle)),
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
              : _PaymentBody(serviceId: serviceId, booking: booking),
        ),
      ),
    );
  }
}

class _PaymentBody extends ConsumerStatefulWidget {
  const _PaymentBody({required this.serviceId, required this.booking});

  final String serviceId;
  final Booking booking;

  @override
  ConsumerState<_PaymentBody> createState() => _PaymentBodyState();
}

class _PaymentBodyState extends ConsumerState<_PaymentBody> {
  /// Kept separately from the provider's own `AsyncValue` for the exact
  /// reason `TrackingScreen._lastKnownBooking` is (see its own doc
  /// comment): `PaymentController.state` transiently loses its value while
  /// [PaymentController.submitPayment] is in flight or after it fails, but
  /// the form (amount, Simulate Payment button) must stay on screen
  /// throughout — only the button itself should show a spinner, never the
  /// whole page collapsing to a bare loading indicator on every submission.
  Payment? _lastKnownPayment;
  bool _hasLoadedOnce = false;

  @override
  Widget build(BuildContext context) {
    final provider = paymentControllerProvider(widget.booking.id);
    final paymentAsync = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      if (next.hasValue) {
        setState(() {
          _lastKnownPayment = next.value;
          _hasLoadedOnce = true;
        });
      }
    });

    if (!_hasLoadedOnce) {
      if (paymentAsync.hasError) {
        return SectionErrorState(onRetry: () => ref.invalidate(provider));
      }
      return const Center(child: CircularProgressIndicator());
    }

    final payment = _lastKnownPayment;
    return payment?.status == PaymentStatus.paid
        ? _PaymentSuccessView(serviceId: widget.serviceId, booking: widget.booking, payment: payment!)
        : _PaymentFormView(booking: widget.booking, isSubmitting: paymentAsync.isLoading);
  }
}

/// The "Simulate Payment" form — shown when there is no payment yet. Never
/// shown once [PaymentStatus.paid], matching Phase 4's "payment becomes
/// paid -> booking proceeds to confirmation" rule: a paid booking has
/// nothing left to pay.
class _PaymentFormView extends ConsumerWidget {
  const _PaymentFormView({required this.booking, required this.isSubmitting});

  final Booking booking;
  final bool isSubmitting;

  /// Records a fresh, always-successful simulated payment. There is no
  /// external gateway to call and no failure outcome this button can
  /// produce — the only error path left is a genuine repository failure
  /// (e.g. the booking no longer exists), which surfaces as a generic
  /// message rather than a fabricated "card declined" reason.
  Future<void> _simulatePayment(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await ref
        .read(paymentControllerProvider(booking.id).notifier)
        .submitPayment(status: PaymentStatus.paid, method: 'simulated', transactionId: generatePaymentAttemptId());
    if (!context.mounted) return;

    // A successful result rebuilds this whole subtree into
    // _PaymentSuccessView instead (see _PaymentBody) — nothing further to
    // do here on success.
    final updated = ref.read(paymentControllerProvider(booking.id));
    if (updated.hasError) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.paymentFailedMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BookingSummaryCard(booking: booking),
        const SizedBox(height: 20),
        _AmountCard(booking: booking),
        const SizedBox(height: 20),
        Text(
          l10n.paymentSimulationNotice,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isSubmitting ? null : () => _simulatePayment(context, ref),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : Text(l10n.simulatePaymentCta),
          ),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.amountDueLabel, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Text(
            l10n.priceSar(booking.price.total.toStringAsFixed(0)),
            style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView({required this.serviceId, required this.booking, required this.payment});

  final String serviceId;
  final Booking booking;
  final Payment payment;

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
        Text(l10n.paymentSuccessTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          l10n.priceSar(payment.amount.toStringAsFixed(0)),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        BookingSummaryCard(booking: booking),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.bookingConfirmation(serviceId, booking.id)),
            child: Text(l10n.continueCta),
          ),
        ),
      ],
    );
  }
}
