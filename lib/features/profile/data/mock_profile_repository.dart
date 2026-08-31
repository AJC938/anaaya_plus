import '../domain/models/customer_profile.dart';
import '../domain/models/profile_preferences.dart';
import 'profile_repository.dart';

/// Local/in-memory stand-in for a future Profile repository backed by a
/// real account service. Updates persist for the lifetime of this instance
/// (i.e. the current app session) — never written anywhere durable.
///
/// The artificial delay is only so the loading/skeleton states are visible
/// when running the app manually.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({CustomerProfile? seedProfile, ProfilePreferences? seedPreferences})
    : _profile = seedProfile ?? _defaultProfile,
      _preferences = seedPreferences ?? _defaultPreferences;

  static const _latency = Duration(milliseconds: 400);

  static const _defaultProfile = CustomerProfile(
    id: 'c1',
    fullName: 'Faisal Al-Qahtani',
    phoneNumber: '+966 55 123 4567',
    email: 'faisal.alqahtani@example.com',
    preferredLanguage: 'ar',
  );

  static const _defaultPreferences = ProfilePreferences(notificationsEnabled: true);

  CustomerProfile _profile;
  ProfilePreferences _preferences;

  @override
  Future<CustomerProfile> getProfile() async {
    await Future.delayed(_latency);
    return _profile;
  }

  @override
  Future<CustomerProfile> updateProfile({required String fullName, String? email}) async {
    await Future.delayed(_latency);
    _profile = CustomerProfile(
      id: _profile.id,
      fullName: fullName,
      phoneNumber: _profile.phoneNumber,
      email: email,
      profileImageAsset: _profile.profileImageAsset,
      preferredLanguage: _profile.preferredLanguage,
    );
    return _profile;
  }

  @override
  Future<ProfilePreferences> getPreferences() async {
    await Future.delayed(_latency);
    return _preferences;
  }

  @override
  Future<ProfilePreferences> updateNotificationPreference(bool enabled) async {
    await Future.delayed(_latency);
    _preferences = _preferences.copyWith(notificationsEnabled: enabled);
    return _preferences;
  }
}
