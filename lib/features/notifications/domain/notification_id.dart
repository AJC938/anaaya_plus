import 'models/notification_type.dart';

/// The deterministic Firestore document id for a booking-scoped
/// notification — `{bookingReference}_{type}`, e.g.
/// `"AN-20481_technicianOnTheWay"`. This is BE-08's entire idempotency
/// mechanism (Phase 11): writing with `.set()` under this exact id, rather
/// than an auto-id via `.add()`, means the same business event — an FCM
/// callback firing twice, a widget rebuild, a Riverpod refresh, an app
/// restart replaying an already-handled Firestore read — can never produce
/// two persisted notification records. It overwrites the same one, which is
/// always safe: the fields it would write are identical every time for a
/// given (bookingReference, type) pair (see `notification_event_mapper.dart`).
///
/// One deliberate consequence: a booking can only ever have ONE stored
/// notification per [NotificationType] — e.g. a second `paymentFailed`
/// after a first failed retry overwrites (not duplicates) the earlier one.
/// This is intentional, not a limitation: repeated identical failures
/// notifying the user again with the same message would just be noise, and
/// nothing in this milestone's product requirements needs a full attempt
/// history (mirrors `FirestorePaymentRepository`'s own single-document
/// `payment/latest` reasoning from BE-07).
String notificationIdFor({required String bookingReference, required NotificationType type}) {
  return '${bookingReference}_${type.name}';
}
