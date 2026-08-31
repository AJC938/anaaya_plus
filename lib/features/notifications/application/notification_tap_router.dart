import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

/// Resolves an incoming [RemoteMessage]'s data payload to a navigation
/// action — the one place BE-08 decides what a notification tap actually
/// does, shared by all three trigger paths (Phase 10): a tap while the app
/// is foregrounded/backgrounded (`onMessageOpenedApp`) and a cold-start tap
/// (`getInitialMessage`, checked once at app startup).
///
/// Deliberately does NOT create a new screen — every booking-scoped
/// notification routes to the exact same Tracking destination the rest of
/// the app already uses (`AppRoutes.bookingTracking`), keyed by
/// `bookingReference` (the same value every `TrackingScreen(bookingId:)`
/// call in this app has always used — see `booking_list_card.dart`/
/// `confirmation_screen.dart`). [GoRouter.push] — not `go` — so a tap never
/// discards whatever the user was already doing; it also flows through the
/// router's own existing `redirect` (auth) check exactly like any other
/// navigation, so a signed-out user tapping a notification still lands on
/// sign-in first, never bypassing authentication. A booking that's since
/// been deleted/inaccessible is handled by `TrackingScreen`'s own existing
/// "not found" state — nothing extra is needed here for that.
class NotificationTapRouter {
  NotificationTapRouter(this._router);

  final GoRouter _router;

  void handleMessage(RemoteMessage message) {
    final bookingReference = message.data['bookingReference'] as String?;
    if (bookingReference == null || bookingReference.isEmpty) return;
    _router.push(AppRoutes.bookingTracking(bookingReference));
  }
}

/// Registered once via `FirebaseMessaging.onBackgroundMessage` — required
/// by the plugin to be a top-level (or static) function annotated exactly
/// like this, since it runs in its own background isolate, separate from
/// the app's main isolate and widget tree.
///
/// This milestone sends "notification" messages (title/body set), which
/// the OS already displays automatically while the app is backgrounded or
/// terminated — no app code is needed for that display. This handler is
/// the documented extension point FCM requires to exist for background
/// delivery to work at all; it intentionally does no extra work here, since
/// nothing in this milestone's scope needs background *data* processing
/// (e.g. silently updating local state before the user ever opens the
/// notification) beyond what already happens when the app is next opened
/// and its providers re-fetch normally.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
