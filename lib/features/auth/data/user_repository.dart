/// Data seam for the signed-in user's Firestore record (`users/{uid}`) —
/// separate from [AuthRepository], which only ever owns Firebase
/// Authentication itself. [FirestoreUserRepository] is the only
/// implementation this milestone.
///
/// This is intentionally the *only* Firestore-backed repository so far —
/// vehicles, bookings, services, and everything else stay mock-driven until
/// their own milestones.
abstract class UserRepository {
  /// Provisions `users/{uid}` the first time this uid signs in, and is a
  /// safe no-op on every later call (see [FirestoreUserRepository] for how
  /// that's guaranteed) — so it's fine to call this on every successful
  /// sign-in, not just the very first one, without ever overwriting an
  /// existing document or resetting its `createdAt`.
  Future<void> ensureUserDocument({required String uid, String? phoneNumber});
}
