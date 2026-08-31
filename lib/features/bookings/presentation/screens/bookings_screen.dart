import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../booking/application/booking_providers.dart';
import '../../../booking/domain/booking_list_grouping.dart';
import '../../../booking/domain/models/booking.dart';
import '../../../booking/presentation/widgets/booking_list_card.dart';

/// My Bookings — every booking the user has made, grouped so active work is
/// never buried under history. Real data now: created bookings (Review's
/// Confirm) land here via [bookingsListProvider], alongside the fixed demo
/// set used to exercise every status.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookingsAsync = ref.watch(bookingsListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navBookings)),
      body: SafeArea(child: _buildBody(context, ref, l10n, bookingsAsync)),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppLocalizations l10n, AsyncValue<List<Booking>> bookingsAsync) {
    if (bookingsAsync.hasValue) {
      final groups = groupBookingsForList(bookingsAsync.value!);
      return groups.isEmpty ? const _EmptyBookingsState() : _BookingsList(groups: groups);
    }

    if (bookingsAsync.hasError) {
      return FullScreenMessage(
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        message: l10n.unableToLoadBookingsMessage,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(bookingsListProvider),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const LoadingPlaceholder(height: 140),
    );
  }
}

class _BookingsList extends StatelessWidget {
  const _BookingsList({required this.groups});

  final BookingListGroups groups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (groups.active.isNotEmpty) ..._section(context, l10n.activeBookingsSectionTitle, groups.active),
        if (groups.completed.isNotEmpty) ..._section(context, l10n.completedBookingsSectionTitle, groups.completed),
        if (groups.cancelled.isNotEmpty) ..._section(context, l10n.cancelledBookingsSectionTitle, groups.cancelled),
      ],
    );
  }

  List<Widget> _section(BuildContext context, String title, List<Booking> bookings) {
    return [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (final booking in bookings)
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 12),
          child: BookingListCard(booking: booking, onTap: () => context.push(AppRoutes.bookingTracking(booking.id))),
        ),
      const SizedBox(height: 8),
    ];
  }
}

class _EmptyBookingsState extends StatelessWidget {
  const _EmptyBookingsState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(l10n.noBookingsTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.noBookingsSubtitle, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            // Jumps straight to the Services catalog — the actual booking
            // entry point — rather than the Home dashboard, matching the
            // cross-branch navigation pattern already used elsewhere (e.g.
            // ConfirmationScreen's own "back to..." actions).
            FilledButton(onPressed: () => context.go(AppRoutes.services()), child: Text(l10n.bookServiceCta)),
          ],
        ),
      ),
    );
  }
}
