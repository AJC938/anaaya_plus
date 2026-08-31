import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Resolves a semantic asset key (e.g. a [Service.imageAsset]) to a local
/// visual. This is the single seam to swap for real imagery later — e.g.
/// `Image.network(url)` from Firebase Storage — without touching any call
/// site, since callers only ever pass the semantic key.
class AssetVisual extends StatelessWidget {
  const AssetVisual({super.key, required this.assetKey, this.size = 44});

  final String assetKey;
  final double size;

  static const Map<String, IconData> _icons = {
    'oil_change': Icons.opacity,
    'full_inspection': Icons.fact_check_outlined,
    'ac_service': Icons.ac_unit,
    'brake_service': Icons.car_repair,
    'tires': Icons.tire_repair,
    'battery': Icons.battery_charging_full,
    'car_wash': Icons.local_car_wash,
    'car_care': Icons.build_circle_outlined,
    'vehicle_sedan': Icons.directions_car_filled_outlined,
    'vehicle_suv': Icons.directions_car_filled_outlined,
    // Product options — each grade/tier gets its own distinct key rather
    // than inheriting its parent service's, so cards can visually tell
    // products apart at a glance.
    'oil_mineral': Icons.water_drop,
    'oil_semi_synthetic': Icons.invert_colors,
    'oil_full_synthetic': Icons.science,
    'battery_standard': Icons.battery_std,
    'battery_premium': Icons.battery_full,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(_icons[assetKey] ?? Icons.build_circle_outlined, color: AppColors.primary, size: size * 0.5),
    );
  }
}
