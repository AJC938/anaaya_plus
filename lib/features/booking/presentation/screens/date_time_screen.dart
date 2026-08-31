import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../scheduling/application/scheduling_providers.dart';
import '../../../scheduling/presentation/widgets/date_selector.dart';
import '../../../scheduling/presentation/widgets/time_slot_selector.dart';
import '../../application/booking_draft_controller.dart';
import '../../domain/booking_validation.dart';
import '../widgets/booking_progress_indicator.dart';
import '../widgets/booking_step_guard.dart';

/// Step 2 of Booking: date first, then that date's time slots — two
/// clearly separate decisions, never conflated.
class DateTimeScreen extends ConsumerWidget {
  const DateTimeScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftControllerProvider);
    if (redirectIfStepNotReached(
      context,
      draft: draft,
      requiredStep: BookingStep.dateTime,
      fallbackRoute: AppRoutes.bookingLocation(serviceId),
    )) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final l10n = AppLocalizations.of(context);
    final datesAsync = ref.watch(availableDatesProvider(serviceId));
    final selectedDate = draft!.date;
    final selectedSlotId = draft.timeSlot?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dateTimeLabel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const BookingProgressIndicator(currentStep: 2),
            const SizedBox(height: 20),
            Text(l10n.chooseDateTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            datesAsync.when(
              loading: () => const LoadingPlaceholder(height: 72),
              error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(availableDatesProvider(serviceId))),
              data: (days) {
                final anyAvailable = days.any((day) => day.hasAvailability);
                if (!anyAvailable) {
                  return _InlineNotice(icon: Icons.event_busy, message: l10n.noAvailableDatesMessage);
                }
                return DateSelector(
                  days: days,
                  selectedDate: selectedDate,
                  onSelect: (date) => ref.read(bookingDraftControllerProvider.notifier).setDate(date),
                );
              },
            ),
            if (selectedDate != null) ...[
              const SizedBox(height: 24),
              Text(l10n.availableTimeTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _TimeSlotsSection(serviceId: serviceId, date: selectedDate, selectedSlotId: selectedSlotId),
            ],
            if (selectedSlotId != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push(AppRoutes.bookingReview(serviceId)),
                  child: Text(l10n.continueCta),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeSlotsSection extends ConsumerWidget {
  const _TimeSlotsSection({required this.serviceId, required this.date, required this.selectedSlotId});

  final String serviceId;
  final DateTime date;
  final String? selectedSlotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = (serviceId: serviceId, date: date);
    final slotsAsync = ref.watch(timeSlotsProvider(query));

    return slotsAsync.when(
      loading: () => const LoadingPlaceholder(height: 96),
      error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(timeSlotsProvider(query))),
      data: (slots) {
        if (slots.isEmpty) {
          return _InlineNotice(icon: Icons.schedule_outlined, message: l10n.noAvailableTimesMessage);
        }
        return TimeSlotSelector(
          slots: slots,
          selectedSlotId: selectedSlotId,
          onSelect: (slot) => ref.read(bookingDraftControllerProvider.notifier).setTimeSlot(slot),
        );
      },
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
