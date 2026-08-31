import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/profile_providers.dart';
import '../../domain/models/customer_profile.dart';
import '../../domain/profile_validation.dart';
import '../widgets/profile_form.dart';

/// Editable Full Name and Email; Phone Number is shown but read-only (see
/// [ProfileForm]). Reached only from the Profile header's Edit action, so
/// the current profile is normally already loaded — read once in
/// [initState], not watched, matching [VehicleFormScreen]'s established
/// pattern. Watching it reactively would flip this whole screen to an error
/// state the moment a failed save sets [profileControllerProvider] to
/// [AsyncError], which is exactly the state Edit Profile must survive
/// (values preserved, form still open).
///
/// If the profile genuinely isn't loaded yet (a restored deep link
/// straight into this route), there's nothing to edit yet — redirect back
/// to Profile rather than crash on a null value.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  CustomerProfile? _initialProfile;
  ProfileFormController? _formController;
  ProfileFormErrors? _errors;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileControllerProvider).value;
    if (profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.profile);
      });
    } else {
      _initialProfile = profile;
      _formController = ProfileFormController(initialProfile: profile);
    }
  }

  @override
  void dispose() {
    _formController?.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return; // guards against duplicate submissions
    final formController = _formController;
    if (formController == null) return;

    final errors = formController.validate();
    if (!errors.isValid) {
      setState(() => _errors = errors);
      return;
    }

    setState(() {
      _errors = null;
      _isSaving = true;
    });

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(profileControllerProvider.notifier);
    final trimmedEmail = formController.emailController.text.trim();

    try {
      await notifier.updateProfile(
        fullName: formController.fullNameController.text.trim(),
        email: trimmedEmail.isEmpty ? null : trimmedEmail,
      );
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileUpdatedMessage)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.updateProfileErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialProfile = _initialProfile;
    final formController = _formController;
    if (initialProfile == null || formController == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileCta)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileForm(controller: formController, phoneNumber: initialProfile.phoneNumber, errors: _errors),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Text(l10n.savingLabel),
                          ],
                        )
                      : Text(l10n.saveChangesCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
