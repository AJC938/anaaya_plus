/// The signed-in customer's account data — deliberately minimal. Profile
/// owns this and only this: vehicles belong to Cars, bookings belong to
/// Booking (see their own repositories), never duplicated here.
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.profileImageAsset,
    required this.preferredLanguage,
  });

  final String id;
  final String fullName;

  /// Display-only in this milestone — not editable from the app (see
  /// EditProfileScreen), since it's expected to later gate
  /// authentication/verification.
  final String phoneNumber;

  /// Optional — a customer may not have provided one.
  final String? email;

  /// Semantic asset key, resolved the same way as Services/Cars imagery.
  /// Null (the normal case for mock data) falls back to an initials avatar
  /// rather than depending on a network image.
  final String? profileImageAsset;

  /// The account's stored language preference ('ar' or 'en'). This is
  /// informational profile data, not the live UI driver — the app's actual
  /// displayed language is always `localeProvider`/`LocaleController`, the
  /// single existing locale system. Changing the Language row updates that
  /// controller directly and does not go through this field.
  final String preferredLanguage;

  CustomerProfile copyWith({String? fullName, String? email}) {
    return CustomerProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber,
      email: email ?? this.email,
      profileImageAsset: profileImageAsset,
      preferredLanguage: preferredLanguage,
    );
  }
}
