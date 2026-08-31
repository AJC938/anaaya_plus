/// Whether a vehicle has an active/upcoming association elsewhere in the
/// product — represented only in Cars' mock data, since Booking doesn't
/// exist yet. This exists purely to drive the delete-protection business
/// rule; it is never a field on [Vehicle] itself.
enum VehicleAssociationStatus {
  /// No association at all.
  none,

  /// Has a scheduled, not-yet-started booking.
  upcomingBooking,

  /// Has a service currently in progress.
  activeService,

  /// Only completed/past activity — nothing blocking.
  historicalOnly,
}

/// A vehicle can be deleted unless it has an upcoming booking or an active
/// service right now. Past activity never blocks deletion.
bool canDeleteVehicle(VehicleAssociationStatus status) {
  return status != VehicleAssociationStatus.upcomingBooking && status != VehicleAssociationStatus.activeService;
}
