import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/booking_validation.dart';
import '../../domain/models/booking_draft.dart';

/// Guards a Booking screen against being reached before its prerequisites
/// exist — a stale deep link, a killed-and-restored app, or a direct URL
/// edit must never crash or show a broken screen. Returns true (and
/// schedules a redirect to [fallbackRoute]) when the screen shouldn't be
/// shown yet; callers should render a minimal placeholder and return early.
bool redirectIfStepNotReached(
  BuildContext context, {
  required BookingDraft? draft,
  required BookingStep requiredStep,
  required String fallbackRoute,
}) {
  final blocked = draft == null || requiredStep.index > resolveReachableStep(draft).index;
  if (blocked) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      // A screen mid-exit-transition is still mounted (Navigator keeps a
      // popped route alive through its own pop animation) but is no longer
      // the active route — e.g. right after a successful Confirm Booking,
      // Location/Date&Time/Review all briefly rebuild against the
      // just-cleared draft while animating out. Redirecting anyway would
      // fire a stale `context.go` that stomps over the navigation that
      // already moved the user on to Confirmation. Only the current route
      // owns the right to redirect.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      context.go(fallbackRoute);
    });
  }
  return blocked;
}
