import '../domain/models/service.dart';
import '../domain/models/service_option.dart';
import 'services_repository.dart';

/// Local/in-memory stand-in for a future Services repository backed by
/// Firestore. IDs are kept aligned with Home's own mock catalog (`s1`…`s8`)
/// so a Home service card deep-links to the matching Details entry — both
/// mock sources represent the same conceptual backend catalog.
///
/// The artificial delay is only so the loading/skeleton states are visible
/// when running the app manually. Unlike Home's mock repository, nothing
/// here fails on its own — tests simulate failures by overriding the
/// Riverpod providers directly, not by adding failure modes here.
class MockServicesRepository implements ServicesRepository {
  static const _latency = Duration(milliseconds: 400);

  static final _services = [
    Service(
      id: 's1',
      nameAr: 'تغيير الزيت',
      nameEn: 'Oil Change',
      descriptionAr: 'تغيير زيت المحرك وفلتر الزيت مع فحص بصري أساسي في موقعك.',
      descriptionEn: 'Engine oil and filter replacement with a basic visual inspection, at your location.',
      category: 'maintenance',
      startingPrice: 89,
      estimatedDuration: const Duration(minutes: 40),
      imageAsset: 'oil_change',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: true,
      includedItemsAr: const ['تغيير زيت المحرك', 'تغيير فلتر الزيت', 'فحص بصري أساسي'],
      includedItemsEn: const ['Engine oil replacement', 'Oil filter replacement', 'Basic visual inspection'],
    ),
    Service(
      id: 's2',
      nameAr: 'فحص شامل',
      nameEn: 'Full Inspection',
      descriptionAr: 'فحص شامل لأهم أنظمة سيارتك لاكتشاف أي مشاكل مبكرًا.',
      descriptionEn: "A thorough check of your car's key systems to catch issues early.",
      category: 'inspection',
      startingPrice: 149,
      estimatedDuration: const Duration(minutes: 60),
      imageAsset: 'full_inspection',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['فحص المحرك', 'فحص الفرامل', 'فحص الإطارات والسوائل', 'تقرير الحالة'],
      includedItemsEn: const ['Engine check', 'Brake check', 'Tires and fluids check', 'Condition report'],
    ),
    Service(
      id: 's3',
      nameAr: 'خدمة التكييف',
      nameEn: 'AC Service',
      descriptionAr: 'فحص وشحن نظام التكييف لأداء بارد وموثوق.',
      descriptionEn: 'AC system check and recharge for reliably cold air.',
      category: 'seasonal',
      startingPrice: 129,
      estimatedDuration: const Duration(minutes: 45),
      imageAsset: 'ac_service',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['فحص نظام التكييف', 'شحن الفريون', 'فحص التسريبات'],
      includedItemsEn: const ['AC system check', 'Refrigerant recharge', 'Leak check'],
    ),
    Service(
      id: 's4',
      nameAr: 'خدمة الفرامل',
      nameEn: 'Brake Service',
      descriptionAr: 'فحص واستبدال تيل الفرامل للحفاظ على سلامتك على الطريق.',
      descriptionEn: 'Brake pad inspection and replacement to keep you safe on the road.',
      category: 'safety',
      startingPrice: 199,
      estimatedDuration: const Duration(minutes: 90),
      imageAsset: 'brake_service',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['فحص تيل الفرامل', 'فحص الأقراص', 'اختبار قوة الفرامل'],
      includedItemsEn: const ['Brake pad inspection', 'Disc inspection', 'Brake performance test'],
    ),
    Service(
      id: 's5',
      nameAr: 'الإطارات',
      nameEn: 'Tires',
      descriptionAr: 'فحص ضغط الهواء والاتزان وحالة الإطارات.',
      descriptionEn: 'Tire pressure, balance, and condition check.',
      category: 'tires',
      startingPrice: 99,
      estimatedDuration: const Duration(minutes: 45),
      imageAsset: 'tires',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['فحص ضغط الهواء', 'فحص حالة الإطارات', 'اتزان العجلات'],
      includedItemsEn: const ['Air pressure check', 'Tread condition check', 'Wheel balancing'],
    ),
    Service(
      id: 's6',
      nameAr: 'البطارية',
      nameEn: 'Battery',
      descriptionAr: 'فحص واستبدال البطارية في موقعك دون انتظار.',
      descriptionEn: 'Battery check and replacement at your location, no waiting.',
      category: 'battery',
      startingPrice: 179,
      estimatedDuration: const Duration(minutes: 30),
      imageAsset: 'battery',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: true,
      includedItemsAr: const ['فحص البطارية', 'تركيب البطارية الجديدة', 'فحص نظام الشحن'],
      includedItemsEn: const ['Battery check', 'New battery installation', 'Charging system check'],
    ),
    Service(
      id: 's7',
      nameAr: 'غسيل السيارة',
      nameEn: 'Car Wash',
      descriptionAr: 'غسيل خارجي وداخلي احترافي في موقعك.',
      descriptionEn: 'Professional exterior and interior wash at your location.',
      category: 'cleaning',
      startingPrice: 39,
      estimatedDuration: const Duration(minutes: 30),
      imageAsset: 'car_wash',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['غسيل خارجي', 'تنظيف داخلي', 'تلميع السيارة'],
      includedItemsEn: const ['Exterior wash', 'Interior cleaning', 'Exterior polish'],
    ),
    Service(
      id: 's8',
      nameAr: 'العناية بالسيارة',
      nameEn: 'Car Care',
      descriptionAr: 'باقة عناية شاملة تحافظ على مظهر سيارتك وقيمتها.',
      descriptionEn: "A complete care package that protects your car's look and value.",
      category: 'care',
      startingPrice: 59,
      estimatedDuration: const Duration(minutes: 60),
      imageAsset: 'car_care',
      isActive: true,
      requiresVehicle: true,
      requiresProductSelection: false,
      includedItemsAr: const ['تنظيف داخلي وخارجي', 'العناية بالمقاعد', 'ملمع الإطارات'],
      includedItemsEn: const ['Interior and exterior cleaning', 'Seat care', 'Tire shine'],
    ),
  ];

