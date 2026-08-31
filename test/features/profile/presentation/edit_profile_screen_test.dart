import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/profile/application/profile_providers.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_screen.dart';

import '../../../support/profile_fixtures.dart';
import '../../../support/profile_screen_harness.dart';

final _route = AppRoutes.profileEdit();

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(EditProfileScreen)));

void main() {
  testWidgets('pre-fills the current full name and email, and shows the read-only phone number', (tester) async {
    await pumpProfileScreen(tester, route: _route);

    expect(find.widgetWithText(TextFormField, testProfile.fullName), findsOneWidget);
    expect(find.widgetWithText(TextFormField, testProfile.email!), findsOneWidget);
    expect(find.widgetWithText(TextFormField, testProfile.phoneNumber), findsOneWidget);
  });

  testWidgets('an empty full name shows a required-field error and does not save', (tester) async {
    final repository = FakeProfileRepository();
    await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.enterText(find.widgetWithText(TextFormField, testProfile.fullName), '');
    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.fieldRequiredError), findsOneWidget);
    expect(repository.updateProfileCallCount, 0);
  });

  testWidgets('an invalid email shows a format error and does not save', (tester) async {
    final repository = FakeProfileRepository();
    await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.enterText(find.widgetWithText(TextFormField, testProfile.email!), 'not-an-email');
    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.invalidEmailError), findsOneWidget);
    expect(repository.updateProfileCallCount, 0);
  });

  testWidgets('a successful save navigates back and shows a confirmation, and updates the provider', (tester) async {
    final repository = FakeProfileRepository();
    final container = await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.enterText(find.widgetWithText(TextFormField, testProfile.fullName), 'Updated Name');
    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.pump();
    // The pop's page transition needs more than a token pump to settle.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text(l10n.profileUpdatedMessage), findsOneWidget);
    expect(container.read(profileControllerProvider).value?.fullName, 'Updated Name');
  });

  testWidgets('a failed save shows an error and preserves the entered values', (tester) async {
    final repository = FakeProfileRepository(onUpdateProfile: (fullName, email) async => throw Exception('mock failure'));
    await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.enterText(find.widgetWithText(TextFormField, testProfile.fullName), 'Attempted Name');
    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.updateProfileErrorMessage), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget); // stayed on the form
    expect(find.widgetWithText(TextFormField, 'Attempted Name'), findsOneWidget);
    expect(find.text(l10n.saveChangesCta), findsOneWidget); // button usable again, not stuck
  });

  testWidgets('a rapid double-tap on Save only submits once', (tester) async {
    final repository = FakeProfileRepository();
    await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.tap(find.text(l10n.saveChangesCta)); // guarded no-op — _isSaving is already true
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.updateProfileCallCount, 1);
  });

  testWidgets('shows the Saving state while a save is in flight', (tester) async {
    final repository = FakeProfileRepository(onUpdateProfile: (fullName, email) async {
      await Future.delayed(const Duration(milliseconds: 300));
      return testProfile.copyWith(fullName: fullName);
    });
    await pumpProfileScreen(tester, route: _route, repository: repository);
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.saveChangesCta));
    await tester.pump();

    expect(find.text(l10n.savingLabel), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
  });
}
