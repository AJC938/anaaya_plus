import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/availability_day.dart';

/// Horizontal date strip ("Mon 18", "Tue 19", ...). Days without
/// availability are shown (not hidden) so the user understands they're
/// unavailable rather than wondering why a date is missing, but they're
/// disabled — not color alone, since they're also visually flattened and
/// unresponsive to taps.
class DateSelector extends StatelessWidget {
  const DateSelector({super.key, required this.days, required this.selectedDate, required this.onSelect});

  final List<AvailabilityDay> days;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = selectedDate != null && _isSameDate(day.date, selectedDate!);
          return _DateChip(
            day: day,
            selected: selected,
            weekdayLabel: DateFormat.E(locale).format(day.date),
            onTap: day.hasAvailability ? () => onSelect(day.date) : null,
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.day, required this.selected, required this.weekdayLabel, required this.onTap});

  final AvailabilityDay day;
  final bool selected;
  final String weekdayLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = !day.hasAvailability;

    return Semantics(
      selected: selected,
      enabled: !disabled,
      button: true,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Material(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 56,
              padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekdayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(color: selected ? AppColors.onPrimary : AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
