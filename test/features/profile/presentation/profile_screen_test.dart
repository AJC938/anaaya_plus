import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/localization/locale_provider.dart';
import 'package:anaaya_plus/core/widgets/full_screen_message.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/auth/application/auth_providers.dart';
import 'package:anaaya_plus/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:anaaya_plus/features/cars/presentation/screens/cars_screen.dart';
import 'package:anaaya_plus/features/profile/application/profile_providers.dart';
import 'package:anaaya_plus/features/profile/domain/models/customer_profile.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_screen.dart';

import '../../../support/profile_fixtures.dart';
import '../../../support/profile_screen_harness.dart';

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ProfileScreen)));

// The bottom nav bar and offstage sibling branches can repeat some Profile
// strings (e.g. "My Cars"/"سياراتي" is also the Cars tab's own AppBar
// title) — scope lookups to ProfileScreen's own subtree to stay unambiguous.
Finder _inProfile(Finder matching) => find.descendant(of: find.byType(ProfileScreen), matching: matching);

void main() {
  testWidgets('shows a structured loading UI, not a bare spinner', (tester) async {
    await pumpProfileScreen(tester, repository: FakeProfileRepository(onGetProfile: () => Completer<CustomerProfile>().future));

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders the profile information: name, phone, and email', (tester) async {
    await pumpProfileScreen(tester);

    expect(_inProfile(find.text(testProfile.fullName)), findsOneWidget);
    expect(_inProfile(find.text(testProfile.phoneNumber)), findsOneWidget);
    expect(_inProfile(find.text(testProfile.email!)), findsOneWidget);
  });

  testWidgets('a missing optional email renders cleanly, with no email row', (tester) async {
    await pumpProfileScreen(tester, repository: FakeProfileRepository(profile: testProfileNoEmail));

    expect(_inProfile(find.text(testProfileNoEmail.fullName)), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('shows an error with retry, and retry recovers', (tester) async {
    var attempt = 0;
    await pumpProfileScreen(
      tester,
      repository: FakeProfileRepository(
        onGetProfile: () async {
          attempt++;
          if (attempt == 1) throw Exception('mock profile failure');
          return testProfile;
        },
      ),
    );
    final l10n = _l10n(tester);

    expect(find.byType(FullScreenMessage), findsOneWidget);
    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_inProfile(find.text(testProfile.fullName)), findsOneWidget);
  });

  testWidgets('tapping Edit Profile navigates to the Edit Profile screen', (tester) async {
    await pumpProfileScreen(tester);

    await tester.tap(_inProfile(find.byIcon(Icons.edit_outlined)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('the Language row shows the current (default Arabic) language', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    expect(_inProfile(find.text(l10n.languageArabic)), findsOneWidget);
  });

  testWidgets('changing the language updates the whole application locale', (tester) async {
    final container = await pumpProfileScreen(tester);
    final l10nBefore = _l10n(tester);
    expect(container.read(localeProvider).languageCode, 'ar');

    await tester.tap(_inProfile(find.text(l10nBefore.languageLabel)));
    await tester.pump();
    // The sheet's own open (slide-up) transition needs more than a token
    // pump to fully settle before its options are reliably tappable.
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(l10nBefore.languageEnglish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(localeProvider).languageCode, 'en');
    expect(Directionality.of(tester.element(find.byType(ProfileScreen))), TextDirection.ltr);
  });

  testWidgets('toggling notifications updates the preference', (tester) async {
    final container = await pumpProfileScreen(tester);

    expect(container.read(profilePreferencesControllerProvider).value?.notificationsEnabled, isTrue);

    await tester.tap(_inProfile(find.byType(Switch)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(profilePreferencesControllerProvider).value?.notificationsEnabled, isFalse);
  });

  testWidgets('My Cars navigates to the existing Cars feature', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.quickAccessCarsTitle)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CarsScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing); // now offstage, not onstage
  });

  testWidgets('Booking History navigates to the existing Bookings feature', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.bookingHistoryTitle)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(BookingsScreen), findsOneWidget);
  });

  testWidgets('Sign Out shows a confirmation dialog', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.signOutAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.signOutConfirmMessage), findsOneWidget);
  });

  testWidgets('cancelling Sign Out does nothing', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.signOutAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(l10n.cancelAction));
    await tester.pump();
    // The dialog's own close (fade/scale) transition needs more than a
    // token pump to fully settle.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(l10n.signedOutMessage), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget); // still here, unaffected
  });

  testWidgets('confirming Sign Out triggers the mock sign-out action', (tester) async {
    await pumpProfileScreen(tester);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.signOutAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Two matches now: the row behind the dialog, and the dialog's own
    // confirm button — the dialog's is the most recently inserted, so last.
    await tester.tap(find.text(l10n.signOutAction).last);
    await tester.pump();
    // The dialog's own close (fade/scale) transition needs more than a
    // token pump to fully settle.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(l10n.signedOutMessage), findsOneWidget);
  });

  testWidgets('confirming Sign Out also resets the OTP flow state, so a later sign-in navigates correctly', (tester) async {
    final container = await pumpProfileScreen(tester);
    // Simulate a prior sign-in having already driven the OTP flow to
    // completion — this is the exact leftover state that, pre-fix, made a
    // second sign-in's `codeSent` go true -> true (never false in between)
    // and silently break the OTP screen's navigation listener.
    await container.read(phoneAuthControllerProvider.notifier).sendCode('+966512345678');
    expect(container.read(phoneAuthControllerProvider).codeSent, isTrue);
    final l10n = _l10n(tester);

    await tester.tap(_inProfile(find.text(l10n.signOutAction)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(l10n.signOutAction).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(phoneAuthControllerProvider).codeSent, isFalse);
  });

  testWidgets('renders RTL by default (Arabic)', (tester) async {
    await pumpProfileScreen(tester);

    expect(Directionality.of(tester.element(find.byType(ProfileScreen))), TextDirection.rtl);
  });
}
