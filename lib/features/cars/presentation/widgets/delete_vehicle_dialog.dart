import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Confirms deletion of a named vehicle. Resolves `true` only if the user
/// taps Delete.
Future<bool> showDeleteVehicleDialog(BuildContext context, {required String vehicleName}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteVehicleTitle),
      content: Text(l10n.deleteVehicleConfirmMessage(vehicleName)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancelAction)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shown instead of the confirm dialog when the vehicle is known upfront to
/// be undeletable — never a confirmation the app can't honor.
Future<void> showCannotDeleteVehicleDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.cannotDeleteVehicleTitle),
      content: Text(l10n.cannotDeleteVehicleMessage),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancelAction))],
    ),
  );
}
