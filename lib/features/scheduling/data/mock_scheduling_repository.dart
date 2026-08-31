import '../domain/models/availability_day.dart';
import '../domain/models/time_slot.dart';
import 'scheduling_repository.dart';

/// Local/in-memory stand-in for a future Scheduling repository backed by a
/// real availability backend. Availability is generated relative to
/// `DateTime.now()` so the mock always shows realistic upcoming dates,
/// regardless of when the app is run.
///
/// The artificial delay is only so the loading states are visible when
/// running the app manually.
class MockSchedulingRepository implements SchedulingRepository {
  static const _latency = Duration(milliseconds: 400);

  static const _daysAhead = 10;

  // One day in the strip is deliberately fully booked, so the "no available
  // time slots" state is reachable without special-casing a service.
  static const _fullyBookedDayIndex = 3;

  // A realistic full-day spread, morning through evening, with a lunch gap
  // at 12 — not just a handful of tokens scattered across the day.
  static const _slotHours = [9, 10, 11, 13, 14, 15, 16, 17];

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _hasAvailability(int dayIndex) => dayIndex != _fullyBookedDayIndex;

  @override
  Future<List<AvailabilityDay>> fetchAvailableDates({required String serviceId}) async {
    await Future.delayed(_latency);
    final today = _dateOnly(DateTime.now());
    return [
      for (var i = 1; i <= _daysAhead; i++)
        AvailabilityDay(date: today.add(Duration(days: i)), hasAvailability: _hasAvailability(i)),
    ];
  }

  @override
  Future<List<TimeSlot>> fetchTimeSlots({required String serviceId, required DateTime date}) async {
    await Future.delayed(_latency);
    final today = _dateOnly(DateTime.now());
    final dayIndex = _dateOnly(date).difference(today).inDays;

    if (!_hasAvailability(dayIndex)) return const [];

    // One slot per day is already booked, so the grid shows a real disabled
    // state rather than every slot always being open.
    final unavailableHour = _slotHours[dayIndex % _slotHours.length];

    return [
      for (final hour in _slotHours)
        TimeSlot(
          id: '${date.year}-${date.month}-${date.day}-$hour',
          start: DateTime(date.year, date.month, date.day, hour),
          isAvailable: hour != unavailableHour,
        ),
    ];
  }
}
