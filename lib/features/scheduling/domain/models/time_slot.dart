/// One selectable appointment time on a given date.
class TimeSlot {
  const TimeSlot({required this.id, required this.start, required this.isAvailable});

  final String id;
  final DateTime start;
  final bool isAvailable;
}
