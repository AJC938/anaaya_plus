import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/customer_profile.dart';
import 'profile_avatar.dart';

/// The strong-but-simple identity block at the top of Profile: avatar, name,
/// phone, optional email, and the single entry point into editing.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, required this.onEdit});

  final CustomerProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsetsDirectional.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProfileAvatar(fullName: profile.fullName, imageAsset: profile.profileImageAsset),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(profile.fullName, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(profile.phoneNumber, style: theme.textTheme.bodyMedium),
                if (profile.email != null) ...[
                  const SizedBox(height: 2),
                  Text(profile.email!, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Semantics(
            button: true,
            label: l10n.editProfileCta,
            excludeSemantics: true,
            child: IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              tooltip: l10n.editProfileCta,
            ),
          ),
        ],
      ),
    );
  }
}
