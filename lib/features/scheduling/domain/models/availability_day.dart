/// One selectable date in the date strip. [date] is date-only (time
/// components are ignored by the repository) — availability is a
/// per-day, not per-instant, concept at this granularity.
class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.hasAvailability});

  final DateTime date;
  final bool hasAvailability;
}
