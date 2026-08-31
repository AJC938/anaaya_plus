import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_providers.dart';

/// Owns the "mark as read" mutation — a plain [Notifier], not an
/// [AsyncNotifier], since it has no meaningful data of its own to hold
/// (matching [BookingDraftController]'s shape where a controller's whole
/// job is mutation, not owning fetched state). The Notifications screen
/// reads [notificationsListProvider] directly for its data; this only
/// exists to mutate it and invalidate that provider afterward.
class NotificationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> markAsRead(String notificationId) async {
    final repository = ref.read(notificationRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repository.markAsRead(notificationId));
    if (state.hasError) return;
    ref.invalidate(notificationsListProvider);
  }
}

final notificationControllerProvider = NotifierProvider<NotificationController, AsyncValue<void>>(NotificationController.new);
