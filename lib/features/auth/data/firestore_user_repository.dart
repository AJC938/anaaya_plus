import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_repository.dart';

/// Real implementation, wrapping `FirebaseFirestore.instance`. Writes
/// `users/{uid}` inside a transaction that reads first: if the document
/// already exists, the transaction makes no write at all — so a returning
/// user's document is never overwritten, `createdAt` never resets, and no
/// duplicate document can ever be created, even if this is called from
/// more than one sign-in path in quick succession.
class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> ensureUserDocument({required String uid, String? phoneNumber}) async {
    final docRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) return; // already provisioned — leave it untouched

      transaction.set(docRef, {
        'uid': uid,
        'phoneNumber': phoneNumber,
        'name': null,
        'email': null,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
