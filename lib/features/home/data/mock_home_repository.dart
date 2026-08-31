import 'package:flutter/widgets.dart' show Locale;

import '../domain/models/home_booking_summary.dart';
import '../domain/models/home_user.dart';
import '../domain/models/offer.dart';
import '../domain/models/service_item.dart';
import '../domain/models/vehicle_summary.dart';
import 'home_repository.dart';

/// Which realistic backend state the mock data should represent. Lets the
/// running app and the test suite exercise every Home state without a real
/// backend, and keeps the mock booking/vehicle data mutually consistent
/// (e.g. no booking is ever generated for a scenario with no vehicle).
enum HomeMockScenario { upcomingBooking, technicianOnTheWay, serviceInProgress, completed, noActiveBooking, noVehicle }

/// Local/in-memory stand-in for a future Home repository backed by Firestore.
/// The artificial delay is only so the loading/skeleton states are visible
/// when running the app manually — see [HomeRepository] for the real seam.
class MockHomeRepository implements HomeRepository {
  MockHomeRepository({this.scenario = HomeMockScenario.upcomingBooking});

  final HomeMockScenario scenario;

  static const _latency = Duration(milliseconds: 400);

  static bool _isAr(Locale locale) => locale.languageCode == 'ar';

  static final _vehicles = [
    const VehicleSummary(
      id: 'v1',
      make: 'Toyota',
      model: 'Camry',
      year: 2023,
      plateNumber: 'ABC 1234',
      imageAsset: 'vehicle_sedan',
    ),
    const VehicleSummary(
      id: 'v2',
      make: 'Hyundai',
      model: 'Tucson',
      year: 2024,
      plateNumber: 'XYZ 5678',
      imageAsset: 'vehicle_suv',
    ),
  ];

  // id -> (category, startingPrice, imageAsset, nameAr, nameEn)
  static const _serviceCatalog = [
    ('s1', 'maintenance', 89.0, 'oil_change', 'تغيير الزيت', 'Oil Change'),
    ('s2', 'inspection', 149.0, 'full_inspection', 'فحص شامل', 'Full Inspection'),
    ('s3', 'seasonal', 129.0, 'ac_service', 'خدمة التكييف', 'AC Service'),
    ('s4', 'safety', 199.0, 'brake_service', 'خدمة الفرامل', 'Brake Service'),
    ('s5', 'tires', 99.0, 'tires', 'الإطارات', 'Tires'),
    ('s6', 'battery', 179.0, 'battery', 'البطارية', 'Battery'),
    ('s7', 'cleaning', 39.0, 'car_wash', 'غسيل السيارة', 'Car Wash'),
    ('s8', 'care', 59.0, 'car_care', 'العناية بالسيارة', 'Car Care'),
  ];

  @override
  Future<HomeUser> fetchUser() async {
    await Future.delayed(_latency);
    return const HomeUser(id: 'u1', name: 'Abdullah');
  }

  @override
  Future<List<VehicleSummary>> fetchVehicles() async {
    await Future.delayed(_latency);
    return scenario == HomeMockScenario.noVehicle ? const [] : _vehicles;
  }

  @override
  Future<List<ServiceItem>> fetchServices(Locale locale) async {
    await Future.delayed(_latency);
    final ar = _isAr(locale);
    return _serviceCatalog
        .map(
          (s) => ServiceItem(
            id: s.$1,
            category: s.$2,
            startingPrice: s.$3,
            imageAsset: s.$4,
            name: ar ? s.$5 : s.$6,
          ),
        )
        .toList();
  }

  @override
  Future<List<Offer>> fetchOffers(Locale locale) async {
    await Future.delayed(_latency);
    final ar = _isAr(locale);
    return [
      Offer(
        id: 'o1',
        imageAsset: 'car_wash',
        title: ar ? 'غسيل مجاني' : 'Free Car Wash',
        description: ar
            ? 'احصل على غسيل خارجي مجاني مع أول حجز لك.'
            : 'Get a free exterior wash with your first booking.',
        badgeLabel: ar ? 'مجاني' : 'Free',
        ctaLabel: ar ? 'احجز الآن' : 'Book Now',
      ),
      Offer(
        id: 'o2',
        imageAsset: 'full_inspection',
        title: ar ? 'خصم على الفحص الشامل' : 'Full Inspection Discount',
        description: ar ? 'خصم 20% على الفحص الشامل هذا الشهر.' : '20% off Full Inspection this month.',
        badgeLabel: '20%',
        ctaLabel: ar ? 'احصل على العرض' : 'Claim Offer',
      ),
    ];
  }

  @override
  Future<HomeBookingSummary?> fetchActiveBooking(Locale locale) async {
    await Future.delayed(_latency);
    final now = DateTime.now();
    final oilChangeName = _isAr(locale) ? 'تغيير الزيت' : 'Oil Change';
    switch (scenario) {
      case HomeMockScenario.noVehicle:
      case HomeMockScenario.noActiveBooking:
        return null;
      case HomeMockScenario.upcomingBooking:
        // Ids match MockBookingRepository's fixed demo bookings, so the
        // Track Service CTA lands on a real, resolvable booking instead of
        // a dead end — see BookingStatusCard.
        return HomeBookingSummary(
          id: 'demo-upcoming',
          serviceName: oilChangeName,
          serviceImageAsset: 'oil_change',
          vehicleName: _vehicles.first.displayName,
          vehicleYear: _vehicles.first.year,
          scheduledAt: now.add(const Duration(hours: 2, minutes: 18)),
          status: HomeBookingStatus.upcoming,
        );
      case HomeMockScenario.technicianOnTheWay:
        return HomeBookingSummary(
          id: 'demo-on-the-way',
          serviceName: oilChangeName,
          serviceImageAsset: 'oil_change',
          vehicleName: _vehicles.first.displayName,
          vehicleYear: _vehicles.first.year,
          scheduledAt: now,
          status: HomeBookingStatus.technicianOnTheWay,
          estimatedArrival: now.add(const Duration(minutes: 18)),
        );
      case HomeMockScenario.serviceInProgress:
        return HomeBookingSummary(
          id: 'demo-in-progress',
          serviceName: oilChangeName,
          serviceImageAsset: 'oil_change',
          vehicleName: _vehicles.first.displayName,
          vehicleYear: _vehicles.first.year,
          scheduledAt: now.subtract(const Duration(minutes: 10)),
          status: HomeBookingStatus.serviceInProgress,
        );
      case HomeMockScenario.completed:
        return HomeBookingSummary(
          id: 'demo-completed',
          serviceName: oilChangeName,
          serviceImageAsset: 'oil_change',
          vehicleName: _vehicles.first.displayName,
          vehicleYear: _vehicles.first.year,
          scheduledAt: now.subtract(const Duration(hours: 1)),
          status: HomeBookingStatus.completed,
        );
    }
  }
}
