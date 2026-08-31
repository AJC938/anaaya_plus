import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_services_repository.dart';
import '../data/services_repository.dart';
import '../domain/models/service.dart';
import '../domain/models/service_option.dart';

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) => MockServicesRepository());

final servicesListProvider = FutureProvider<List<Service>>((ref) {
  return ref.watch(servicesRepositoryProvider).fetchServices();
});

final serviceByIdProvider = FutureProvider.family<Service?, String>((ref, id) {
  return ref.watch(servicesRepositoryProvider).fetchServiceById(id);
});

final serviceOptionsProvider = FutureProvider.family<List<ServiceOption>, String>((ref, serviceId) {
  return ref.watch(servicesRepositoryProvider).fetchOptions(serviceId);
});

// Deliberately no servicesVehiclesProvider here anymore — vehicle selection
// throughout Booking is backed directly by carsControllerProvider (see
// features/cars/application/cars_providers.dart), the real
// users/{uid}/cars/{carId} data, not a Services-local mock catalog.
