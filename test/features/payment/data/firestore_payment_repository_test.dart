import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/payment/data/firestore_payment_repository.dart';
import 'package:anaaya_plus/features/payment/domain/models/payment.dart';

final createdAtUtc = DateTime.utc(2026, 3, 5, 12, 0);
final statusUpdatedAtUtc = DateTime.utc(2026, 3, 5, 12, 5);

Map<String, dynamic> _fullyPopulatedData({
  String bookingReference = 'AN-20481',
  double amount = 124.0,
  String currency = 'SAR',
  String status = 'paid',
  String method = 'card_visa',
  String transactionId = 'sim-1234567890',
}) {
  return <String, dynamic>{
    'bookingReference': bookingReference,
    'amount': amount,
    'currency': currency,
    'status': status,
    'method': method,
    'transactionId': transactionId,
    'createdAt': Timestamp.fromDate(createdAtUtc),
    'statusUpdatedAt': Timestamp.fromDate(statusUpdatedAtUtc),
  };
}

void main() {
  group('paymentFromFirestoreData', () {
    test('maps a fully populated document', () {
      final payment = paymentFromFirestoreData(_fullyPopulatedData());

      expect(payment.bookingReference, 'AN-20481');
      expect(payment.amount, 124.0);
      expect(payment.currency, 'SAR');
      expect(payment.status, PaymentStatus.paid);
      expect(payment.method, 'card_visa');
      expect(payment.transactionId, 'sim-1234567890');
      expect(payment.createdAt.toUtc(), createdAtUtc);
      expect(payment.statusUpdatedAt.toUtc(), statusUpdatedAtUtc);
    });

    test('maps every known status string to its PaymentStatus', () {
      for (final status in PaymentStatus.values) {
        final payment = paymentFromFirestoreData(_fullyPopulatedData(status: status.name));
        expect(payment.status, status);
      }
    });

    test('an unrecognized status string falls back to pending, without crashing', () {
      final payment = paymentFromFirestoreData(_fullyPopulatedData(status: 'some-future-status'));

      expect(payment.status, PaymentStatus.pending);
    });

    test('an integer amount (Firestore num, not double) is still mapped correctly', () {
      final data = _fullyPopulatedData()..['amount'] = 124;

      final payment = paymentFromFirestoreData(data);

      expect(payment.amount, 124.0);
    });

    test('missing document data (null map) does not crash', () {
      final payment = paymentFromFirestoreData(null);

      expect(payment.bookingReference, '');
      expect(payment.amount, 0);
      expect(payment.currency, paymentCurrency);
      expect(payment.status, PaymentStatus.pending);
      expect(payment.method, '');
      expect(payment.transactionId, '');
    });
  });
}
