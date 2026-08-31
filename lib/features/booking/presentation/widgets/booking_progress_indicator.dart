import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// A slim, non-decorative step indicator so the four Booking screens read
/// as one journey. [currentStep] is 1-based; steps up to and including it
/// are filled, the rest are outlined.
class BookingProgressIndicator extends StatelessWidget {
  const BookingProgressIndicator({super.key, required this.currentStep});

  final int currentStep;

  static const _totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.bookingStepLabel(currentStep, _totalSteps),
      child: Row(
        children: [
          for (var step = 1; step <= _totalSteps; step++) ...[
            if (step > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: step <= currentStep ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
