import '../domain/models/availability_day.dart';
import '../domain/models/time_slot.dart';

/// Data seam for the Scheduling feature. [MockSchedulingRepository] is the
/// only implementation for this milestone; a real scheduling backend can
/// replace it later without Booking's screens changing.
abstract class SchedulingRepository {
  Future<List<AvailabilityDay>> fetchAvailableDates({required String serviceId});

  /// [date] is date-only — the time of day is irrelevant to which day's
  /// slots are being requested.
  Future<List<TimeSlot>> fetchTimeSlots({required String serviceId, required DateTime date});
}
