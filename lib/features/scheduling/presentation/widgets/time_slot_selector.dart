import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/time_slot.dart';

/// A wrap grid of time chips. Unavailable slots are visually flattened and
/// unresponsive — never selectable, never color-only (they're also
/// crossed out).
class TimeSlotSelector extends StatelessWidget {
  const TimeSlotSelector({super.key, required this.slots, required this.selectedSlotId, required this.onSelect});

  final List<TimeSlot> slots;
  final String? selectedSlotId;
  final ValueChanged<TimeSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final timeFormat = DateFormat.jm(locale);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final slot in slots)
          _TimeSlotChip(
            label: timeFormat.format(slot.start),
            selected: slot.id == selectedSlotId,
            available: slot.isAvailable,
            onTap: slot.isAvailable ? () => onSelect(slot) : null,
          ),
      ],
    );
  }
}

class _TimeSlotChip extends StatelessWidget {
  const _TimeSlotChip({required this.label, required this.selected, required this.available, required this.onTap});

  final String label;
  final bool selected;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      enabled: available,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: !available
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : selected
                    ? AppColors.onPrimary
                    : AppColors.textPrimary,
                decoration: available ? null : TextDecoration.lineThrough,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
