import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_info_screen.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_screen.dart';

import '../../../support/profile_screen_harness.dart';

void main() {
  for (final entry in {
    'help': AppRoutes.helpSupport(),
    'terms': AppRoutes.termsConditions(),
    'privacy': AppRoutes.privacyPolicy(),
  }.entries) {
    testWidgets('the ${entry.key} support route renders a ProfileInfoScreen', (tester) async {
      await pumpProfileScreen(tester, route: entry.value);

      expect(find.byType(ProfileInfoScreen), findsOneWidget);
    });
  }

  testWidgets('tapping each Support row navigates to its own screen', (tester) async {
    await pumpProfileScreen(tester); // starts at /profile
    final l10n = AppLocalizations.of(tester.element(find.byType(ProfileScreen)));

    await tester.tap(find.descendant(of: find.byType(ProfileScreen), matching: find.text(l10n.helpSupportTitle)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ProfileInfoScreen), findsOneWidget);
    expect(find.text(l10n.helpSupportTitle), findsWidgets); // AppBar title
    expect(find.text(l10n.helpSupportBody), findsOneWidget);
  });
}
