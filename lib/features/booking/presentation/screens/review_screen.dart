import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../cars/application/cars_providers.dart';
import '../../../cars/domain/models/vehicle.dart';
import '../../../services/application/services_providers.dart';
import '../../../services/domain/models/service.dart';
import '../../../services/domain/models/service_option.dart';
import '../../application/booking_draft_controller.dart';
import '../../application/booking_submission_controller.dart';
import '../../data/booking_repository.dart';
import '../../domain/booking_validation.dart';
import '../../domain/models/booking_draft.dart';
import '../../domain/pricing.dart';
import '../widgets/booking_progress_indicator.dart';
import '../widgets/booking_step_guard.dart';
import '../widgets/price_breakdown_card.dart';
import '../widgets/review_section_card.dart';
import '../widgets/vehicle_edit_sheet.dart';

/// Step 3 of Booking: a checkout-style review, not a text summary — every
/// selection is visible, editable, and the total has real hierarchy.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftControllerProvider);
    if (redirectIfStepNotReached(
      context,
      draft: draft,
      requiredStep: BookingStep.review,
      fallbackRoute: AppRoutes.bookingDateTime(serviceId),
    )) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final l10n = AppLocalizations.of(context);
    final serviceAsync = ref.watch(serviceByIdProvider(serviceId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewBookingTitle)),
      body: SafeArea(
        child: serviceAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const LoadingPlaceholder(height: 84),
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.sectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(serviceByIdProvider(serviceId)),
          ),
          data: (service) => service == null
              ? FullScreenMessage(icon: Icons.block, message: l10n.serviceUnavailableMessage)
              : _ReviewBody(serviceId: serviceId, service: service, draft: draft!),
        ),
      ),
    );
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.serviceId, required this.service, required this.draft});

  final String serviceId;
  final Service service;
  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(carsControllerProvider);

    return vehiclesAsync.when(
      loading: () => const LoadingPlaceholder(height: 84),
      error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(carsControllerProvider)),
      data: (vehicles) {
        Vehicle? vehicle;
        for (final candidate in vehicles) {
          if (candidate.id == draft.vehicleId) {
            vehicle = candidate;
            break;
          }
        }
        if (vehicle == null) {
          return FullScreenMessage(icon: Icons.error_outline, iconColor: AppColors.error, message: l10n.sectionErrorMessage);
        }

        if (draft.serviceOptionId == null) {
          return _ReviewContent(serviceId: serviceId, service: service, vehicle: vehicle, option: null, draft: draft);
        }

        final optionsAsync = ref.watch(serviceOptionsProvider(serviceId));
        return optionsAsync.when(
          loading: () => const LoadingPlaceholder(height: 84),
          error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(serviceOptionsProvider(serviceId))),
          data: (options) {
            ServiceOption? option;
            for (final candidate in options) {
              if (candidate.id == draft.serviceOptionId) {
                option = candidate;
                break;
              }
            }
            return _ReviewContent(serviceId: serviceId, service: service, vehicle: vehicle!, option: option, draft: draft);
          },
        );
      },
    );
  }
}

class _ReviewContent extends ConsumerWidget {
  const _ReviewContent({required this.serviceId, required this.service, required this.vehicle, required this.option, required this.draft});

  final String serviceId;
  final Service service;
  final Vehicle vehicle;
  final ServiceOption? option;
  final BookingDraft draft;