  // Oil options for s1. Each option carries its own product image key
  // rather than inheriting the parent service's — see AssetVisual for the
  // lookup.
  //
  // compatibleVehicleIds is intentionally empty (universally compatible)
  // for all three — the field's own doc comment already establishes that
  // an empty list is the "universal" value, and a non-empty list is only
  // ever a literal Firestore vehicle-document-id allow-list. Vehicle
  // selection is now backed by the user's real, per-account
  // users/{uid}/cars/{carId} documents (see carsControllerProvider), whose
  // ids are Firestore auto-ids nobody can predict — a static mock catalog
  // can never hardcode a real user's vehicle id, so any non-empty list here
  // would be permanently unmatchable and silently hide every option (this
  // previously left Oil Change with zero selectable options for any real
  // vehicle). Per the field's own doc comment, a real fitment engine would
  // replace the call site, not this field — until one exists, universal
  // compatibility is the only value that is actually correct for real data.
  static final _oilOptions = [
    const ServiceOption(
      id: 'opt-oil-mineral',
      serviceId: 's1',
      nameAr: 'زيت معدني',
      nameEn: 'Mineral',
      descriptionAr: 'حماية أساسية للمحرك',
      descriptionEn: 'Basic engine protection',
      price: 25,
      imageAsset: 'oil_mineral',
      compatibleVehicleIds: [],
      isAvailable: true,
    ),
    const ServiceOption(
      id: 'opt-oil-semi',
      serviceId: 's1',
      nameAr: 'نصف صناعي',
      nameEn: 'Semi-Synthetic',
      descriptionAr: 'توازن جيد بين الحماية والسعر',
      descriptionEn: 'Good balance of protection and price',
      price: 40,
      imageAsset: 'oil_semi_synthetic',
      compatibleVehicleIds: [],
      isAvailable: true,
    ),
    const ServiceOption(
      id: 'opt-oil-full',
      serviceId: 's1',
      nameAr: 'صناعي كامل',
      nameEn: 'Full Synthetic',
      descriptionAr: 'حماية متقدمة للمحرك',
      descriptionEn: 'Advanced engine protection',
      price: 60,
      imageAsset: 'oil_full_synthetic',
      compatibleVehicleIds: [],
      isAvailable: true,
    ),
  ];

  // Battery options for s6 — both universally compatible (empty list), for
  // the same reason as the oil options above: any non-empty
  // compatibleVehicleIds can only ever reference a specific Firestore
  // vehicle document id, which no static mock catalog can predict for a
  // real, per-account vehicle. Each option carries its own product image
  // key rather than inheriting the parent service's.
  static final _batteryOptions = [
    const ServiceOption(
      id: 'opt-battery-standard',
      serviceId: 's6',
      nameAr: 'بطارية قياسية',
      nameEn: 'Standard Battery',
      descriptionAr: 'بديل موثوق بضمان قياسي',
      descriptionEn: 'A reliable replacement with standard warranty',
      price: 0,
      imageAsset: 'battery_standard',
      compatibleVehicleIds: [],
      isAvailable: true,
    ),
    const ServiceOption(
      id: 'opt-battery-premium',
      serviceId: 's6',
      nameAr: 'بطارية بريميوم',
      nameEn: 'Premium Battery',
      descriptionAr: 'عمر أطول وضمان ممتد',
      descriptionEn: 'Longer life with extended warranty',
      price: 90,
      imageAsset: 'battery_premium',
      compatibleVehicleIds: [],
      isAvailable: true,
    ),
  ];

  @override
  Future<List<Service>> fetchServices() async {
    await Future.delayed(_latency);
    return _services;
  }

  @override
  Future<Service?> fetchServiceById(String id) async {
    await Future.delayed(_latency);
    for (final service in _services) {
      if (service.id == id) return service;
    }
    return null;
  }

  @override
  Future<List<ServiceOption>> fetchOptions(String serviceId) async {
    await Future.delayed(_latency);
    return switch (serviceId) {
      's1' => _oilOptions,
      's6' => _batteryOptions,
      _ => const [],
    };
  }
}
