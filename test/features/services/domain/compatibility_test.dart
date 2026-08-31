import 'package:flutter_test/flutter_test.dart';

import 'package:anaaya_plus/features/services/domain/compatibility.dart';
import 'package:anaaya_plus/features/services/domain/models/service_option.dart';

const _universal = ServiceOption(
  id: 'opt-universal',
  serviceId: 's6',
  nameAr: 'قياسي',
  nameEn: 'Standard',
  descriptionAr: 'خيار قياسي',
  descriptionEn: 'A standard option',
  price: 0,
  imageAsset: 'battery',
  compatibleVehicleIds: [],
  isAvailable: true,
);

const _camryOnly = ServiceOption(
  id: 'opt-camry',
  serviceId: 's1',
  nameAr: 'زيت معدني',
  nameEn: 'Mineral',
  descriptionAr: 'حماية أساسية',
  descriptionEn: 'Basic protection',
  price: 25,
  imageAsset: 'oil_change',
  compatibleVehicleIds: ['v1'],
  isAvailable: true,
);

const _unavailableButCompatible = ServiceOption(
  id: 'opt-unavailable',
  serviceId: 's1',
  nameAr: 'غير متاح',
  nameEn: 'Unavailable',
  descriptionAr: 'غير متاح حاليًا',
  descriptionEn: 'Currently unavailable',
  price: 50,
  imageAsset: 'oil_change',
  compatibleVehicleIds: ['v1'],
  isAvailable: false,
);

void main() {
  group('ServiceOption.isCompatibleWith', () {
    test('an option with an empty compatibleVehicleIds list is universally compatible', () {
      expect(_universal.isCompatibleWith('v1'), isTrue);
      expect(_universal.isCompatibleWith('any-other-vehicle'), isTrue);
    });

    test('a non-empty list is an explicit allow-list', () {
      expect(_camryOnly.isCompatibleWith('v1'), isTrue);
      expect(_camryOnly.isCompatibleWith('v2'), isFalse);
    });
  });

  group('compatibleOptions', () {
    test('returns an empty list when no vehicle is selected', () {
      expect(compatibleOptions([_universal, _camryOnly], null), isEmpty);
    });

    test('reproduces the Camry/Tucson compatibility matrix from the spec', () {
      const semiSynthetic = ServiceOption(
        id: 'opt-semi',
        serviceId: 's1',
        nameAr: 'نصف صناعي',
        nameEn: 'Semi-Synthetic',
        descriptionAr: '',
        descriptionEn: '',
        price: 40,
        imageAsset: 'oil_change',
        compatibleVehicleIds: ['v1', 'v2'],
        isAvailable: true,
      );
      const fullSynthetic = ServiceOption(
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
      final allOptions = [_camryOnly, semiSynthetic, fullSynthetic];

      final forCamry = compatibleOptions(allOptions, 'v1');
      expect(forCamry.map((o) => o.id), containsAll(['opt-camry', 'opt-semi']));
      expect(forCamry.map((o) => o.id), isNot(contains('opt-full')));

      final forTucson = compatibleOptions(allOptions, 'v2');
      expect(forTucson.map((o) => o.id), containsAll(['opt-semi', 'opt-full']));
      expect(forTucson.map((o) => o.id), isNot(contains('opt-camry')));
    });

    test('excludes options that are compatible but not available', () {
      final result = compatibleOptions([_unavailableButCompatible], 'v1');
      expect(result, isEmpty);
    });
  });
}
