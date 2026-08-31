import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';

/// The customer's avatar. Mock data never has a real [imageAsset], so the
/// normal case is the initials fallback — never a network image.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.fullName, this.imageAsset, this.size = 72});

  final String fullName;
  final String? imageAsset;
  final double size;

  String get _initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (imageAsset != null) {
      return AssetVisual(assetKey: imageAsset!, size: size);
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(color: AppColors.onPrimary, fontSize: size * 0.36, fontWeight: FontWeight.w700),
      ),
    );
  }
}
