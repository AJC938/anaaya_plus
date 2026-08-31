import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/payment/domain/payment_attempt_id.dart';

void main() {
  group('generatePaymentAttemptId', () {
    final uuidV4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('produces a well-formed UUID v4 string', () {
      final id = generatePaymentAttemptId();

      expect(id, matches(uuidV4Pattern));
    });

    test('every call produces a distinct id — never reused across attempts', () {
      final ids = List.generate(200, (_) => generatePaymentAttemptId());

      expect(ids.toSet(), hasLength(200));
    });
  });
}
