import '../domain/models/booking_location.dart';
import 'location_repository.dart';

/// Local/in-memory stand-in for a future Location repository backed by a
/// real Places/Maps provider. "Current Location" is never represented
/// here — see `CurrentLocationController`, a completely separate, real
/// GPS-backed concept this repository has nothing to do with.
///
/// The artificial delay is only so the loading state is visible when
/// running the app manually.
class MockLocationRepository implements LocationRepository {
  MockLocationRepository({List<BookingLocation>? seedLocations})
    : _locations = List.of(seedLocations ?? _defaultLocations);

  static const _latency = Duration(milliseconds: 400);

  static const _defaultLocations = [
    BookingLocation(
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
    ),
    BookingLocation(
      id: 'loc-work',
      labelAr: 'العمل',
      labelEn: 'Work',
      cityAr: 'جدة',
      cityEn: 'Jeddah',
      districtAr: 'حي الروضة',
      districtEn: 'Al Rawdah District',
      addressLineAr: 'طريق الملك عبدالعزيز',
      addressLineEn: 'King Abdulaziz Road',
      latitude: 21.5645,
      longitude: 39.1758,
      isSimulatedCurrentLocation: false,
    ),
  ];

  int _nextId = 1;
  final List<BookingLocation> _locations;

  @override
  Future<List<BookingLocation>> fetchSavedLocations() async {
    await Future.delayed(_latency);
    return List.unmodifiable(_locations);
  }

  @override
  Future<BookingLocation> addLocation(BookingLocation location) async {
    await Future.delayed(_latency);
    final created = BookingLocation(
      id: 'loc-new-${_nextId++}',
      labelAr: location.labelAr,
      labelEn: location.labelEn,
      cityAr: location.cityAr,
      cityEn: location.cityEn,
      districtAr: location.districtAr,
      districtEn: location.districtEn,
      addressLineAr: location.addressLineAr,
      addressLineEn: location.addressLineEn,
      latitude: location.latitude,
      longitude: location.longitude,
      isSimulatedCurrentLocation: false,
    );
    _locations.add(created);
    return created;
  }

  @override
  Future<BookingLocation> updateLocation(BookingLocation location) async {
    await Future.delayed(_latency);
    final index = _locations.indexWhere((existing) => existing.id == location.id);
    if (index == -1) {
      throw StateError('Location ${location.id} not found');
    }
    _locations[index] = location;
    return location;
  }

  @override
  Future<void> deleteLocation(String id) async {
    await Future.delayed(_latency);
    _locations.removeWhere((location) => location.id == id);
  }
}
