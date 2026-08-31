import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/profile/data/mock_profile_repository.dart';
import 'package:anaaya_plus/features/profile/domain/models/customer_profile.dart';
import 'package:anaaya_plus/features/profile/domain/models/profile_preferences.dart';

const _seedProfile = CustomerProfile(
  id: 'c1',
  fullName: 'Test User',
  phoneNumber: '+966 50 000 0000',
  email: 'test@example.com',
  preferredLanguage: 'ar',
);

void main() {
  test('getProfile returns the seeded profile', () async {
    final repository = MockProfileRepository(seedProfile: _seedProfile);
    final profile = await repository.getProfile();
    expect(profile.fullName, 'Test User');
    expect(profile.email, 'test@example.com');
  });

  test('updateProfile persists the change for the rest of the session', () async {
    final repository = MockProfileRepository(seedProfile: _seedProfile);

    final updated = await repository.updateProfile(fullName: 'New Name', email: 'new@example.com');
    expect(updated.fullName, 'New Name');
    expect(updated.email, 'new@example.com');
    // The phone number and id are never touched by updateProfile.
    expect(updated.phoneNumber, _seedProfile.phoneNumber);
    expect(updated.id, _seedProfile.id);

    final refetched = await repository.getProfile();
    expect(refetched.fullName, 'New Name');
    expect(refetched.email, 'new@example.com');
  });

  test('updateProfile with a null email clears a previously set email', () async {
    final repository = MockProfileRepository(seedProfile: _seedProfile);
    final updated = await repository.updateProfile(fullName: 'New Name');
    expect(updated.email, isNull);
  });

  test('getPreferences returns the seeded preferences', () async {
    final repository = MockProfileRepository(seedPreferences: const ProfilePreferences(notificationsEnabled: false));
    final preferences = await repository.getPreferences();
    expect(preferences.notificationsEnabled, isFalse);
  });

  test('updateNotificationPreference persists the change for the rest of the session', () async {
    final repository = MockProfileRepository(seedPreferences: const ProfilePreferences(notificationsEnabled: true));

    final updated = await repository.updateNotificationPreference(false);
    expect(updated.notificationsEnabled, isFalse);

    final refetched = await repository.getPreferences();
    expect(refetched.notificationsEnabled, isFalse);
  });
}
