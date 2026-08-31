import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/auth/domain/phone_auth_failure.dart';
import 'package:anaaya_plus/features/auth/presentation/screens/otp_screen.dart';
import 'package:anaaya_plus/features/auth/presentation/screens/phone_number_screen.dart';
import 'package:anaaya_plus/features/home/presentation/screens/home_screen.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/auth_screen_harness.dart';

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(PhoneNumberScreen)));

/// Drives the app from the Phone Number screen through a successful send,
/// landing on the real OTP screen with a genuine verification session —
/// the same path every OTP test in this file starts from.
Future<void> _reachOtpScreen(WidgetTester tester, FakeAuthRepository auth) async {
  await pumpAuthScreen(tester, auth: auth);
  final l10n = _l10n(tester);
  await tester.enterText(find.byType(TextFormField), '512345678');
  await tester.tap(find.text(l10n.sendCodeCta));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('shows which number the code was sent to', (tester) async {
    final auth = FakeAuthRepository();
    await _reachOtpScreen(tester, auth);
    final l10n = AppLocalizations.of(tester.element(find.byType(OtpScreen)));

    expect(find.text(l10n.otpSentToLabel('+966512345678')), findsOneWidget);
  });

  testWidgets('a correct code signs the user in and the app moves to Home', (tester) async {
    final auth = FakeAuthRepository(onVerifyOtp: (phone, code) async => 'real-uid');
    await _reachOtpScreen(tester, auth);
    final l10n = AppLocalizations.of(tester.element(find.byType(OtpScreen)));

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text(l10n.verifyCodeCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.currentUserUid, 'real-uid');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
  });

  testWidgets('an incorrect code shows an error and stays on the OTP screen', (tester) async {
    final auth = FakeAuthRepository(
      onVerifyOtp: (phone, code) async => throw const PhoneAuthFailureException(PhoneAuthFailure.invalidOtp),
    );
    await _reachOtpScreen(tester, auth);
    final l10n = AppLocalizations.of(tester.element(find.byType(OtpScreen)));

    await tester.enterText(find.byType(TextFormField), '000000');
    await tester.tap(find.text(l10n.verifyCodeCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(l10n.invalidOtpError), findsOneWidget);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(auth.currentUserUid, isNull);
  });

  testWidgets('shows the verifying state while a submission is in flight', (tester) async {
    final auth = FakeAuthRepository(
      onVerifyOtp: (phone, code) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return 'real-uid';
      },
    );
    await _reachOtpScreen(tester, auth);
    final l10n = AppLocalizations.of(tester.element(find.byType(OtpScreen)));

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text(l10n.verifyCodeCta));
    await tester.pump();

    expect(find.text(l10n.verifyingCodeLabel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('resend is not yet available immediately after a code is sent', (tester) async {
    final auth = FakeAuthRepository();
    await _reachOtpScreen(tester, auth);
    final l10n = AppLocalizations.of(tester.element(find.byType(OtpScreen)));

    expect(find.text(l10n.resendCodeCta), findsNothing);
  });

  testWidgets('the back action returns to the Phone Number screen and clears the session', (tester) async {
    final auth = FakeAuthRepository();
    await _reachOtpScreen(tester, auth);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    // The page transition back to the Phone Number screen needs more than
    // a token pump to fully settle before the old page is gone.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PhoneNumberScreen), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
  });
}
