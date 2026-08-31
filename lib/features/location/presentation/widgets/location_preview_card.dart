import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/booking_location.dart';

/// Reinforces the selected location before the user continues — lets them
/// visually confirm "this is where the technician will come" without a
/// full map.
class LocationPreviewCard extends StatelessWidget {
  const LocationPreviewCard({super.key, required this.location});

  final BookingLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final address = location.addressLine(locale);

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.location_on, color: AppColors.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(location.label(locale), style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('${location.district(locale)}, ${location.city(locale)}', style: theme.textTheme.bodyMedium),
                if (address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
