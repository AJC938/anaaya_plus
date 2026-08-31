import 'package:cloud_firestore/cloud_firestore.dart';

import 'device_token_repository.dart';

/// Real implementation, wrapping `FirebaseFirestore.instance`. Device
/// records live at `users/{uid}/devices/{token}` — the FCM token itself is
/// the document id (not an auto-id, not a locally-generated device id):
/// registering the same token twice (an app relaunch, a widget rebuild
/// re-triggering registration, `onTokenRefresh` firing with an unchanged
/// value) always resolves to the same document and just refreshes
/// `updatedAt`, never creates a duplicate. A genuine token *rotation*
/// (FCM issuing a new token) intentionally creates a new document for the
/// new token — that's not a duplicate, it's a different, real delivery
/// target — and leaves the old one in place rather than racing to delete
/// it; an expired/rotated token simply stops receiving deliveries, the same
/// natural cleanup every real FCM integration relies on, so no separate
/// token-rotation-cleanup mechanism is needed here.
class FirestoreDeviceTokenRepository implements DeviceTokenRepository {
  FirestoreDeviceTokenRepository({
    required String uid,
    FirebaseFirestore? firestore,
    // ignore: prefer_initializing_formals
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _devicesRef => _firestore.collection('users').doc(_uid).collection('devices');

  @override
  Future<void> registerToken({required String token, required String platform}) async {
    await _devicesRef.doc(token).set({'token': token, 'platform': platform, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> deleteToken(String token) async {
    await _devicesRef.doc(token).delete();
  }
}
