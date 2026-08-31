import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/phone_number_screen.dart';
import '../../features/booking/presentation/screens/confirmation_screen.dart';
import '../../features/booking/presentation/screens/date_time_screen.dart';
import '../../features/booking/presentation/screens/location_screen.dart';
import '../../features/location/presentation/screens/map_location_picker_screen.dart';
import '../../features/booking/presentation/screens/review_screen.dart';
import '../../features/booking/presentation/screens/tracking_screen.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/bookings/presentation/screens/bookings_screen.dart';
import '../../features/cars/presentation/screens/cars_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/personal_info_screen.dart';
import '../../features/profile/presentation/screens/profile_info_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/cars/presentation/screens/vehicle_form_screen.dart';
import '../../features/services/presentation/screens/service_details_screen.dart';
import '../../features/services/presentation/screens/services_screen.dart';
import '../../core/localization/app_localizations.dart';

abstract final class AppRoutes {
  static const authPhone = '/auth/phone';
  static const authOtp = '/auth/otp';

  static const home = '/home';
  static const bookings = '/bookings';
  static const cars = '/cars';
  static const profile = '/profile';

  // Services is a drill-down flow nested under Home (not its own branch),
  // so it stays within Home's own Navigator and the bottom nav bar stays
  // visible while browsing the catalog and Service Details.
  static const _servicesSegment = 'services';
  static String services() => '$home/$_servicesSegment';
  static String serviceDetails(String serviceId) => '$home/$_servicesSegment/$serviceId';

  // BE-08: reached from the Home bell icon — same "drill-down nested under
  // Home" reasoning as Services, so the bottom nav bar stays visible.
  static String notifications() => '$home/notifications';

  // Add/Edit are drill-downs nested under the Cars branch for the same
  // reason — one Navigator, bottom nav stays visible.
  static String addVehicle() => '$cars/add';
  static String editVehicle(String vehicleId) => '$cars/$vehicleId/edit';

  // The booking creation flow nests under Service Details (same Navigator,
  // bottom nav stays visible, and a pushed flow survives tab-switching per
  // the Foundation tests) — it starts there because the service, option,
  // and vehicle are already chosen on that screen.
  static String bookingLocation(String serviceId) => '${serviceDetails(serviceId)}/book/location';
  static String bookingLocationMap(String serviceId) => '${bookingLocation(serviceId)}/map';
  static String bookingLocationMapEdit(String serviceId, String locationId) => '${bookingLocation(serviceId)}/map/$locationId/edit';
  static String bookingDateTime(String serviceId) => '${serviceDetails(serviceId)}/book/datetime';
  static String bookingReview(String serviceId) => '${serviceDetails(serviceId)}/book/review';
  // BE-07: sits between Review and Confirmation — a booking exists (created
  // by Review's Confirm action, unchanged) by the time this route is ever
  // reached, so it's keyed by bookingId exactly like Confirmation/Tracking
  // are, not by draft state.
  static String bookingPayment(String serviceId, String bookingId) =>
      '${serviceDetails(serviceId)}/book/payment/$bookingId';
  static String bookingConfirmation(String serviceId, String bookingId) =>
      '${serviceDetails(serviceId)}/book/confirmation/$bookingId';

  // Tracking nests under the existing Bookings branch — the natural home
  // for a future "My Bookings" list to link into.
  static String bookingTracking(String bookingId) => '$bookings/$bookingId/tracking';

  // Profile drill-downs — same Navigator, bottom nav stays visible.
  static String profileEdit() => '$profile/edit';
  static String personalInfo() => '$profile/personal-info';
  static String helpSupport() => '$profile/help';
  static String termsConditions() => '$profile/terms';
  static String privacyPolicy() => '$profile/privacy';
}

/// One [Navigator] key per bottom-nav branch, so each tab gets its own,
/// independently addressable navigation stack that go_router's
/// [StatefulShellRoute.indexedStack] keeps alive (offstage) instead of
/// rebuilding whenever the user switches tabs.
abstract final class AppNavigatorKeys {
  static final home = GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
  static final bookings = GlobalKey<NavigatorState>(debugLabel: 'bookingsBranch');
  static final cars = GlobalKey<NavigatorState>(debugLabel: 'carsBranch');
  static final profile = GlobalKey<NavigatorState>(debugLabel: 'profileBranch');
}

