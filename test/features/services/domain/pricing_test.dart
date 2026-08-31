import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/services/domain/models/service_option.dart';
import 'package:anaaya_plus/features/services/domain/pricing.dart';

const _fullSynthetic = ServiceOption(
  id: 'opt-full',
  serviceId: 's1',
  nameAr: 'صناعي كامل',
  nameEn: 'Full Synthetic',
  descriptionAr: '',
  descriptionEn: '',
  price: 60,
  imageAsset: 'oil_change',
  compatibleVehicleIds: ['v2'],
  isAvailable: true,
);

void main() {
  test('with no option selected, total equals the base price', () {
    final result = calculatePrice(basePrice: 89);
    expect(result.basePrice, 89);
    expect(result.optionPrice, 0);
    expect(result.total, 89);
  });

  test('reproduces the spec price summary example: 89 base + 60 option = 149', () {
    final result = calculatePrice(basePrice: 89, selectedOption: _fullSynthetic);
    expect(result.basePrice, 89);
    expect(result.optionPrice, 60);
    expect(result.total, 149);
  });
}
