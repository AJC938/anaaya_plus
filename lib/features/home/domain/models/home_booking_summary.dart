/// Home-scoped projection of a booking, just enough for the dashboard.
/// Not the final Booking domain model — that arrives with the Booking feature.
enum HomeBookingStatus { upcoming, technicianOnTheWay, serviceInProgress, completed }

class HomeBookingSummary {
  const HomeBookingSummary({
    required this.id,
    required this.serviceName,
    required this.serviceImageAsset,
    required this.vehicleName,
    required this.vehicleYear,
    required this.scheduledAt,
    required this.status,
    this.estimatedArrival,
  });

  final String id;

  /// Already resolved to the requested locale — see [ServiceItem.name].
  final String serviceName;

  /// Semantic asset key resolved by [AssetVisual].
  final String serviceImageAsset;
  final String vehicleName;
  final int vehicleYear;
  final DateTime scheduledAt;
  final HomeBookingStatus status;

  /// Only meaningful while [status] is [HomeBookingStatus.technicianOnTheWay].
  final DateTime? estimatedArrival;
}
