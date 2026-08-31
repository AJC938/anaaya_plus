/// App-level preferences that belong to the account, not to a single
/// screen's local state. Language is deliberately not modeled here — it's
/// owned entirely by the existing `localeProvider`.
class ProfilePreferences {
  const ProfilePreferences({required this.notificationsEnabled});

  final bool notificationsEnabled;

  ProfilePreferences copyWith({bool? notificationsEnabled}) {
    return ProfilePreferences(notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled);
  }
}
