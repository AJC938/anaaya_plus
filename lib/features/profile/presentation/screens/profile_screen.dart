import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_menu_row.dart';
import '../widgets/sign_out_dialog.dart';

/// Profile is an account/settings area, not a social profile — a header
/// plus compact, grouped settings rows.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showSignOutDialog(context);
    if (!confirmed) return;
    // Real Firebase sign-out — authStateChangesProvider picks up the change
    // and the router's own redirect sends the app back to the phone screen.
    await ref.read(authRepositoryProvider).signOut();
    // Reset the OTP flow's own local state too — without this, a second
    // sign-in in the same app session sees `codeSent` go true -> true
    // (never false in between), so the OTP screen's navigation listener
    // (which only fires on a false -> true transition) never triggers.
    ref.read(phoneAuthControllerProvider.notifier).clear();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.signedOutMessage)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, index) => LoadingPlaceholder(height: index == 0 ? 108 : 140),
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.sectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(profileControllerProvider),
          ),
          data: (profile) {
            final locale = ref.watch(localeProvider);
            final currentLanguageName = locale.languageCode == 'ar' ? l10n.languageArabic : l10n.languageEnglish;
            final preferencesAsync = ref.watch(profilePreferencesControllerProvider);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ProfileHeader(profile: profile, onEdit: () => context.push(AppRoutes.profileEdit())),
                const SizedBox(height: 24),
                ProfileMenuSection(
                  title: l10n.accountSectionTitle,
                  rows: [
                    ProfileMenuRow(
                      icon: Icons.badge_outlined,
                      label: l10n.personalInformationTitle,
                      onTap: () => context.push(AppRoutes.personalInfo()),
                    ),
                    ProfileMenuRow(
                      icon: Icons.directions_car_outlined,
                      label: l10n.quickAccessCarsTitle,
                      onTap: () => context.go(AppRoutes.cars),
                    ),
                    ProfileMenuRow(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.bookingHistoryTitle,
                      onTap: () => context.go(AppRoutes.bookings),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ProfileMenuSection(
                  title: l10n.preferencesSectionTitle,
                  rows: [
                    ProfileMenuRow(
                      icon: Icons.language,
                      label: l10n.languageLabel,
                      valueText: currentLanguageName,
                      onTap: () => showLanguagePickerSheet(
                        context,
                        current: locale,
                        onSelect: (selected) => ref.read(localeProvider.notifier).set(selected),
                      ),
                    ),
                    preferencesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
                        child: LoadingPlaceholder(height: 22),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 6),
                        child: SectionErrorState(
                          onRetry: () => ref.invalidate(profilePreferencesControllerProvider),
                          height: 70,
                        ),
                      ),
                      data: (preferences) => ProfileMenuRow(
                        icon: Icons.notifications_outlined,
                        label: l10n.notifications,
                        trailing: Switch(
                          value: preferences.notificationsEnabled,
                          onChanged: (enabled) =>
                              ref.read(profilePreferencesControllerProvider.notifier).setNotificationsEnabled(enabled),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ProfileMenuSection(
                  title: l10n.supportSectionTitle,
                  rows: [
                    ProfileMenuRow(
                      icon: Icons.help_outline,
                      label: l10n.helpSupportTitle,
                      onTap: () => context.push(AppRoutes.helpSupport()),
                    ),
                    ProfileMenuRow(
                      icon: Icons.description_outlined,
                      label: l10n.termsConditionsTitle,
                      onTap: () => context.push(AppRoutes.termsConditions()),
                    ),
                    ProfileMenuRow(
                      icon: Icons.privacy_tip_outlined,
                      label: l10n.privacyPolicyTitle,
                      onTap: () => context.push(AppRoutes.privacyPolicy()),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ProfileMenuSection(
                  rows: [
                    ProfileMenuRow(
                      icon: Icons.logout,
                      label: l10n.signOutAction,
                      destructive: true,
                      onTap: () => _handleSignOut(context, ref),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
