import 'dart:math';

/// A fresh, unpredictable UUID v4 — used as the [Payment.transactionId] for
/// each local test payment simulation attempt (see `payment_screen.dart`'s
/// "Simulate Payment" button), so every attempt, including a retry, is a
/// distinct id. Never reuse one value across two attempts.
///
/// Hand-rolled rather than pulling in the `uuid` package: this is the one
/// place in the app a UUID is needed, and the algorithm is a handful of
/// lines — matches this project's own bias against a dependency for
/// something this small.
String generatePaymentAttemptId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10xx

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
