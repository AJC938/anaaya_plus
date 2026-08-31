import 'package:anaaya_plus/features/profile/data/firestore_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('customerProfileFromFirestoreData', () {
    const uid = 'uid-123';

    test('maps a fully populated document', () {
      final profile = customerProfileFromFirestoreData({
        'uid': uid,
        'name': 'Faisal Al-Qahtani',
        'phoneNumber': '+966501234567',
        'email': 'faisal@example.com',
      }, uid: uid);

      expect(profile.id, uid);
      expect(profile.fullName, 'Faisal Al-Qahtani');
      expect(profile.phoneNumber, '+966501234567');
      expect(profile.email, 'faisal@example.com');
    });

    test('a freshly-provisioned document (name and email null) does not crash', () {
      final profile = customerProfileFromFirestoreData({
        'uid': uid,
        'name': null,
        'phoneNumber': '+966501234567',
        'email': null,
      }, uid: uid);

      expect(profile.fullName, '');
      expect(profile.email, isNull);
      expect(profile.phoneNumber, '+966501234567');
    });

    test('missing document data (null map) does not crash', () {
      final profile = customerProfileFromFirestoreData(null, uid: uid);

      expect(profile.id, uid);
      expect(profile.fullName, '');
      expect(profile.phoneNumber, '');
      expect(profile.email, isNull);
    });

    test('always uses the uid passed in, not any uid field in the data', () {
      final profile = customerProfileFromFirestoreData({'uid': 'someone-else', 'name': 'X'}, uid: uid);

      expect(profile.id, uid);
    });
  });
}
