enum PaymentStatus { pending, paid, failed }

/// Currency for every booking in this app — Services/Booking never surface
/// a currency picker (see `priceSar`/`startingFromPrice` l10n keys), so
/// Payment doesn't invent one either. The single source of truth for this
/// literal — `FirestorePaymentRepository` imports it from here rather than
/// hardcoding `'SAR'` separately.
const String paymentCurrency = 'SAR';

/// A booking's payment record — entirely independent of [BookingStatus]:
/// the service lifecycle (upcoming/technicianOnTheWay/.../cancelled) and the
/// payment lifecycle (pending/paid/failed) are two separate concerns that
/// happen to both hang off the same booking. One booking has at most one
/// [Payment] at a time — a retry after [PaymentStatus.failed] overwrites the
/// prior attempt rather than accumulating a history, since nothing in this
/// milestone's product requirements needs one.
///
/// This app has no real payment gateway — [Payment] is written entirely by
/// a local test simulation (see `PaymentRepository.submitPayment`'s own doc
/// comment). It is never the product of a real charge.
class Payment {
  const Payment({
    required this.bookingReference,
    required this.amount,
    required this.currency,
    required this.status,
    required this.method,
    required this.transactionId,
    required this.createdAt,
    required this.statusUpdatedAt,
  });

  /// Explicit linkage back to the booking, in addition to this document's
  /// own Firestore path already nesting under that booking — matches
  /// `serviceSlots`' own defense-in-depth `bookingReference` field from
  /// BE-06, so a payment record is never trusted by path alone.
  final String bookingReference;

  /// Always sourced from the booking's own `price.total` at the moment of
  /// submission — never a value the UI or caller supplies (see
  /// [PaymentRepository.submitPayment]'s own doc comment).
  final double amount;

  final String currency;
  final PaymentStatus status;

  /// Always `'simulated'` in this app's local test payment simulation — kept
  /// as its own field (rather than folded into [status]) since a real
  /// payment integration would populate it from the gateway's own response.
  final String method;

  /// A fresh id generated per simulated attempt (see
  /// `generatePaymentAttemptId`) — regenerated on every new attempt
  /// (including a retry), never reused across attempts.
  final String transactionId;

  final DateTime createdAt;
  final DateTime statusUpdatedAt;
}
