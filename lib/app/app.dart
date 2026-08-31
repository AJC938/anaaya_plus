import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/notifications/application/fcm_service.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/notifications/application/notification_tap_router.dart';
import 'router/app_router.dart';

class AnaayaPlusApp extends ConsumerStatefulWidget {
  // `router` is kept as the public parameter name — `this._router` would
  // force external callers to use the private field name instead.
  // ignore: prefer_initializing_formals
  const AnaayaPlusApp({super.key, GoRouter? router}) : _router = router;

  /// Defaults to the shared [appRouter] singleton. Tests pass their own
  /// instance (see [createAppRouter]) to get a clean navigation slate with
  /// no state left over from a previous test.
  final GoRouter? _router;

  @override
  ConsumerState<AnaayaPlusApp> createState() => _AnaayaPlusAppState();
}

class _AnaayaPlusAppState extends ConsumerState<AnaayaPlusApp> {
  GoRouter get _router => widget._router ?? appRouter;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  ProviderSubscription<AsyncValue<String?>>? _authSubscription;

  /// `flutter test` sets this environment variable on its own process —
  /// the standard, documented way to detect a test run without importing
  /// `package:flutter_test` (a dev-only dependency with no place in
  /// production code) into production code. Every one of this project's
  /// hundreds of existing widget tests constructs this exact widget without
  /// knowing anything about FCM, and none of them can fake
  /// `FirebaseMessaging.instance` (there is no Riverpod provider standing
  /// in front of it, unlike every other Firebase-touching seam in this
  /// app) — without this check, `FirebaseMessaging.instance` throws
  /// immediately in `initState` (Firebase.initializeApp() is never called
  /// under `flutter test`), and every single pre-existing test would start
  /// failing the moment this widget mounted, which is exactly the
  /// regression this line exists to prevent.
  bool get _isRunningInTests => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (!_isRunningInTests) _bootstrapNotifications();
  }

  /// BE-08's entire FCM bootstrap, run once per app process. Kept out of
  /// build() deliberately (this sets up long-lived stream subscriptions and
  /// performs one-shot startup checks, not something that should re-run on
  /// every rebuild). Every step here is best-effort — a permission denial,
  /// an unavailable token, or a transient error must never crash app
  /// startup (matches every other cross-cutting best-effort path in this
  /// project, e.g. `PhoneAuthController._ensureUserDocument`). Every
  /// callback also checks `mounted` before touching `ref` — defense in
  /// depth against an async FCM callback resolving after this State has
  /// already been disposed (e.g. a very fast app-shutdown race), not just
  /// the test-environment case `_isRunningInTests` already rules out.
  void _bootstrapNotifications() {
    final tapRouter = NotificationTapRouter(_router);

    // Token registration/refresh is tied to auth state reactively (not a
    // one-shot call from the sign-in flow) — this is what makes a
    // returning, already-signed-in user's cold start register a token too,
    // not just a fresh sign-in. See FcmDeviceTokenSync's own doc comment.
    _authSubscription = ref.listenManual(authStateChangesProvider, (previous, next) {
      if (!mounted) return;
      unawaited(ref.read(fcmDeviceTokenSyncProvider).syncForUid(next.value));
    }, fireImmediately: true);

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (!mounted) return;
      unawaited(ref.read(fcmDeviceTokenSyncProvider).handleTokenRefresh(token));
    });

    // Foreground handling (Phase 8/Phase 5's "foreground notification
    // handling"): FCM deliberately does NOT auto-display a system
    // notification while the app is in the foreground (the OS assumes the
    // app itself will surface it) — this refreshes the notification
    // history/unread badge so the in-app surface picks up whatever
    // Firestore record the sender wrote alongside the push, without
    // introducing a separate local-notification package just to mirror the
    // system tray while the app is already open.
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      ref.invalidate(notificationsListProvider);
    });

    // Background tap: the app was backgrounded/killed-but-resumable, the OS
    // displayed the system notification, the user tapped it.
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(tapRouter.handleMessage);

    // Cold-start tap: the app was fully terminated and this notification
    // tap is literally what launched it — checked once, here, rather than
    // assumed to already be on Tracking (Phase 10's explicit requirement).
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message == null) return;
      // Wait for Firebase Auth to restore (or fail to restore) the
      // session before pushing. `getInitialMessage()` can resolve before
      // `currentUserUid` is populated on a genuine cold start — pushing
      // immediately would navigate while `redirect` still sees "signed
      // out", sending this to /auth/phone; the moment auth then resolves,
      // `GoRouterRefreshStream` re-runs `redirect` on that now-current
      // location and bounces it straight to Home, silently discarding the
      // deep link instead of landing on Tracking.
      await ref.read(authStateChangesProvider.future);
      if (!mounted) return;
      tapRouter.handleMessage(message);
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: _router,
    );
  }
}
