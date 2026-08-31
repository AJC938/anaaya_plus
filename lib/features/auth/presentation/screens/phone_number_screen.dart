import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_providers.dart';
import '../../domain/phone_number_validation.dart';
import '../widgets/phone_auth_failure_text.dart';

/// Entry point of the auth flow — the only screen an unauthenticated user
/// can reach (see the router's redirect). Collects a Saudi mobile number
/// and starts Firebase phone verification; navigates to [OtpScreen] once
/// Firebase confirms the code was sent.
class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final l10n = AppLocalizations.of(context);
    final input = _controller.text;

    if (!isValidSaudiLocalNumber(input)) {
      setState(() => _errorText = l10n.invalidPhoneNumberError);
      return;
    }

    setState(() => _errorText = null);
    ref.read(phoneAuthControllerProvider.notifier).sendCode(toSaudiE164(input));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(phoneAuthControllerProvider);

    ref.listen(phoneAuthControllerProvider, (previous, next) {
      if (next.codeSent && previous?.codeSent != true) {
        context.go(AppRoutes.authOtp);
      }
      if (next.failure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(phoneAuthFailureMessage(next.failure!, l10n))));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.local_taxi_outlined, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              Text(l10n.authWelcomeTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(l10n.authPhonePrompt, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 32),
              Text(l10n.phoneNumberLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    alignment: Alignment.center,
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(saudiCountryCode, style: theme.textTheme.bodyLarge),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '5XXXXXXXX',
                        errorText: _errorText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: authState.isSending ? null : _handleSubmit,
                  child: authState.isSending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Text(l10n.sendingCodeLabel),
                          ],
                        )
                      : Text(l10n.sendCodeCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
