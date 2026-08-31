import 'package:flutter/widgets.dart' show Locale;

import '../../cars/data/cars_repository.dart';
import '../../cars/domain/models/vehicle.dart';
import '../../location/domain/models/booking_location.dart';
import '../../scheduling/data/scheduling_repository.dart';
import '../../services/data/services_repository.dart';
import '../../services/domain/models/service_option.dart';
import '../domain/booking_reference.dart';
import '../domain/booking_status_transition.dart';
import '../domain/models/booking.dart';
import '../domain/models/booking_draft.dart';
import '../domain/pricing.dart';
import 'booking_repository.dart';

/// Local/in-memory stand-in for a future Booking repository backed by a
/// real backend. Resolves the draft's ids into real snapshots via the
/// existing Services/Cars repositories — Booking is the top of the
/// dependency chain (`Cars -> Booking`, `Services -> Booking`), so this
/// direction is intentional, never the reverse.
///
/// The artificial delay is only so loading/submitting states are visible
/// when running the app manually.
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({required this.servicesRepository, required this.carsRepository, required this.schedulingRepository});

  final ServicesRepository servicesRepository;
  final CarsRepository carsRepository;
  final SchedulingRepository schedulingRepository;

  static const _latency = Duration(milliseconds: 400);

  /// Real bookings created via [createBooking], keyed by reference.
  final Map<String, Booking> _bookings = {};

  @override
  Future<Booking> createBooking(BookingDraft draft, Locale locale) async {
    await Future.delayed(_latency);

    final location = draft.location;
    final date = draft.date;
    final timeSlot = draft.timeSlot;
    if (location == null || date == null || timeSlot == null) {
      throw StateError('createBooking called with an incomplete draft');
    }

    // Never trust that the slot chosen earlier in the flow is still open.
    final currentSlots = await schedulingRepository.fetchTimeSlots(serviceId: draft.serviceId, date: date);
    final stillAvailable = currentSlots.any((slot) => slot.id == timeSlot.id && slot.isAvailable);
    if (!stillAvailable) {
      throw const BookingSlotUnavailableException();
    }

    final service = await servicesRepository.fetchServiceById(draft.serviceId);
    if (service == null) {
      throw StateError('Service ${draft.serviceId} not found');
    }

    final vehicles = await carsRepository.getVehicles();
    Vehicle? vehicle;
    for (final candidate in vehicles) {
      if (candidate.id == draft.vehicleId) {
        vehicle = candidate;
        break;
      }
    }
    if (vehicle == null) {
      throw StateError('Vehicle ${draft.vehicleId} not found');
    }

    ServiceOption? option;
    if (draft.serviceOptionId != null) {
      final options = await servicesRepository.fetchOptions(draft.serviceId);
      for (final candidate in options) {
        if (candidate.id == draft.serviceOptionId) {
          option = candidate;
          break;
        }
      }
    }

    final price = calculateBookingPrice(basePrice: service.startingPrice, optionPrice: option?.price ?? 0);

    final booking = Booking(
      id: generateBookingReference(),
      serviceId: service.id,
      serviceName: service.name(locale),
      serviceImageAsset: service.imageAsset,
      serviceOptionId: option?.id,
      serviceOptionName: option?.name(locale),
      vehicleId: vehicle.id,
      vehicleName: vehicle.displayName,
      vehicleYear: vehicle.year,
      plateNumber: vehicle.plateNumber,
      location: location,
      scheduledAt: timeSlot.start,
      price: price,
      status: BookingStatus.upcoming,
      createdAt: DateTime.now(),
    );

    _bookings[booking.id] = booking;
    return booking;
  }

  @override
  Future<Booking?> fetchBookingById(String id, Locale locale) async {
    await Future.delayed(_latency);
    if (_bookings.containsKey(id)) return _bookings[id];
    return _demoBooking(id, locale);
  }

  /// Only real bookings created via [createBooking] this session can have
  /// their status advanced — the fixed demo bookings are regenerated fresh
  /// on every [fetchBookingById]/[getBookings] call (see [_demoBooking]),
  /// so there is nothing persistent there to mutate.
  @override
  Future<Booking> updateBookingStatus({required String bookingReference, required BookingStatus newStatus}) async {
    await Future.delayed(_latency);
    final current = _bookings[bookingReference];
    if (current == null) {
      throw StateError('Booking $bookingReference not found');
    }
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
    _bookings[bookingReference] = updated;
    return updated;
  }

  /// Mirrors [updateBookingStatus]'s validation exactly, targeting
  /// [BookingStatus.cancelled] specifically. No slot-claim release happens
  /// here — unlike [FirestoreBookingRepository], this mock never persists a
  /// separate slot-claim record in the first place ([MockSchedulingRepository]
  /// derives availability procedurally from [_bookings] itself), so there is
  /// nothing to release.
  @override
  Future<Booking> cancelBooking({required String bookingReference}) async {
    await Future.delayed(_latency);
    final current = _bookings[bookingReference];
    if (current == null) {
      throw StateError('Booking $bookingReference not found');
    }
    if (!isValidBookingStatusTransition(from: current.status, to: BookingStatus.cancelled)) {
      throw InvalidBookingStatusTransitionException(from: current.status, to: BookingStatus.cancelled);
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
      status: BookingStatus.cancelled,
      estimatedArrival: current.estimatedArrival,
      createdAt: current.createdAt,
    );
    _bookings[bookingReference] = updated;
    return updated;
  }

  static const _demoIds = ['demo-upcoming', 'demo-on-the-way', 'demo-in-progress', 'demo-completed', 'demo-cancelled'];

  @override
  Future<List<Booking>> getBookings(Locale locale) async {
    await Future.delayed(_latency);
    return [..._bookings.values, for (final id in _demoIds) _demoBooking(id, locale)!];
  }

  // Fixed-id demo bookings so every BookingStatus can be reached directly
  // (e.g. while developing/QA-ing Tracking) without going through the full
  // creation flow each time.
  Booking? _demoBooking(String id, Locale locale) {
    final ar = locale.languageCode == 'ar';
    const location = BookingLocation(
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
    final now = DateTime.now();

    switch (id) {
      case 'demo-upcoming':
        return Booking(
          id: 'AN-20481',
          serviceId: 's1',
          serviceName: ar ? 'تغيير الزيت' : 'Oil Change',
          serviceImageAsset: 'oil_change',
          serviceOptionId: 'opt-oil-full',
          serviceOptionName: ar ? 'صناعي كامل' : 'Full Synthetic',
          vehicleId: 'v1',
          vehicleName: 'Toyota Camry',
          vehicleYear: 2023,
          plateNumber: 'ABC 1234',
          location: location,
          scheduledAt: now.add(const Duration(hours: 26)),
          price: calculateBookingPrice(basePrice: 89, optionPrice: 60),
          status: BookingStatus.upcoming,
          createdAt: now.subtract(const Duration(hours: 2)),
        );
      case 'demo-on-the-way':
        return Booking(
          id: 'AN-20482',
          serviceId: 's1',
          serviceName: ar ? 'تغيير الزيت' : 'Oil Change',
          serviceImageAsset: 'oil_change',
          serviceOptionId: 'opt-oil-semi',
          serviceOptionName: ar ? 'نصف صناعي' : 'Semi-Synthetic',
          vehicleId: 'v1',
          vehicleName: 'Toyota Camry',
          vehicleYear: 2023,
          plateNumber: 'ABC 1234',
          location: location,
          scheduledAt: now,
          price: calculateBookingPrice(basePrice: 89, optionPrice: 40),
          status: BookingStatus.technicianOnTheWay,
          estimatedArrival: now.add(const Duration(minutes: 18)),
          createdAt: now.subtract(const Duration(days: 1)),
        );
      case 'demo-in-progress':
        return Booking(
          id: 'AN-20483',
          serviceId: 's2',
          serviceName: ar ? 'فحص شامل' : 'Full Inspection',
          serviceImageAsset: 'full_inspection',
          vehicleId: 'v2',
          vehicleName: 'Hyundai Tucson',
          vehicleYear: 2024,
          plateNumber: 'XYZ 5678',
          location: location,
          scheduledAt: now.subtract(const Duration(minutes: 20)),
          price: calculateBookingPrice(basePrice: 149),
          status: BookingStatus.inProgress,
          createdAt: now.subtract(const Duration(days: 1)),
        );
      case 'demo-completed':
        return Booking(
          id: 'AN-20470',
          serviceId: 's7',
          serviceName: ar ? 'غسيل السيارة' : 'Car Wash',
          serviceImageAsset: 'car_wash',
          vehicleId: 'v1',
          vehicleName: 'Toyota Camry',
          vehicleYear: 2023,
          plateNumber: 'ABC 1234',
          location: location,
          scheduledAt: now.subtract(const Duration(days: 3)),
          price: calculateBookingPrice(basePrice: 39),
          status: BookingStatus.completed,
          createdAt: now.subtract(const Duration(days: 4)),
        );
      case 'demo-cancelled':
        return Booking(
          id: 'AN-20465',
          serviceId: 's4',
          serviceName: ar ? 'خدمة الفرامل' : 'Brake Service',
          serviceImageAsset: 'brake_service',
          vehicleId: 'v2',
          vehicleName: 'Hyundai Tucson',
          vehicleYear: 2024,
          plateNumber: 'XYZ 5678',
          location: location,
          scheduledAt: now.subtract(const Duration(days: 1)),
          price: calculateBookingPrice(basePrice: 199),
          status: BookingStatus.cancelled,
          createdAt: now.subtract(const Duration(days: 2)),
        );
      default:
        return null;
    }
  }
}
