import 'models/booking_draft.dart';

/// The furthest screen the current draft supports reaching. A draft always
/// exists with a service+vehicle already chosen (Service Details only
/// creates one once its own CTA is ready), so [BookingStep.location] is
/// always reachable — this only distinguishes what comes after.
enum BookingStep { location, dateTime, review }

/// Used both to gate navigation (a screen deep-linked past this step
/// redirects back to it — see the Booking screens) and to resolve the
/// Confirm button's enabled state: [BookingStep.review] means the draft is
/// complete and ready to submit.
BookingStep resolveReachableStep(BookingDraft draft) {
  if (draft.location == null) return BookingStep.location;
  if (draft.date == null || draft.timeSlot == null) return BookingStep.dateTime;
  return BookingStep.review;
}

bool isDraftComplete(BookingDraft draft) => resolveReachableStep(draft) == BookingStep.review;

/// Thrown by [BookingSubmissionController.submit] when, at the moment of
/// submission, the draft is no longer structurally complete. Review is only
/// ever reachable once [isDraftComplete] was already true (see
/// `redirectIfStepNotReached`), so this should be unreachable in normal use
/// — it exists purely as a final defensive check immediately before the
/// Firestore write, rather than trusting that a draft sitting in memory is
/// still whatever it was when Review first became reachable.
class IncompleteBookingDraftException implements Exception {
  const IncompleteBookingDraftException();
}
