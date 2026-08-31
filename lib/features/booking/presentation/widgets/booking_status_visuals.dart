import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/booking.dart';

/// Icon, color, and localized label for a [BookingStatus] — shared by
/// Tracking's status hero and the Bookings list's status chip, the two
/// places that need to render a status at a glance.
(IconData, Color, String) bookingStatusVisual(BookingStatus status, AppLocalizations l10n) {
  return switch (status) {
    BookingStatus.upcoming => (Icons.event_available_outlined, AppColors.primary, l10n.upcomingServiceTitle),
    BookingStatus.technicianOnTheWay => (Icons.directions_car_filled, AppColors.primary, l10n.technicianOnTheWayTitle),
    BookingStatus.inProgress => (Icons.build_circle_outlined, AppColors.primary, l10n.serviceInProgressTitle),
    BookingStatus.completed => (Icons.check_circle, AppColors.success, l10n.serviceCompletedTitle),
    BookingStatus.cancelled => (Icons.cancel_outlined, AppColors.error, l10n.bookingCancelledTitle),
  };
}
