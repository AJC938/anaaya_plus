import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_scheduling_repository.dart';
import '../data/scheduling_repository.dart';
import '../domain/models/availability_day.dart';
import '../domain/models/time_slot.dart';

/// Backed by the global, shared `serviceSlots` collection — see
/// [FirestoreSchedulingRepository]. Unlike Cars/Location/Booking, slot
/// availability isn't user-scoped, so this doesn't depend on
/// [authStateChangesProvider] the way those repositories' providers do —
/// any authenticated user reads the same availability.
final schedulingRepositoryProvider = Provider<SchedulingRepository>((ref) => FirestoreSchedulingRepository());

final availableDatesProvider = FutureProvider.family<List<AvailabilityDay>, String>((ref, serviceId) {
  return ref.watch(schedulingRepositoryProvider).fetchAvailableDates(serviceId: serviceId);
});

/// Keyed by (serviceId, date) — a record compares by value, so picking a
/// different date is a genuinely different cache entry.
typedef TimeSlotsQuery = ({String serviceId, DateTime date});

final timeSlotsProvider = FutureProvider.family<List<TimeSlot>, TimeSlotsQuery>((ref, query) {
  return ref.watch(schedulingRepositoryProvider).fetchTimeSlots(serviceId: query.serviceId, date: query.date);
});
