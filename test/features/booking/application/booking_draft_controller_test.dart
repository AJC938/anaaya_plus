import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/application/booking_draft_controller.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';
import 'package:anaaya_plus/features/scheduling/domain/models/time_slot.dart';

const _home = BookingLocation(
  id: 'loc-home',
  labelAr: 'المنزل',
  labelEn: 'Home',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الزهراء',
  districtEn: 'Al Zahra District',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

const _work = BookingLocation(
  id: 'loc-work',
  labelAr: 'العمل',
  labelEn: 'Work',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الروضة',
  districtEn: 'Al Rawdah District',
  latitude: 21.5645,
  longitude: 39.1758,
  isSimulatedCurrentLocation: false,
);

void main() {
  test('no draft exists before startOrUpdateDraft is called', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(bookingDraftControllerProvider), isNull);
  });

  test('startOrUpdateDraft creates a draft with the given service, option, and vehicle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', serviceOptionId: 'opt-1', vehicleId: 'v1');

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.serviceId, 's1');
    expect(draft.serviceOptionId, 'opt-1');
    expect(draft.vehicleId, 'v1');
    expect(draft.location, isNull);
  });

  test('re-entering the same service preserves location, date, and time slot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.setLocation(_home);
    notifier.setDate(DateTime(2026, 1, 5));
    notifier.setTimeSlot(TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true));

    // Same service, different vehicle — e.g. re-tapping the CTA after
    // changing the vehicle on Service Details.
    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v2');

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.vehicleId, 'v2');
    expect(draft.location, _home);
    expect(draft.date, isNotNull);
    expect(draft.timeSlot, isNotNull);
  });

  test('starting a draft for a different service clears location, date, and time slot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.setLocation(_home);
    notifier.setDate(DateTime(2026, 1, 5));
    notifier.setTimeSlot(TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true));

    notifier.startOrUpdateDraft(serviceId: 's2', vehicleId: 'v1');

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.serviceId, 's2');
    expect(draft.location, isNull);
    expect(draft.date, isNull);
    expect(draft.timeSlot, isNull);
  });

  test('setVehicle preserves location, date, and time slot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.setLocation(_home);
    final slot = TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true);
    notifier.setDate(DateTime(2026, 1, 5));
    notifier.setTimeSlot(slot);

    notifier.setVehicle('v2');

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.vehicleId, 'v2');
    expect(draft.location, _home);
    expect(draft.timeSlot, slot);
  });

  test('setLocation preserves the vehicle (changing location never erases it)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.setLocation(_home);
    notifier.setLocation(_work);

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.vehicleId, 'v1');
    expect(draft.location, _work);
  });

  test('setDate clears a previously selected time slot — slots are date-specific', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.setLocation(_home);
    notifier.setDate(DateTime(2026, 1, 5));
    notifier.setTimeSlot(TimeSlot(id: 'slot-1', start: DateTime(2026, 1, 5, 10), isAvailable: true));

    notifier.setDate(DateTime(2026, 1, 6));

    final draft = container.read(bookingDraftControllerProvider)!;
    expect(draft.date, DateTime(2026, 1, 6));
    expect(draft.timeSlot, isNull);
  });

  test('clear removes the draft entirely', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookingDraftControllerProvider.notifier);

    notifier.startOrUpdateDraft(serviceId: 's1', vehicleId: 'v1');
    notifier.clear();

    expect(container.read(bookingDraftControllerProvider), isNull);
  });
}
