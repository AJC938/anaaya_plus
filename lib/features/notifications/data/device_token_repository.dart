/// Data seam for FCM device-token persistence — deliberately separate from
/// [NotificationRepository] (notification history vs. delivery
/// registration are independent concerns, matching Booking/Payment's own
/// split into distinct repositories rather than one god-repository).
abstract class DeviceTokenRepository {
  /// Registers (or refreshes) [token] under the authenticated user. Always
  /// idempotent for the same token — see
  /// [FirestoreDeviceTokenRepository]'s own doc comment for why using the
  /// token itself as the document id is what makes that true.
  Future<void> registerToken({required String token, required String platform});

  /// Removes [token] — called on sign-out so a device that's no longer
  /// associated with this account stops being a delivery target for it.
  Future<void> deleteToken(String token);
}
