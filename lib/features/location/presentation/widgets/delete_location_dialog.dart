import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Confirms deletion of a named saved location. Resolves `true` only if
/// the user taps Delete — mirrors `showDeleteVehicleDialog`'s exact
/// pattern for Cars.
Future<bool> showDeleteLocationDialog(BuildContext context, {required String locationName}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteLocationTitle),
      content: Text(l10n.deleteLocationConfirmMessage(locationName)),
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
