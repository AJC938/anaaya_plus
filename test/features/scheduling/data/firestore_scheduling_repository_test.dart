import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/scheduling/data/firestore_scheduling_repository.dart';

void main() {
  group('scheduleSlotDocumentId', () {
    test('is deterministic — the same service/time always produces the same id', () {
      final a = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));
      final b = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));

      expect(a, b);
    });

    test('differs across services for the exact same time — no cross-service collision', () {
      final s1 = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));
      final s2 = scheduleSlotDocumentId(serviceId: 's2', scheduledAt: DateTime(2026, 1, 5, 9));

      expect(s1, isNot(s2));
    });

    test('differs across dates for the same service and hour', () {
      final day5 = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));
      final day6 = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 6, 9));

      expect(day5, isNot(day6));
    });

    test('differs across hours for the same service and date', () {
      final nine = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));
      final ten = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 10));

      expect(nine, isNot(ten));
    });

    test('zero-pads month/day/hour, and length-prefixes serviceId, in a fixed, predictable shape', () {
      final id = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 3, 7, 9));

      expect(id, '2~s1~20260307~09');
    });

    test('a Firestore document ID built from it contains no invalid characters (no slashes)', () {
      final id = scheduleSlotDocumentId(serviceId: 's1', scheduledAt: DateTime(2026, 1, 5, 9));

      expect(id.contains('/'), isFalse);
    });

    // The old plain-delimiter join (`'$serviceId_$date_$hour'`) could let a
    // serviceId containing '_' or '-' shift where the boundary falls,
    // risking two logically different (serviceId, date, hour) triples
    // formatting to the same string. Length-prefixing serviceId removes
    // that risk entirely — the tests below construct exactly the kind of
    // serviceId content that would have been suspect under a plain join,
    // and prove the id stays unambiguous.
    group('delimiter-ambiguity safety', () {
      test('a serviceId containing "_" never collides with a differently-split serviceId at the same time', () {
        final embeddedUnderscore = scheduleSlotDocumentId(serviceId: 'svc_2026-01-05', scheduledAt: DateTime(2026, 1, 5, 9));
        final plain = scheduleSlotDocumentId(serviceId: 'svc', scheduledAt: DateTime(2026, 1, 5, 9));

        expect(embeddedUnderscore, isNot(plain));
      });

      test('a serviceId containing "-" never collides with a differently-split serviceId at the same time', () {
        final embeddedDash = scheduleSlotDocumentId(serviceId: 'svc-2026-01-05', scheduledAt: DateTime(2026, 1, 5, 9));
        final plain = scheduleSlotDocumentId(serviceId: 'svc', scheduledAt: DateTime(2026, 1, 5, 9));

        expect(embeddedDash, isNot(plain));
      });

      test('a serviceId containing "~" (the id/date separator itself) still never collides', () {
        final embeddedTilde = scheduleSlotDocumentId(serviceId: 'svc~20260105~09', scheduledAt: DateTime(2026, 1, 5, 9));
        final plain = scheduleSlotDocumentId(serviceId: 'svc', scheduledAt: DateTime(2026, 1, 5, 9));

        expect(embeddedTilde, isNot(plain));
      });

      test('two different serviceIds of different lengths that share a common prefix never collide', () {
        final short = scheduleSlotDocumentId(serviceId: 'svc', scheduledAt: DateTime(2026, 1, 5, 9));
        final long = scheduleSlotDocumentId(serviceId: 'svc_extra', scheduledAt: DateTime(2026, 1, 5, 9));

        expect(short, isNot(long));
        // Confirms the safety comes from the length prefix, not just from
        // the two ids happening to differ — the length digit itself is
        // part of what's compared.
        expect(short.startsWith('3~'), isTrue);
        expect(long.startsWith('9~'), isTrue);
      });
    });
  });

  group('slotClaimFields', () {
    test('writes every claim field with the correct value and type', () {
      final fields = slotClaimFields(
        serviceId: 's1',
        scheduledAt: DateTime(2026, 1, 5, 9),
        claimedByUid: 'uid-abc',
        bookingReference: 'AN-12345-6789',
      );

      expect(fields['serviceId'], 's1');
      expect(fields['claimedByUid'], 'uid-abc');
      expect(fields['bookingReference'], 'AN-12345-6789');
      expect(fields['scheduledAt'], isA<Timestamp>());
      expect((fields['scheduledAt'] as Timestamp).toDate(), DateTime(2026, 1, 5, 9));
    });

    test('never includes claimedAt — the caller stamps that separately with a server timestamp', () {
      final fields = slotClaimFields(
        serviceId: 's1',
        scheduledAt: DateTime(2026, 1, 5, 9),
        claimedByUid: 'uid-abc',
        bookingReference: 'AN-12345-6789',
      );

      expect(fields.containsKey('claimedAt'), isFalse);
    });

    test('never includes an id field — the document ID alone is the slot identity', () {
      final fields = slotClaimFields(
        serviceId: 's1',
        scheduledAt: DateTime(2026, 1, 5, 9),
        claimedByUid: 'uid-abc',
        bookingReference: 'AN-12345-6789',
      );

      expect(fields.containsKey('id'), isFalse);
    });
  });
}
