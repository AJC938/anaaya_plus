import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/profile_providers.dart';

/// Read-only account details. Editable fields (Full Name, Email) can only
/// be changed through Edit Profile — this screen never mutates anything,
/// so it stays free of form/business logic.
class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.personalInformationTitle)),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const LoadingPlaceholder(height: 64),
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.sectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(profileControllerProvider),
          ),
          data: (profile) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(label: l10n.fullNameLabel, value: profile.fullName),
                    const Divider(height: 1, indent: 16),
                    _InfoRow(label: l10n.phoneNumberLabel, value: profile.phoneNumber),
                    const Divider(height: 1, indent: 16),
                    _InfoRow(label: l10n.emailOptionalLabel, value: profile.email ?? l10n.notProvidedLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
