import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/payment.dart';
import '../domain/payment_status_transition.dart';
import 'payment_repository.dart';

Payment paymentFromFirestoreData(Map<String, dynamic>? data) {
  final statusName = data?['status'] as String?;
  final status = PaymentStatus.values.firstWhere(
    (candidate) => candidate.name == statusName,
    orElse: () => PaymentStatus.pending,
  );
  final createdAtTimestamp = data?['createdAt'] as Timestamp?;
  final statusUpdatedAtTimestamp = data?['statusUpdatedAt'] as Timestamp?;
  return Payment(
    bookingReference: data?['bookingReference'] as String? ?? '',
    amount: (data?['amount'] as num?)?.toDouble() ?? 0,
    currency: data?['currency'] as String? ?? paymentCurrency,
    status: status,
    method: data?['method'] as String? ?? '',
    transactionId: data?['transactionId'] as String? ?? '',
    createdAt: createdAtTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
    statusUpdatedAt: statusUpdatedAtTimestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Client-authoritative Firestore implementation — the app's own
/// authenticated Firestore session (governed by `firestore.rules`' owner
/// check) is the only credential involved; there is no server-side
/// verification step. [submitPayment] writes `payment/latest` directly,
/// inside a transaction so a concurrent call for the same booking can never
/// silently clobber the first. See [PaymentRepository.submitPayment]'s own
/// doc comment for the test/portfolio-only security caveat this implies.
class FirestorePaymentRepository implements PaymentRepository {
  FirestorePaymentRepository({required String uid, FirebaseFirestore? firestore})
    : _uid = uid,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookingsRef =>
      _firestore.collection('users').doc(_uid).collection('bookings');

  DocumentReference<Map<String, dynamic>> _paymentDocFor(DocumentReference<Map<String, dynamic>> bookingRef) =>
      bookingRef.collection('payment').doc('latest');

  Future<DocumentReference<Map<String, dynamic>>> _bookingDocRef(String bookingReference) async {
    final snapshot = await _bookingsRef.where('bookingReference', isEqualTo: bookingReference).limit(1).get();
    if (snapshot.docs.isEmpty) throw StateError('Booking $bookingReference not found');
    return snapshot.docs.first.reference;
  }

  @override
  Future<Payment?> fetchPayment({required String bookingReference}) async {
    final bookingRef = await _bookingDocRef(bookingReference);
    final snapshot = await _paymentDocFor(bookingRef).get();
    if (!snapshot.exists) return null;
    return paymentFromFirestoreData(snapshot.data());
  }

  @override
  Future<Payment> submitPayment({
    required String bookingReference,
    required PaymentStatus status,
    required String method,
    required String transactionId,
  }) async {
    final bookingRef = await _bookingDocRef(bookingReference);
    final bookingSnapshot = await bookingRef.get();
    final price = bookingSnapshot.data()?['price'] as Map<String, dynamic>?;
    final priceTotal = (price?['total'] as num?)?.toDouble();
    if (priceTotal == null) {
      throw StateError('Booking $bookingReference is missing price.total');
    }
    final paymentRef = _paymentDocFor(bookingRef);

    return _firestore.runTransaction<Payment>((transaction) async {
      final existingSnapshot = await transaction.get(paymentRef);
      final existing = existingSnapshot.exists ? paymentFromFirestoreData(existingSnapshot.data()) : null;

      // Already paid is terminal and idempotent — see
      // payment_status_transition.dart's own doc comment.
      if (existing?.status == PaymentStatus.paid) return existing!;

      if (!canSubmitPayment(current: existing?.status, target: status)) {
        throw InvalidPaymentStatusTransitionException(from: existing?.status ?? PaymentStatus.pending, to: status);
      }

      final now = DateTime.now();
      final payment = Payment(
        bookingReference: bookingReference,
        amount: priceTotal,
        currency: paymentCurrency,
        status: status,
        method: method,
        transactionId: transactionId,
        createdAt: existing?.createdAt ?? now,
        statusUpdatedAt: now,
      );

      transaction.set(paymentRef, {
        'bookingReference': payment.bookingReference,
        'amount': payment.amount,
        'currency': payment.currency,
        'status': payment.status.name,
        'method': payment.method,
        'transactionId': payment.transactionId,
        'createdAt': Timestamp.fromDate(payment.createdAt),
        'statusUpdatedAt': Timestamp.fromDate(payment.statusUpdatedAt),
      });

      return payment;
    });
  }
}