  Future<void> _editVehicle(BuildContext context, WidgetRef ref) async {
    final newVehicleId = await showVehicleEditSheet(context, currentVehicleId: vehicle.id);
    if (newVehicleId != null) {
      ref.read(bookingDraftControllerProvider.notifier).setVehicle(newVehicleId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final location = draft.location!;
    final dateTimeFormat = DateFormat.yMMMMEEEEd(locale.toString());
    final timeFormat = DateFormat.jm(locale.toString());
    final price = calculateBookingPrice(basePrice: service.startingPrice, optionPrice: option?.price ?? 0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const BookingProgressIndicator(currentStep: 3),
        const SizedBox(height: 20),
        ReviewSectionCard(
          leading: AssetVisual(assetKey: service.imageAsset, size: 44),
          label: l10n.serviceLabel,
          title: service.name(locale),
          onEdit: () => context.go(AppRoutes.serviceDetails(serviceId)),
        ),
        const SizedBox(height: 12),
        ReviewSectionCard(
          leading: AssetVisual(assetKey: vehicle.imageAsset, size: 44),
          label: l10n.vehicleLabel,
          title: vehicle.displayName,
          subtitle: '${vehicle.year} • ${vehicle.plateNumber}',
          onEdit: () => _editVehicle(context, ref),
        ),
        if (option != null) ...[
          const SizedBox(height: 12),
          ReviewSectionCard(
            leading: AssetVisual(assetKey: option!.imageAsset, size: 44),
            label: l10n.serviceOptionLabel,
            title: option!.name(locale),
            onEdit: () => context.go(AppRoutes.serviceDetails(serviceId)),
          ),
        ],
        const SizedBox(height: 12),
        ReviewSectionCard(
          leading: const _RoundIcon(icon: Icons.location_on_outlined),
          label: l10n.locationLabel,
          title: location.district(locale),
          subtitle: location.city(locale),
          onEdit: () => context.push(AppRoutes.bookingLocation(serviceId)),
        ),
        const SizedBox(height: 12),
        ReviewSectionCard(
          leading: const _RoundIcon(icon: Icons.calendar_today_outlined),
          label: l10n.dateTimeLabel,
          title: dateTimeFormat.format(draft.date!),
          subtitle: timeFormat.format(draft.timeSlot!.start),
          onEdit: () => context.push(AppRoutes.bookingDateTime(serviceId)),
        ),
        const SizedBox(height: 20),
        PriceBreakdownCard(breakdown: price, optionLabel: option != null ? l10n.serviceOptionLabel : null),
        const SizedBox(height: 20),
        _ConfirmSection(serviceId: serviceId, draft: draft),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

class _ConfirmSection extends ConsumerStatefulWidget {
  const _ConfirmSection({required this.serviceId, required this.draft});

  final String serviceId;
  final BookingDraft draft;

  @override
  ConsumerState<_ConfirmSection> createState() => _ConfirmSectionState();
}

class _ConfirmSectionState extends ConsumerState<_ConfirmSection> {
  /// Delegates the actual submission — including the authoritative
  /// duplicate-submission guard — to [BookingSubmissionController], which
  /// always re-reads the current draft itself rather than trusting
  /// [widget.draft]. This method only reacts to the outcome: a second
  /// invocation that arrives while one is already in flight gets back a
  /// no-op result (state still `AsyncLoading`, no value, no error) from the
  /// controller and simply does nothing further — never a second
  /// navigation, never a second error message.
  Future<void> _handleConfirm() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context);
    final router = GoRouter.of(context);

    await ref.read(bookingSubmissionControllerProvider.notifier).submit(locale);
    if (!mounted) return;

    final result = ref.read(bookingSubmissionControllerProvider);
    final booking = result.value;
    if (booking != null) {
      // BE-07: the booking now exists (unchanged Booking Engine behavior),
      // but is not yet paid — Payment sits between Review and Confirmation,
      // so a successful submission navigates there, never straight to
      // Confirmation. Confirmation itself is only reached once Payment's
      // own domain layer reports `paid` (see payment_screen.dart).
      router.go(AppRoutes.bookingPayment(widget.serviceId, booking.id));
      return;
    }

    final error = result.error;
    if (error == null) return; // a duplicate call while one was already in flight — nothing new to show

    if (error is BookingSlotUnavailableException) {
      // The stale slot can't be trusted anymore — clear it (setDate clears
      // the time slot as a side effect) and send the user back to re-pick.
      ref.read(bookingDraftControllerProvider.notifier).setDate(widget.draft.date!);
      messenger.showSnackBar(SnackBar(content: Text(l10n.slotUnavailableMessage)));
      router.pop();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookingFailedMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isConfirming = ref.watch(bookingSubmissionControllerProvider).isLoading;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isConfirming ? null : _handleConfirm,
        child: isConfirming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.confirmingLabel),
                ],
              )
            : Text(l10n.confirmBookingCta),
      ),
    );
  }
}
