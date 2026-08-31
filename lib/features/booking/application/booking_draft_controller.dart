import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/domain/models/booking_location.dart';
import '../../scheduling/domain/models/time_slot.dart';
import '../domain/models/booking_draft.dart';

/// The single active booking draft. Created when Service Details' CTA is
/// tapped and cleared when the flow is abandoned or successfully confirmed
/// — a completed booking must never keep behaving like an unfinished draft.
class BookingDraftController extends Notifier<BookingDraft?> {
  @override
  BookingDraft? build() => null;

  /// Called from Service Details. If a draft already exists for the same
  /// service, its location/date/time-slot are preserved (the vehicle/option
  /// may have simply been re-confirmed); switching to a different service
  /// starts fresh, since date/time availability is service-specific and an
  /// old selection could silently be wrong for the new one.
  void startOrUpdateDraft({required String serviceId, String? serviceOptionId, required String vehicleId}) {
    final current = state;
    final sameService = current != null && current.serviceId == serviceId;
    state = BookingDraft(
      serviceId: serviceId,
      serviceOptionId: serviceOptionId,
      vehicleId: vehicleId,
      location: sameService ? current.location : null,
      date: sameService ? current.date : null,
      timeSlot: sameService ? current.timeSlot : null,
    );
  }

  void setVehicle(String vehicleId) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(vehicleId: vehicleId);
  }

  void setLocation(BookingLocation location) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(location: location);
  }

  /// Changing the date invalidates any previously selected time slot —
  /// slots are date-specific, so an old slot can't just carry over.
  void setDate(DateTime date) {
    final current = state;
    if (current == null) return;
    state = BookingDraft(
      serviceId: current.serviceId,
      serviceOptionId: current.serviceOptionId,
      vehicleId: current.vehicleId,
      location: current.location,
      date: date,
      timeSlot: null,
    );
  }

  void setTimeSlot(TimeSlot slot) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(timeSlot: slot);
  }

  void clear() => state = null;
}

final bookingDraftControllerProvider = NotifierProvider<BookingDraftController, BookingDraft?>(BookingDraftController.new);
