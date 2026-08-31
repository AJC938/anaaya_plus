import '../../../location/domain/models/booking_location.dart';
import '../../../scheduling/domain/models/time_slot.dart';

/// The single in-progress booking — created when Service Details' CTA is
/// tapped (service + option + vehicle already chosen there) and filled in
/// as the user moves through Location and Date & Time.
///
/// Deliberately has no "ready"/status field — readiness is always derived
/// from these values (see domain/booking_validation.dart), so it can never
/// drift out of sync with the actual selections.
class BookingDraft {
  const BookingDraft({
    required this.serviceId,
    this.serviceOptionId,
    required this.vehicleId,
    this.location,
    this.date,
    this.timeSlot,
  });

  final String serviceId;
  final String? serviceOptionId;
  final String vehicleId;
  final BookingLocation? location;

  /// Date-only; the time of day lives on [timeSlot].
  final DateTime? date;
  final TimeSlot? timeSlot;

  BookingDraft copyWith({String? vehicleId, BookingLocation? location, DateTime? date, TimeSlot? timeSlot}) {
    return BookingDraft(
      serviceId: serviceId,
      serviceOptionId: serviceOptionId,
      vehicleId: vehicleId ?? this.vehicleId,
      location: location ?? this.location,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
    );
  }
}