/// Bridges a [Stream] (Firebase's `authStateChanges()`) into the
/// [Listenable] go_router's `refreshListenable` expects, so a sign-in or
/// sign-out re-evaluates `redirect` immediately instead of waiting for the
/// next unrelated navigation.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Builds a fresh router instance with the app's full route table. The real
/// app uses the single [appRouter] below; tests that need a clean
/// navigation slate (no state left over from a previous test) build their
/// own instance instead of reusing the shared singleton — and pass their
/// own [authRepository] fake, since the default touches real Firebase.
GoRouter createAppRouter({AuthRepository? authRepository}) {
  final auth = authRepository ?? FirebaseAuthRepository();

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final isAuthenticated = auth.currentUserUid != null;
      final onAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !onAuthRoute) return AppRoutes.authPhone;
      if (isAuthenticated && onAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.authPhone, builder: (context, state) => const PhoneNumberScreen()),
      GoRoute(path: AppRoutes.authOtp, builder: (context, state) => const OtpScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
        StatefulShellBranch(
          navigatorKey: AppNavigatorKeys.home,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'services',
                  builder: (context, state) => const ServicesScreen(),
                  routes: [
                    GoRoute(
                      path: ':serviceId',
                      builder: (context, state) =>
                          ServiceDetailsScreen(serviceId: state.pathParameters['serviceId']!),
                      routes: [
                        GoRoute(
                          path: 'book/location',
                          builder: (context, state) => LocationScreen(serviceId: state.pathParameters['serviceId']!),
                          routes: [
                            GoRoute(
                              path: 'map',
                              builder: (context, state) => const MapLocationPickerScreen(),
                            ),
                            GoRoute(
                              path: 'map/:locationId/edit',
                              builder: (context, state) =>
                                  MapLocationPickerScreen(locationId: state.pathParameters['locationId']!),
                            ),
                          ],
                        ),
                        GoRoute(
                          path: 'book/datetime',
                          builder: (context, state) => DateTimeScreen(serviceId: state.pathParameters['serviceId']!),
                        ),
                        GoRoute(
                          path: 'book/review',
                          builder: (context, state) => ReviewScreen(serviceId: state.pathParameters['serviceId']!),
                        ),
                        GoRoute(
                          path: 'book/payment/:bookingId',
                          builder: (context, state) => PaymentScreen(
                            serviceId: state.pathParameters['serviceId']!,
                            bookingId: state.pathParameters['bookingId']!,
                          ),
                        ),
                        GoRoute(
                          path: 'book/confirmation/:bookingId',
                          builder: (context, state) =>
                              ConfirmationScreen(bookingId: state.pathParameters['bookingId']!),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: AppNavigatorKeys.bookings,
          routes: [
            GoRoute(
              path: AppRoutes.bookings,
              builder: (context, state) => const BookingsScreen(),
              routes: [
                GoRoute(
                  path: ':bookingId/tracking',
                  builder: (context, state) => TrackingScreen(bookingId: state.pathParameters['bookingId']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: AppNavigatorKeys.cars,
          routes: [
            GoRoute(
              path: AppRoutes.cars,
              builder: (context, state) => const CarsScreen(),
              routes: [
                GoRoute(path: 'add', builder: (context, state) => const VehicleFormScreen()),
                GoRoute(
                  path: ':vehicleId/edit',
                  builder: (context, state) => VehicleFormScreen(vehicleId: state.pathParameters['vehicleId']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: AppNavigatorKeys.profile,
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'edit', builder: (context, state) => const EditProfileScreen()),
                GoRoute(path: 'personal-info', builder: (context, state) => const PersonalInfoScreen()),
                GoRoute(
                  path: 'help',
                  builder: (context, state) {
                    final l10n = AppLocalizations.of(context);
                    return ProfileInfoScreen(title: l10n.helpSupportTitle, body: l10n.helpSupportBody);
                  },
                ),
                GoRoute(
                  path: 'terms',
                  builder: (context, state) {
                    final l10n = AppLocalizations.of(context);
                    return ProfileInfoScreen(title: l10n.termsConditionsTitle, body: l10n.termsConditionsBody);
                  },
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) {
                    final l10n = AppLocalizations.of(context);
                    return ProfileInfoScreen(title: l10n.privacyPolicyTitle, body: l10n.privacyPolicyBody);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    ],
  );
  return router;
}

final GoRouter appRouter = createAppRouter();
