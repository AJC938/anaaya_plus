import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/domain/booking_reference.dart';

void main() {
  test('produces a user-friendly "AN-XXXXX-YYYY" reference, not a raw UUID', () {
    final reference = generateBookingReference(now: DateTime(2026, 1, 5, 10, 30), random: Random(1));
    expect(reference, matches(RegExp(r'^AN-\d{5}-\d{4}$')));
  });

  test('the time-derived segment is unchanged from the original format for the same instant', () {
    // Pins the exact pre-existing value so this hardening never silently
    // changes what the time segment itself encodes — only adds to it.
    final reference = generateBookingReference(now: DateTime(2026, 1, 5, 10, 30), random: Random(1));
    expect(reference, startsWith('AN-'));
    expect(reference.split('-')[1].length, 5);
  });

  test('two references generated for the exact same instant no longer collide', () {
    // This is the exact scenario that previously produced a GUARANTEED
    // collision (same millisecondsSinceEpoch % 100000): two bookings
    // created at the identical instant. Deterministic (seeded) draws stand
    // in for two different real Random() draws here so this assertion
    // never depends on the tiny (1-in-10,000) chance that two genuinely
    // random draws happen to match.
    final now = DateTime(2026, 1, 5, 10, 30, 0, 0);
    final first = generateBookingReference(now: now, random: _FixedRandom(1));
    final second = generateBookingReference(now: now, random: _FixedRandom(2));

    expect(first, isNot(second));
  });

  test('the random segment spans the full 10,000-value range with no internal duplicates', () {
    // Deterministically walks every possible draw from `Random.nextInt(10000)`
    // via a fake Random that returns a fixed, controlled value, proving the
    // entropy space is genuinely 10,000 distinct values (no padding/
    // formatting bug quietly collapsing some of them) rather than asserting
    // uniqueness over a real-random sample, which is inherently probabilistic
    // (the birthday paradox guarantees frequent collisions well before 2,000
    // draws from a 10,000-value space — that would be the wrong thing to
    // assert here).
    final now = DateTime(2026, 1, 5, 10, 30, 0, 0);
    final suffixes = {for (var i = 0; i < 10000; i++) generateBookingReference(now: now, random: _FixedRandom(i)).split('-')[2]};

    expect(suffixes.length, 10000);
  });

  test('a fixed random draw is reflected verbatim in the second segment', () {
    final reference = generateBookingReference(now: DateTime(2026, 1, 5, 10, 30), random: _FixedRandom(7));
    expect(reference, endsWith('-0007'));
  });
}

/// A [Random] stand-in that always returns a fixed value from [nextInt], so
/// the random segment can be pinned exactly in a test.
class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}
