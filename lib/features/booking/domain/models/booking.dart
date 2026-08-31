import '../../../location/domain/models/booking_location.dart';
import 'booking_price_breakdown.dart';

enum BookingStatus { upcoming, technicianOnTheWay, inProgress, completed, cancelled }

/// A confirmed booking. Service and vehicle display information are
/// snapshots taken at confirmation time — Tracking must never depend on
/// Cars/Services' live state (a vehicle can be edited or deleted, a service
/// can change, after the booking exists).
class Booking {
  const Booking({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.serviceImageAsset,
    this.serviceOptionId,
    this.serviceOptionName,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleYear,
    required this.plateNumber,
    required this.location,
    required this.scheduledAt,
    required this.price,
    required this.status,
    this.estimatedArrival,
    required this.createdAt,
  });

  /// User-friendly reference, e.g. "AN-20481" — never a raw UUID in the UI.
  final String id;

  final String serviceId;
  final String serviceName;
  final String serviceImageAsset;
  final String? serviceOptionId;
  final String? serviceOptionName;

  final String vehicleId;
  final String vehicleName;
  final int vehicleYear;
  final String plateNumber;

  final BookingLocation location;

  /// Combined date + time of the appointment.
  final DateTime scheduledAt;

  final BookingPriceBreakdown price;
  final BookingStatus status;

  /// Only meaningful while [status] is [BookingStatus.technicianOnTheWay].
  final DateTime? estimatedArrival;

  final DateTime createdAt;
}
