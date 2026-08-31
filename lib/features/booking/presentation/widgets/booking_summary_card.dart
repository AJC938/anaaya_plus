import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../domain/models/booking.dart';

/// The service/vehicle/date/location summary shared by Confirmation and
/// Tracking — informational only, never editable (unlike Review's cards).
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({super.key, required this.booking, this.trailing});

  final Booking booking;

  /// Optional header-row accessory — e.g. the Bookings list's status chip.
  /// Confirmation/Tracking never pass one; the header stays exactly as before.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final dateTimeFormat = DateFormat.yMMMMEEEEd(locale.toString());
    final timeFormat = DateFormat.jm(locale.toString());

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
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
              AssetVisual(assetKey: booking.serviceImageAsset, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(booking.serviceName, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${booking.vehicleName} • ${booking.vehicleYear} • ${booking.plateNumber}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          const Padding(padding: EdgeInsetsDirectional.symmetric(vertical: 12), child: Divider(height: 1)),
          BookingInfoRow(
            icon: Icons.calendar_today_outlined,
            text: '${dateTimeFormat.format(booking.scheduledAt)} • ${timeFormat.format(booking.scheduledAt)}',
          ),
          const SizedBox(height: 8),
          BookingInfoRow(
            icon: Icons.location_on_outlined,
            text: '${booking.location.district(locale)}, ${booking.location.city(locale)}',
          ),
        ],
      ),
    );
  }
}

class BookingInfoRow extends StatelessWidget {
  const BookingInfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
