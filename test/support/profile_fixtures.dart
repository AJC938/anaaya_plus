import 'package:anaaya_plus/features/profile/data/profile_repository.dart';
import 'package:anaaya_plus/features/profile/domain/models/customer_profile.dart';
import 'package:anaaya_plus/features/profile/domain/models/profile_preferences.dart';

const testProfile = CustomerProfile(
  id: 'c1',
  fullName: 'Faisal Al-Qahtani',
  phoneNumber: '+966 55 123 4567',
  email: 'faisal.alqahtani@example.com',
  preferredLanguage: 'ar',
);

const testProfileNoEmail = CustomerProfile(
  id: 'c1',
  fullName: 'Faisal Al-Qahtani',
  phoneNumber: '+966 55 123 4567',
  preferredLanguage: 'ar',
);

const testPreferences = ProfilePreferences(notificationsEnabled: true);

/// A [ProfileRepository] with no artificial latency and controllable
/// outcomes — widget tests that only care about the UI's reaction to
/// success/failure use this instead of the real mock (whose realistic
/// latency is exercised directly in mock_profile_repository_test.dart).
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    CustomerProfile? profile,
    ProfilePreferences? preferences,
    this.onUpdateProfile,
    this.onUpdatePreference,
    this.onGetProfile,
    this.onGetPreferences,
  }) : _profile = profile ?? testProfile,
       _preferences = preferences ?? testPreferences;

  CustomerProfile _profile;
  ProfilePreferences _preferences;

  /// Return a profile for success, or throw for failure.
  Future<CustomerProfile> Function(String fullName, String? email)? onUpdateProfile;

  /// Return preferences for success, or throw for failure.
  Future<ProfilePreferences> Function(bool enabled)? onUpdatePreference;

  /// Overrides the initial fetch — a [Completer]'s future for a loading
  /// test, a throwing closure for an error test.
  Future<CustomerProfile> Function()? onGetProfile;
  Future<ProfilePreferences> Function()? onGetPreferences;

  int updateProfileCallCount = 0;

  @override
  Future<CustomerProfile> getProfile() => onGetProfile != null ? onGetProfile!() : Future.value(_profile);

  @override
  Future<CustomerProfile> updateProfile({required String fullName, String? email}) async {
    updateProfileCallCount++;
    _profile = onUpdateProfile != null
        ? await onUpdateProfile!(fullName, email)
        : CustomerProfile(
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
  Future<ProfilePreferences> getPreferences() => onGetPreferences != null ? onGetPreferences!() : Future.value(_preferences);

  @override
  Future<ProfilePreferences> updateNotificationPreference(bool enabled) async {
    _preferences = onUpdatePreference != null ? await onUpdatePreference!(enabled) : _preferences.copyWith(notificationsEnabled: enabled);
    return _preferences;
  }
}
