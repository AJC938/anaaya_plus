import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Confirms sign-out. Resolves `true` only if the user taps Sign Out. No
/// authentication logic lives here or anywhere in Profile yet — this is
/// just the confirmation seam a real sign-out call will slot into later.
Future<bool> showSignOutDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.signOutConfirmTitle),
      content: Text(l10n.signOutConfirmMessage),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancelAction)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.signOutAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
