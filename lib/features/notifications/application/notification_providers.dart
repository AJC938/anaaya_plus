import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/device_token_repository.dart';
import '../data/firestore_device_token_repository.dart';
import '../data/firestore_notification_repository.dart';
import '../data/notification_repository.dart';
import '../domain/models/app_notification.dart';

/// Mirrors `bookingRepositoryProvider`'s exact shape — scoped to the
/// signed-in user's uid, rebuilds on sign-in/sign-out, throws rather than
/// returning a placeholder when signed out.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;
  if (uid == null) {
    throw StateError('notificationRepositoryProvider requires an authenticated user.');
  }
  return FirestoreNotificationRepository(uid: uid);
});

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  final uid = ref.watch(authStateChangesProvider).value;
  if (uid == null) {
    throw StateError('deviceTokenRepositoryProvider requires an authenticated user.');
  }
  return FirestoreDeviceTokenRepository(uid: uid);
});

/// Backs the Notifications screen — not `autoDispose`, matching
/// `bookingsListProvider`'s own reasoning (must stay cached while the
/// screen sits offstage), explicitly invalidated after a new notification
/// is recorded or one is marked read.
final notificationsListProvider = FutureProvider<List<AppNotification>>((ref) async {
  await ref.watch(authStateChangesProvider.future);
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

/// Derived, not independently fetched — the unread count is always exactly
/// "however many of the already-loaded notifications aren't read yet", so
/// this stays trivially consistent with [notificationsListProvider] rather
/// than becoming a second source of truth that could drift from it.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsListProvider).value ?? const [];
  return notifications.where((n) => !n.isRead).length;
});
