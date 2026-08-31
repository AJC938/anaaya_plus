import 'models/payment.dart';

/// The single authoritative Payment status state machine — mirrors
/// `booking_status_transition.dart`'s exact shape/reasoning (one map, both
/// the app and Firestore rules validated against the same edges), but for a
/// genuinely separate concern: [PaymentStatus] never appears on
/// [BookingStatus], and vice versa.
///
///   pending -> paid    (a successful charge)
///   pending -> failed  (a declined/errored charge)
///   failed  -> pending (retrying re-opens a fresh attempt)
///
/// [PaymentStatus.paid] is terminal — once paid, there is nothing to retry
/// and nothing this milestone lets the user undo. [PaymentStatus.pending]
/// can also be reached fresh (no prior payment at all, i.e. no document
/// exists yet) — that case has no "from" state to validate, it's simply the
/// first-ever write, not a transition.
const Map<PaymentStatus, Set<PaymentStatus>> paymentStatusTransitions = {
  PaymentStatus.pending: {PaymentStatus.paid, PaymentStatus.failed},
  PaymentStatus.paid: {},
  PaymentStatus.failed: {PaymentStatus.pending},
};

bool isValidPaymentStatusTransition({required PaymentStatus from, required PaymentStatus to}) {
  return paymentStatusTransitions[from]?.contains(to) ?? false;
}

/// Whether a NEW submission attempt (whatever [target] outcome it
/// eventually resolves to) is legal given the payment's [current] stored
/// status. `null` means no payment has ever been attempted for this booking
/// — always legal, there's no "from" state to validate against.
///
/// Composes two edges of [paymentStatusTransitions] rather than checking
/// `current -> target` directly: every real submission conceptually passes
/// through `pending` first (`current -> pending`, then `pending -> target`),
/// even though this milestone's mock gateway resolves synchronously and so
/// never actually persists that intermediate `pending` write (see
/// `FirestorePaymentRepository.submitPayment`'s own doc comment) — a real,
/// asynchronous gateway integration *would* persist it, and this composition
/// is what makes that swap not require touching this file. The practical
/// effect: [PaymentStatus.failed] can be resubmitted to either outcome,
/// [PaymentStatus.paid] can never be resubmitted at all (it has no outgoing
/// edge to `pending`), matching "paid is terminal."
bool canSubmitPayment({required PaymentStatus? current, required PaymentStatus target}) {
  if (current == null) return true;
  // pending already has direct edges to both outcomes — no composition
  // needed (there is no pending -> pending self-edge to compose through).
  if (current == PaymentStatus.pending) {
    return isValidPaymentStatusTransition(from: PaymentStatus.pending, to: target);
  }
  return isValidPaymentStatusTransition(from: current, to: PaymentStatus.pending) &&
      isValidPaymentStatusTransition(from: PaymentStatus.pending, to: target);
}

/// Thrown when a requested payment status change isn't a legal edge in
/// [paymentStatusTransitions] — e.g. retrying an already-paid payment, or
/// somehow requesting a direct pending->pending no-op.
class InvalidPaymentStatusTransitionException implements Exception {
  const InvalidPaymentStatusTransitionException({required this.from, required this.to});

  final PaymentStatus from;
  final PaymentStatus to;

  @override
  String toString() => 'InvalidPaymentStatusTransitionException: $from -> $to is not an allowed transition';
}
