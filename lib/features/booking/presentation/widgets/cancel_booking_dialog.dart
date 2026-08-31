import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Confirms cancelling a booking. Resolves `true` only if the user taps
/// Cancel Booking — mirrors [showDeleteVehicleDialog]/[showSignOutDialog]'s
/// exact shape (a dismiss [TextButton] plus a destructive-styled
/// [FilledButton]) for the same "confirm before a destructive action"
/// pattern this app already uses.
Future<bool> showCancelBookingDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cancelBookingConfirmTitle),
      content: Text(l10n.cancelBookingConfirmMessage),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.keepBookingAction)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cancelBookingCta),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
