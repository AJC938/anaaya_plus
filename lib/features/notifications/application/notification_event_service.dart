import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../booking/domain/models/booking.dart' show BookingStatus;
import '../../payment/domain/models/payment.dart' show PaymentStatus;
import '../domain/notification_event_mapper.dart';
import 'notification_providers.dart';

/// The one place BE-08 hooks into the Booking/Payment Engines' own success
/// paths — never the other way around. `BookingStatusController`/
/// `PaymentController` call this *after* their own mutation has already
/// succeeded; this service never touches booking or payment state itself
/// (see Phase 7's own rule: the Booking/Payment Engines stay the sole
/// source of truth for their state, notifications only observe it).
///
/// Resolves [AppLocalizations] from the current [localeProvider] value via
/// `lookupAppLocalizations` (the generated l10n package's own
/// context-free lookup) rather than requiring a `BuildContext` — this is
/// what lets notification creation live entirely in the controller layer,
/// matching Phase 2's expected "domain -> repository -> ... -> application
/// controller" layering, instead of being scattered into widget event
/// handlers.
///
/// Every method here is deliberately best-effort: a failure to record a
/// notification (offline, a transient Firestore error) must never undo or
/// even be reported as failing the booking/payment mutation that already
/// genuinely succeeded — the exact same reasoning
/// `PhoneAuthController._ensureUserDocument` already established for
/// provisioning `users/{uid}` after a successful sign-in.
class NotificationEventService {
  NotificationEventService(this._ref);

  final Ref _ref;

  AppLocalizations get _l10n => lookupAppLocalizations(_ref.read(localeProvider));

  Future<void> recordBookingCreated({required String bookingReference}) {
    final content = notificationForBookingCreated(l10n: _l10n, bookingReference: bookingReference);
    return _record(content, bookingReference);
  }

  Future<void> recordBookingStatusChange({required BookingStatus to, required String bookingReference}) {
    final content = notificationForBookingStatusChange(to: to, l10n: _l10n, bookingReference: bookingReference);
    return _record(content, bookingReference);
  }

  Future<void> recordPaymentStatus({required PaymentStatus status, required String bookingReference}) {
    final content = notificationForPaymentStatus(status: status, l10n: _l10n, bookingReference: bookingReference);
    if (content == null) return Future.value();
    return _record(content, bookingReference);
  }

  Future<void> _record(NotificationContent content, String bookingReference) async {
    try {
      await _ref
          .read(notificationRepositoryProvider)
          .recordNotification(type: content.type, title: content.title, body: content.body, bookingReference: bookingReference);
      // So the Notifications screen/unread badge reflect the new entry
      // immediately instead of showing whatever it last fetched — matches
      // every other controller's own reasoning for invalidating a list
      // provider on a successful mutation.
      _ref.invalidate(notificationsListProvider);
    } catch (_) {
      // Best-effort — see this class's own doc comment.
    }
  }
}

final notificationEventServiceProvider = Provider((ref) => NotificationEventService(ref));
