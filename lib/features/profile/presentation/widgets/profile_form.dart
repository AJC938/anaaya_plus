import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/customer_profile.dart';
import '../../domain/profile_validation.dart';

/// Owns Edit Profile's local field state — no Riverpod providers for
/// individual fields, matching [VehicleFormController]'s established
/// pattern. The screen creates one per form session and disposes it when
/// done.
class ProfileFormController {
  ProfileFormController({required CustomerProfile initialProfile})
    : fullNameController = TextEditingController(text: initialProfile.fullName),
      emailController = TextEditingController(text: initialProfile.email ?? '');

  final TextEditingController fullNameController;
  final TextEditingController emailController;

  ProfileFormErrors validate() {
    return validateProfileForm(fullName: fullNameController.text, email: emailController.text);
  }

  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
  }
}

String? _fieldErrorText(AppLocalizations l10n, ProfileFieldError? error) {
  return switch (error) {
    null => null,
    ProfileFieldError.required => l10n.fieldRequiredError,
    ProfileFieldError.tooShort => l10n.nameTooShortError,
    ProfileFieldError.invalidEmail => l10n.invalidEmailError,
  };
}

/// Full Name / Email (editable) plus a read-only Phone Number field with an
/// explanatory note — phone changes aren't supported this milestone since
/// it's expected to later gate authentication/verification.
class ProfileForm extends StatelessWidget {
  const ProfileForm({super.key, required this.controller, required this.phoneNumber, required this.errors});

  final ProfileFormController controller;
  final String phoneNumber;
  final ProfileFormErrors? errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.fullNameLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.fullNameController,
          decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.fullName)),
        ),
        const SizedBox(height: 16),
        Text(l10n.emailOptionalLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.email)),
        ),
        const SizedBox(height: 16),
        Text(l10n.phoneNumberLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: phoneNumber,
          enabled: false,
          decoration: InputDecoration(border: const OutlineInputBorder(), helperText: l10n.phoneNumberNotEditableNote),
        ),
      ],
    );
  }
}
