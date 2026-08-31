import 'package:flutter/widgets.dart' show Locale;

import 'package:anaaya_plus/features/booking/data/booking_repository.dart';
import 'package:anaaya_plus/features/booking/domain/booking_status_transition.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking.dart';
import 'package:anaaya_plus/features/booking/domain/models/booking_draft.dart';
import 'package:anaaya_plus/features/booking/domain/pricing.dart';
import 'package:anaaya_plus/features/location/domain/models/booking_location.dart';

const testLocation = BookingLocation(
  id: 'loc-home',
  labelAr: 'المنزل',
  labelEn: 'Home',
  cityAr: 'جدة',
  cityEn: 'Jeddah',
  districtAr: 'حي الزهراء',
  districtEn: 'Al Zahra District',
  addressLineAr: 'شارع الأمير سلطان',
  addressLineEn: 'Prince Sultan Street',
  latitude: 21.5896,
  longitude: 39.1547,
  isSimulatedCurrentLocation: false,
);

/// A [BookingRepository] with no artificial latency and controllable
/// outcomes — widget tests that only care about the UI's reaction to
/// success/failure use this instead of the real mock (whose realistic,
/// chained latency is exercised directly in mock_booking_repository_test.dart).
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.onCreate, this.onGetBookings, this.onUpdateStatus, this.onCancel});

  /// Return a [Booking] for success, or throw for failure — defaults to a
  /// simple successful booking.
  Future<Booking> Function(BookingDraft draft, Locale locale)? onCreate;

  /// Overrides [getBookings] entirely — a [Completer]'s future for a
  /// loading test, a throwing closure for an error test. Defaults to
  /// returning whatever is in [bookings].
  Future<List<Booking>> Function()? onGetBookings;

  /// Overrides [updateBookingStatus] entirely — a throwing closure for an
  /// error-path test. Defaults to a real in-memory mutation that enforces
  /// [isValidBookingStatusTransition] the same way the real repositories do,
  /// so most tests get realistic transition behavior for free.
  Future<Booking> Function(String bookingReference, BookingStatus newStatus)? onUpdateStatus;

  /// Overrides [cancelBooking] entirely — a throwing closure for an
  /// error-path test. Defaults to a real in-memory mutation that enforces
  /// [isValidBookingStatusTransition] the same way the real repositories do.
  Future<Booking> Function(String bookingReference)? onCancel;

  final Map<String, Booking> bookings = {};

  @override
  Future<Booking> createBooking(BookingDraft draft, Locale locale) async {
    final booking = onCreate != null ? await onCreate!(draft, locale) : _defaultBooking(draft);
    bookings[booking.id] = booking;
    return booking;
  }

  @override
  Future<Booking?> fetchBookingById(String id, Locale locale) async => bookings[id];

  @override
  Future<List<Booking>> getBookings(Locale locale) => onGetBookings != null ? onGetBookings!() : Future.value(bookings.values.toList());

  @override
  Future<Booking> updateBookingStatus({required String bookingReference, required BookingStatus newStatus}) {
    if (onUpdateStatus != null) return onUpdateStatus!(bookingReference, newStatus);
    return _defaultUpdateStatus(bookingReference, newStatus);
  }

  Future<Booking> _defaultUpdateStatus(String bookingReference, BookingStatus newStatus) async {
    final current = bookings[bookingReference];
    if (current == null) throw StateError('Booking $bookingReference not found');
    if (!isValidBookingStatusTransition(from: current.status, to: newStatus)) {
      throw InvalidBookingStatusTransitionException(from: current.status, to: newStatus);
    }
    final updated = Booking(
      id: current.id,
      serviceId: current.serviceId,
      serviceName: current.serviceName,
      serviceImageAsset: current.serviceImageAsset,
      serviceOptionId: current.serviceOptionId,
      serviceOptionName: current.serviceOptionName,
      vehicleId: current.vehicleId,
      vehicleName: current.vehicleName,
      vehicleYear: current.vehicleYear,
      plateNumber: current.plateNumber,
      location: current.location,
      scheduledAt: current.scheduledAt,
      price: current.price,
      status: newStatus,
      estimatedArrival: newStatus == BookingStatus.technicianOnTheWay
          ? DateTime.now().add(const Duration(minutes: 15))
          : current.estimatedArrival,
      createdAt: current.createdAt,
    );
    bookings[bookingReference] = updated;
    return updated;
  }

  @override
  Future<Booking> cancelBooking({required String bookingReference}) {
    if (onCancel != null) return onCancel!(bookingReference);
    return _defaultUpdateStatus(bookingReference, BookingStatus.cancelled);
  }

  Booking _defaultBooking(BookingDraft draft) {
    return Booking(
      id: 'AN-00001',
      serviceId: draft.serviceId,
      serviceName: 'Oil Change',
      serviceImageAsset: 'oil_change',
      serviceOptionId: draft.serviceOptionId,
      serviceOptionName: draft.serviceOptionId != null ? 'Full Synthetic' : null,
      vehicleId: draft.vehicleId,
      vehicleName: 'Toyota Camry',
      vehicleYear: 2023,
      plateNumber: 'ABC 1234',
      location: draft.location ?? testLocation,
      scheduledAt: draft.timeSlot?.start ?? DateTime.now(),
      price: calculateBookingPrice(basePrice: 89),
      status: BookingStatus.upcoming,
      createdAt: DateTime.now(),
    );
  }
}
