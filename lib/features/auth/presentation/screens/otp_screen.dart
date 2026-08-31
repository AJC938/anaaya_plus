import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/countdown.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_providers.dart';
import '../widgets/phone_auth_failure_text.dart';

const _resendCooldown = Duration(seconds: 60);

/// Step 2 of the auth flow: the code Firebase sent. Reachable only with an
/// active verification session (see the redirect guard below) — success
/// isn't handled here at all: [authStateChangesProvider] picks up the newly
/// signed-in user and the router's own redirect takes it from there.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeNumber() {
    ref.read(phoneAuthControllerProvider.notifier).clear();
    context.go(AppRoutes.authPhone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(phoneAuthControllerProvider);

    ref.listen(phoneAuthControllerProvider, (previous, next) {
      if (next.failure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(phoneAuthFailureMessage(next.failure!, l10n))));
      }
    });

    // A direct/restored deep link with no active verification session has
    // nothing to verify — send the user back to enter their number.
    if (!state.codeSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.authPhone);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _changeNumber)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.otpScreenTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(l10n.otpSentToLabel(state.phoneNumber ?? ''), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 32),
              Text(l10n.otpFieldLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state.isVerifying
                      ? null
                      : () => ref.read(phoneAuthControllerProvider.notifier).verifyOtp(_controller.text),
                  child: state.isVerifying
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Text(l10n.verifyingCodeLabel),
                          ],
                        )
                      : Text(l10n.verifyCodeCta),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: _ResendSection(phoneNumber: state.phoneNumber!, codeSentAt: state.codeSentAt!)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendSection extends ConsumerWidget {
  const _ResendSection({required this.phoneNumber, required this.codeSentAt});

  final String phoneNumber;
  final DateTime codeSentAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(secondTickerProvider);
    final l10n = AppLocalizations.of(context);
    final remaining = remainingUntil(codeSentAt.add(_resendCooldown));

    if (remaining > Duration.zero) {
      return Text(
        l10n.resendCodeInLabel('${remaining.inSeconds}s'),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return TextButton(
      onPressed: () => ref.read(phoneAuthControllerProvider.notifier).sendCode(phoneNumber, isResend: true),
      child: Text(l10n.resendCodeCta),
    );
  }
}
