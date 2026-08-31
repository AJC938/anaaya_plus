import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/domain/booking_list_grouping.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/pricing.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';

const _location = BookingLocation(
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

Booking _booking({required String id, required BookingStatus status, required DateTime scheduledAt}) {
  return Booking(
    id: id,
    serviceId: 's1',
    serviceName: 'Oil Change',
    serviceImageAsset: 'oil_change',
    vehicleId: 'v1',
    vehicleName: 'Toyota Camry',
    vehicleYear: 2023,
    plateNumber: 'ABC 1234',
    location: _location,
    scheduledAt: scheduledAt,
    price: calculateBookingPrice(basePrice: 89),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('an empty list groups to all-empty', () {
    final groups = groupBookingsForList(const []);
    expect(groups.isEmpty, isTrue);
    expect(groups.active, isEmpty);
    expect(groups.completed, isEmpty);
    expect(groups.cancelled, isEmpty);
  });

  test('upcoming, on-the-way, and in-progress all count as active', () {
    final bookings = [
      _booking(id: 'a', status: BookingStatus.upcoming, scheduledAt: DateTime(2026, 1, 10)),
      _booking(id: 'b', status: BookingStatus.technicianOnTheWay, scheduledAt: DateTime(2026, 1, 5)),
      _booking(id: 'c', status: BookingStatus.inProgress, scheduledAt: DateTime(2026, 1, 5, 1)),
    ];

    final groups = groupBookingsForList(bookings);

    expect(groups.active.map((b) => b.id), ['b', 'c', 'a']); // sorted soonest-first
    expect(groups.completed, isEmpty);
    expect(groups.cancelled, isEmpty);
  });

  test('completed bookings sort most-recent-first', () {
    final bookings = [
      _booking(id: 'old', status: BookingStatus.completed, scheduledAt: DateTime(2026, 1, 1)),
      _booking(id: 'new', status: BookingStatus.completed, scheduledAt: DateTime(2026, 1, 10)),
    ];

    final groups = groupBookingsForList(bookings);

    expect(groups.completed.map((b) => b.id), ['new', 'old']);
  });

  test('cancelled bookings are grouped separately from active/completed', () {
    final bookings = [_booking(id: 'x', status: BookingStatus.cancelled, scheduledAt: DateTime(2026, 1, 1))];

    final groups = groupBookingsForList(bookings);

    expect(groups.cancelled.map((b) => b.id), ['x']);
    expect(groups.active, isEmpty);
    expect(groups.completed, isEmpty);
    expect(groups.isEmpty, isFalse);
  });
}
