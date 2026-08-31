import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/cars/domain/make_model_catalog.dart';

void main() {
  test('getMakes returns a non-empty curated list', () {
    expect(getMakes(), isNotEmpty);
    expect(getMakes(), contains('Toyota'));
  });

  test('getModelsForMake returns models for a known make', () {
    expect(getModelsForMake('Toyota'), contains('Camry'));
  });

  test('getModelsForMake returns an empty list for an unknown or null make', () {
    expect(getModelsForMake('NotAMake'), isEmpty);
    expect(getModelsForMake(null), isEmpty);
  });

  test('models are not shared across different makes', () {
    expect(getModelsForMake('Toyota'), isNot(contains('Tucson')));
  });
}
