import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/booking.dart';
import 'booking_status_visuals.dart';
import 'booking_summary_card.dart';

/// One row on the Bookings screen — the same informational summary shown on
/// Confirmation/Tracking, made tappable, with a status chip so the list is
/// scannable without opening each booking.
class BookingListCard extends StatelessWidget {
  const BookingListCard({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (_, color, statusLabel) = bookingStatusVisual(booking.status, l10n);

    return Semantics(
      button: true,
      label: '${booking.serviceName}, $statusLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: BookingSummaryCard(
          booking: booking,
          trailing: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(
              statusLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
