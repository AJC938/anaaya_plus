import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/booking/domain/pricing.dart';

void main() {
  test('with no option, total is base price plus the flat fee', () {
    final result = calculateBookingPrice(basePrice: 120);
    expect(result.basePrice, 120);
    expect(result.optionPrice, 0);
    expect(result.fees, bookingServiceFee);
    expect(result.total, 120 + bookingServiceFee);
  });

  test('reproduces the spec review example: 120 base + 40 option + 10 fees = 170', () {
    final result = calculateBookingPrice(basePrice: 120, optionPrice: 40, fees: 10);
    expect(result.total, 170);
  });

  test('an explicit zero fee is respected, not silently replaced by the default', () {
    final result = calculateBookingPrice(basePrice: 100, fees: 0);
    expect(result.fees, 0);
    expect(result.total, 100);
  });
}
