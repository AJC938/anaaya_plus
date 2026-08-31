import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/auth/domain/phone_auth_failure.dart';
import 'package:anaaya_plus/features/auth/presentation/screens/otp_screen.dart';
import 'package:anaaya_plus/features/auth/presentation/screens/phone_number_screen.dart';

import '../../../support/auth_fixtures.dart';
import '../../../support/auth_screen_harness.dart';

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(PhoneNumberScreen)));

void main() {
  testWidgets('an invalid phone number shows a validation error and never contacts Firebase', (tester) async {
    final auth = FakeAuthRepository();
    await pumpAuthScreen(tester, auth: auth);
    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text(l10n.sendCodeCta));
    await tester.pump();

    expect(find.text(l10n.invalidPhoneNumberError), findsOneWidget);
    expect(auth.sendOtpCallCount, 0);
  });

  testWidgets('a valid number sends the code and navigates to the OTP screen', (tester) async {
    final auth = FakeAuthRepository();
    await pumpAuthScreen(tester, auth: auth);
    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextFormField), '512345678');
    await tester.tap(find.text(l10n.sendCodeCta));
    await tester.pump();
    // The page transition to the OTP screen needs more than a token pump
    // to fully settle before the old page is gone.
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.sendOtpCallCount, 1);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.byType(PhoneNumberScreen), findsNothing);
  });

  testWidgets('shows the sending state while verification is in flight', (tester) async {
    final auth = FakeAuthRepository(
      onSendCode: (phone) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
    );
    await pumpAuthScreen(tester, auth: auth);
    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextFormField), '512345678');
    await tester.tap(find.text(l10n.sendCodeCta));
    await tester.pump();

    expect(find.text(l10n.sendingCodeLabel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a Firebase-side failure shows an error and stays on this screen', (tester) async {
    final auth = FakeAuthRepository(
      onSendCode: (phone) async => throw const PhoneAuthFailureException(PhoneAuthFailure.tooManyRequests),
    );
    await pumpAuthScreen(tester, auth: auth);
    final l10n = _l10n(tester);

    await tester.enterText(find.byType(TextFormField), '512345678');
    await tester.tap(find.text(l10n.sendCodeCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.tooManyRequestsError), findsOneWidget);
    expect(find.byType(PhoneNumberScreen), findsOneWidget);
  });
}
