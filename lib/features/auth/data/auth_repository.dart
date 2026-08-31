/// Data seam for the Auth feature — wraps whatever backend actually
/// authenticates the user (Supabase OTP + Firebase Custom Token, as of
/// SMS-05) so the application layer never touches `FirebaseAuth` or the
/// Supabase OTP client directly (see [FirebaseAuthRepository], the only
/// implementation this milestone).
///
/// Exposes the signed-in user only as a UID string, not Firebase's `User`
/// object — nothing in this app needs more than that yet, and a plain
/// `String?` keeps every part of this contract constructible in a plain
/// Dart test double, with no platform channel involved.
abstract class AuthRepository {
  /// The single source of truth for whether the app is authenticated —
  /// emits the current user's UID, or null once signed out. Backed
  /// directly by Firebase's own `authStateChanges()` — this stays true
  /// regardless of which flow (OTP, or historically Firebase-native phone
  /// auth) produced the session, since both ultimately sign in through the
  /// same `FirebaseAuth` instance.
  Stream<String?> authStateChanges();

  String? get currentUserUid;

  /// The signed-in user's phone number, exactly as Firebase Auth reports it
  /// — used only to seed `users/{uid}.phoneNumber` on first sign-in.
  String? get currentUserPhoneNumber;

  /// The current user's Firebase ID token — a short-lived signed JWT proving
  /// this user's identity to a server-side verifier (see SPG-08), NOT a
  /// long-lived refresh/session credential. `null` when signed out.
  ///
  /// Firebase's own SDK transparently refreshes this token as needed; this
  /// method never caches or persists a value itself, it always defers to
  /// the SDK for whichever token is currently valid.
  Future<String?> getIdToken();

  /// Requests a one-time code for [phoneNumber] from the backend OTP
  /// service (SMS-03/04's `send-otp`). Throws [PhoneAuthFailureException]
  /// for any rejected/failed request — see each implementation's own error
  /// mapping.
  Future<void> sendOtp(String phoneNumber);

  /// Submits [otp] for [phoneNumber] to the backend OTP service
  /// (`verify-otp`) and, on success, signs the user into Firebase with the
  /// resulting Custom Token. Returns the signed-in Firebase UID. Throws
  /// [PhoneAuthFailureException] for any rejected code or sign-in failure.
  Future<String> verifyOtp({required String phoneNumber, required String otp});

  Future<void> signOut();
}
