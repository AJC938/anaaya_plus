import '../domain/models/service.dart';
import '../domain/models/service_option.dart';

/// Data seam for the Services feature. [MockServicesRepository] is the only
/// implementation for this milestone; a Firebase-backed implementation can
/// replace it later without the Services widgets or providers changing.
///
/// Unlike Home's repository, content here isn't pre-localized — [Service]
/// and [ServiceOption] carry both language variants directly (see their
/// `.name(locale)` getters), so these calls don't take a [Locale].
///
/// Deliberately has no `fetchVehicles()` — vehicle selection is backed
/// directly by the real Cars data (`carsControllerProvider`), never a
/// Services-local catalog. See `ServiceDetailsScreen`'s `_VehicleSection`.
abstract class ServicesRepository {
  Future<List<Service>> fetchServices();

  /// Null if no service with this id exists (e.g. a stale deep link).
  Future<Service?> fetchServiceById(String id);
  Future<List<ServiceOption>> fetchOptions(String serviceId);
}
