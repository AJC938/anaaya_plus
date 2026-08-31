import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/personal_info_screen.dart';
import 'package:anaaya_plus/features/profile/presentation/screens/profile_screen.dart';

import '../../../support/profile_fixtures.dart';
import '../../../support/profile_screen_harness.dart';

final _route = AppRoutes.personalInfo();

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(PersonalInfoScreen)));

void main() {
  testWidgets('renders the full name, phone number, and email', (tester) async {
    await pumpProfileScreen(tester, route: _route);

    expect(find.text(testProfile.fullName), findsOneWidget);
    expect(find.text(testProfile.phoneNumber), findsOneWidget);
    expect(find.text(testProfile.email!), findsOneWidget);
  });

  testWidgets('a missing optional email shows "Not provided" instead of a blank row', (tester) async {
    await pumpProfileScreen(tester, route: _route, repository: FakeProfileRepository(profile: testProfileNoEmail));
    final l10n = _l10n(tester);

    expect(find.text(l10n.notProvidedLabel), findsOneWidget);
  });

  testWidgets('tapping Personal Information on Profile navigates here', (tester) async {
    await pumpProfileScreen(tester); // starts at /profile
    final l10n = AppLocalizations.of(tester.element(find.byType(ProfileScreen)));

    await tester.tap(find.descendant(of: find.byType(ProfileScreen), matching: find.text(l10n.personalInformationTitle)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PersonalInfoScreen), findsOneWidget);
  });
}
