import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Time remaining until [target], never negative.
Duration remainingUntil(DateTime target, {DateTime? now}) {
  final effectiveNow = now ?? DateTime.now();
  final diff = target.difference(effectiveNow);
  return diff.isNegative ? Duration.zero : diff;
}

/// Compact "2h 18m" / "45m" style duration text. Never produces a negative
/// value — callers should treat [Duration.zero] as "arrived"/"starting now".
String formatCountdown(Duration duration) {
  if (duration <= Duration.zero) return '0m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }
  return '${minutes}m';
}

/// A once-a-second heartbeat so a countdown display can rebuild itself
/// without any other section of the screen rebuilding alongside it. Used by
/// Home's booking card and Booking Tracking's ETA.
final secondTickerProvider = StreamProvider<void>((ref) async* {
  yield null;
  yield* Stream.periodic(const Duration(seconds: 1));
});
