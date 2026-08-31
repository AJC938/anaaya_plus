import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/customer_profile.dart';
import '../domain/models/profile_preferences.dart';
import 'profile_repository.dart';

/// `preferredLanguage` has no Firestore field yet (see the milestone note on
/// [FirestoreProfileRepository]) — this matches [MockProfileRepository]'s
/// default until a later milestone adds the field to the schema.
const _defaultPreferredLanguage = 'ar';

/// Maps a `users/{uid}` document's data onto [CustomerProfile]. Pulled out
/// as a standalone function — rather than inlined in
/// [FirestoreProfileRepository] — so the null-handling for a
/// freshly-provisioned document (`name`/`email` both null, as
/// `FirestoreUserRepository.ensureUserDocument` writes them) is
/// unit-testable without a real or fake Firestore instance.
CustomerProfile customerProfileFromFirestoreData(Map<String, dynamic>? data, {required String uid}) {
  final name = data?['name'] as String?;
  final phoneNumber = data?['phoneNumber'] as String?;
  final email = data?['email'] as String?;

  return CustomerProfile(
    id: uid,
    fullName: name ?? '',
    phoneNumber: phoneNumber ?? '',
    email: email,
    preferredLanguage: _defaultPreferredLanguage,
  );
}

/// Real implementation, wrapping `FirebaseFirestore.instance`. Reads and
/// updates the same `users/{uid}` document [FirestoreUserRepository]
/// provisions on sign-in — this repository never creates the document
/// itself, and only ever touches the fields Profile owns (`name`, `email`).
///
/// `preferredLanguage`/`profileImageAsset`/notifications have no Firestore
/// field yet, so preferences stay in-memory for the lifetime of this
/// instance — matching [MockProfileRepository]'s behavior — until a later
/// milestone adds them to the schema.
class FirestoreProfileRepository implements ProfileRepository {
  // `uid` is kept as the public parameter name — `this._uid` would make the
  // named parameter private and unusable from outside this library (see
  // AnaayaPlusApp's `_router` field for the same tradeoff).
  FirestoreProfileRepository({required String uid, FirebaseFirestore? firestore})
    // ignore: prefer_initializing_formals
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  ProfilePreferences _preferences = const ProfilePreferences(notificationsEnabled: true);

  DocumentReference<Map<String, dynamic>> get _docRef => _firestore.collection('users').doc(_uid);

  @override
  Future<CustomerProfile> getProfile() async {
    final snapshot = await _docRef.get();
    return customerProfileFromFirestoreData(snapshot.data(), uid: _uid);
  }

  /// [email] is nullable — passing null clears it, matching
  /// [ProfileRepository.updateProfile]'s contract. Phone number isn't
  /// included: it isn't editable from Edit Profile (see [ProfileForm]), so
  /// this repository never writes it.
  @override
  Future<CustomerProfile> updateProfile({required String fullName, String? email}) async {
    await _docRef.set({'name': fullName, 'email': email}, SetOptions(merge: true));
    return getProfile();
  }

  @override
  Future<ProfilePreferences> getPreferences() async => _preferences;

  @override
  Future<ProfilePreferences> updateNotificationPreference(bool enabled) async {
    _preferences = _preferences.copyWith(notificationsEnabled: enabled);
    return _preferences;
  }
}
