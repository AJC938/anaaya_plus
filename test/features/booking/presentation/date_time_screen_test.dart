import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:anaaya_plus/app/router/app_router.dart';
import 'package:anaaya_plus/core/localization/app_localizations.dart';
import 'package:anaaya_plus/core/widgets/section_states.dart';
import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/date_time_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/location_screen.dart';
import 'package:anaaya_plus/features/booking/presentation/screens/review_screen.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/availability_day.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';

import '../../../support/booking_screen_harness.dart';

final _draftNoLocation = const BookingDraft(serviceId: testServiceId, serviceOptionId: 'opt-mineral', vehicleId: 'v1');
final _draftWithLocation = BookingDraft(
  serviceId: testServiceId,
  serviceOptionId: 'opt-mineral',
  vehicleId: 'v1',
  location: testHomeLocation,
);
final _route = AppRoutes.bookingDateTime(testServiceId);

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(DateTimeScreen)));

String _dayLabel(DateTime date) => '${date.day}';

void main() {
  testWidgets('with no location chosen yet, redirects back to Location instead of showing the screen', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draftNoLocation);
    await tester.pumpAndSettle();

    expect(find.byType(DateTimeScreen), findsNothing);
    expect(find.byType(LocationScreen), findsOneWidget);
  });

  testWidgets('shows a structured loading UI for dates, not a bare spinner', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation,
      availableDates: (ref, id) => Completer<List<AvailabilityDay>>().future,
    );

    expect(find.byType(LoadingPlaceholder), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the date strip once dates load, with no time section yet', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draftWithLocation);
    final l10n = _l10n(tester);

    expect(find.text(_dayLabel(testAvailableDate)), findsOneWidget);
    expect(find.text(l10n.availableTimeTitle), findsNothing);
  });

  testWidgets('no available dates shows an explanatory notice', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation,
      availableDates: (ref, id) async => [AvailabilityDay(date: testAvailableDate, hasAvailability: false)],
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.noAvailableDatesMessage), findsOneWidget);
  });

  testWidgets('dates error shows retry, and retry recovers', (tester) async {
    var attempt = 0;
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation,
      availableDates: (ref, id) async {
        attempt++;
        if (attempt == 1) throw Exception('mock dates failure');
        return [testAvailableDay];
      },
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_dayLabel(testAvailableDate)), findsOneWidget);
  });

  testWidgets('selecting a date updates the draft and reveals the time section', (tester) async {
    final container = await pumpBookingScreen(tester, route: _route, draft: _draftWithLocation);
    final l10n = _l10n(tester);

    expect(find.text(l10n.availableTimeTitle), findsNothing);

    await tester.tap(find.text(_dayLabel(testAvailableDate)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.availableTimeTitle), findsOneWidget);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.date, DateTime(testAvailableDate.year, testAvailableDate.month, testAvailableDate.day));
  });

  testWidgets('shows a structured loading UI for time slots', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation.copyWith(date: testAvailableDate),
      timeSlots: (ref, query) => Completer<List<TimeSlot>>().future,
    );

    expect(find.byType(LoadingPlaceholder), findsWidgets);
  });

  testWidgets('unavailable slots are shown but not selectable', (tester) async {
    final container = await pumpBookingScreen(tester, route: _route, draft: _draftWithLocation.copyWith(date: testAvailableDate));
    final locale = Localizations.localeOf(tester.element(find.byType(DateTimeScreen)));
    final timeFormat = DateFormat.jm(locale.toString());
    final unavailableLabel = timeFormat.format(testUnavailableSlot.start);

    expect(find.text(unavailableLabel), findsOneWidget);

    await tester.tap(find.text(unavailableLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.timeSlot, isNull);
  });

  testWidgets('no available times for the selected date shows an explanatory notice', (tester) async {
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation.copyWith(date: testAvailableDate),
      timeSlots: (ref, query) async => const [],
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.noAvailableTimesMessage), findsOneWidget);
  });

  testWidgets('time slots error shows retry, and retry recovers', (tester) async {
    var attempt = 0;
    await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation.copyWith(date: testAvailableDate),
      timeSlots: (ref, query) async {
        attempt++;
        if (attempt == 1) throw Exception('mock slots failure');
        return [testSlot];
      },
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.sectionErrorMessage), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final locale = Localizations.localeOf(tester.element(find.byType(DateTimeScreen)));
    expect(find.text(DateFormat.jm(locale.toString()).format(testSlot.start)), findsOneWidget);
  });

  testWidgets('selecting an available slot updates the draft and shows continue', (tester) async {
    final container = await pumpBookingScreen(tester, route: _route, draft: _draftWithLocation.copyWith(date: testAvailableDate));
    final l10n = _l10n(tester);
    final locale = Localizations.localeOf(tester.element(find.byType(DateTimeScreen)));
    final availableLabel = DateFormat.jm(locale.toString()).format(testSlot.start);

    expect(find.text(l10n.continueCta), findsNothing);

    await tester.tap(find.text(availableLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.continueCta), findsOneWidget);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.timeSlot, testSlot);
  });

  testWidgets('changing the date clears a previously selected time slot', (tester) async {
    final secondDate = DateTime(2026, 1, 6);
    final container = await pumpBookingScreen(
      tester,
      route: _route,
      draft: _draftWithLocation.copyWith(date: testAvailableDate, timeSlot: testSlot),
      availableDates: (ref, id) async => [testAvailableDay, AvailabilityDay(date: secondDate, hasAvailability: true)],
    );
    final l10n = _l10n(tester);

    expect(find.text(l10n.continueCta), findsOneWidget);

    await tester.tap(find.text(_dayLabel(secondDate)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l10n.continueCta), findsNothing);
    final draft = container.read(bookingDraftControllerProvider);
    expect(draft!.timeSlot, isNull);
  });

  testWidgets('tapping continue navigates to Review', (tester) async {
    await pumpBookingScreen(tester, route: _route, draft: _draftWithLocation.copyWith(date: testAvailableDate, timeSlot: testSlot));
    final l10n = _l10n(tester);

    await tester.tap(find.text(l10n.continueCta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ReviewScreen), findsOneWidget);
  });
}
