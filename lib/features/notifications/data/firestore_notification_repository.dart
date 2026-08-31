import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/app_notification.dart';
import '../domain/models/notification_type.dart';
import '../domain/notification_id.dart';
import 'notification_repository.dart';

/// Maps a `users/{uid}/notifications/{id}` document's data onto
/// [AppNotification]. Pulled out as a standalone function, matching every
/// other `xFromFirestoreData` in this project, so its null-handling is
/// unit-testable without a real or fake Firestore instance.
AppNotification notificationFromFirestoreData(String id, Map<String, dynamic>? data) {
  final typeName = data?['type'] as String?;
  final type = NotificationType.values.firstWhere(
    (candidate) => candidate.name == typeName,
    // No "unknown" type exists on the enum — falls back to the least
    // alarming type for data that doesn't match any known value, matching
    // `bookingFromFirestoreData`'s own reasoning for its status fallback.
    orElse: () => NotificationType.bookingConfirmed,
  );
  final createdAtTimestamp = data?['createdAt'] as Timestamp?;

  return AppNotification(
    id: id,
    type: type,
    title: data?['title'] as String? ?? '',
    body: data?['body'] as String? ?? '',
    bookingReference: data?['bookingReference'] as String?,
    isRead: data?['isRead'] as bool? ?? false,
    createdAt: createdAtTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Notification
/// history lives at `users/{uid}/notifications/{id}` — lightweight
/// documents only (see [AppNotification]'s own doc comment): never a copy
/// of the booking, only what's needed to display an entry and route a tap.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({
    required String uid,
    FirebaseFirestore? firestore,
    // ignore: prefer_initializing_formals
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('users').doc(_uid).collection('notifications');

  @override
  Future<List<AppNotification>> getNotifications() async {
    final snapshot = await _notificationsRef.orderBy('createdAt', descending: true).get();
    return [for (final doc in snapshot.docs) notificationFromFirestoreData(doc.id, doc.data())];
  }

  @override
  Future<AppNotification> recordNotification({
    required NotificationType type,
    required String title,
    required String body,
    required String? bookingReference,
  }) async {
    final id = bookingReference != null
        ? notificationIdFor(bookingReference: bookingReference, type: type)
        // A hypothetical non-booking-scoped notification (none exists yet
        // in this milestone) has no natural deterministic key to reuse —
        // falls back to a fresh id rather than guessing one.
        : _notificationsRef.doc().id;
    final docRef = _notificationsRef.doc(id);
    // A plain (non-transactional) read-before-write: this isn't a
    // financial/security-critical path like payment amounts, so the rare
    // race of two truly simultaneous duplicate calls both seeing "doesn't
    // exist yet" is an acceptable, low-stakes outcome (createdAt lands a
    // few milliseconds later than the true first call, never wrong by more
    // than that, and the document itself is still never duplicated —
    // both calls write the exact same id).
    final existing = await docRef.get();

    // Merge, and deliberately never write `isRead` here: if this exact
    // (bookingReference, type) was already recorded — the very duplicate
    // call this whole id scheme exists to absorb — re-running this must
    // never silently flip an already-read notification back to unread.
    // A brand-new document simply has no `isRead` field at all, which
    // `notificationFromFirestoreData` already treats as `false` by
    // fallback, so the default is preserved without writing it explicitly.
    // `createdAt` is likewise preserved across a duplicate call — matching
    // `FirestorePaymentRepository.submitPayment`'s identical reasoning for
    // its own createdAt-preserved-across-retries behavior.
    await docRef.set({
      'type': type.name,
      'title': title,
      'body': body,
      'bookingReference': bookingReference,
      'createdAt': existing.exists ? existing.data()!['createdAt'] : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final written = await docRef.get();
    return notificationFromFirestoreData(written.id, written.data());
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef.doc(notificationId).set({'isRead': true}, SetOptions(merge: true));
  }
}
