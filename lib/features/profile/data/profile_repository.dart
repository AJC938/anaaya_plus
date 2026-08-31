import '../domain/models/customer_profile.dart';
import '../domain/models/profile_preferences.dart';

/// Data seam for the Profile feature. [MockProfileRepository] is the only
/// implementation for this milestone; a real backend can replace it later
/// without Profile's screens changing.
abstract class ProfileRepository {
  Future<CustomerProfile> getProfile();

  /// [email] is nullable — passing null clears it, matching the field's
  /// optional nature on [CustomerProfile]. Full name is always required.
  Future<CustomerProfile> updateProfile({required String fullName, String? email});

  Future<ProfilePreferences> getPreferences();

  Future<ProfilePreferences> updateNotificationPreference(bool enabled);
}
