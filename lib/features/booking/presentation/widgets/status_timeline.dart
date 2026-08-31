import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/booking.dart';

enum _NodeState { done, current, pending }

/// The upcoming -> technicianOnTheWay -> inProgress -> completed timeline.
/// [BookingStatus] has no distinct "assigned" state of its own, so
/// "Technician Assigned" is treated as done from technicianOnTheWay onward
/// — a reasonable single point since the model doesn't track it separately.
/// Never used for [BookingStatus.cancelled] — that gets its own layout.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status});

  final BookingStatus status;

  static const _statusOrder = {
    BookingStatus.upcoming: 0,
    BookingStatus.technicianOnTheWay: 1,
    BookingStatus.inProgress: 2,
    BookingStatus.completed: 3,
  };

  _NodeState _stateFor(int stepIndex, int currentIndex, {required bool canBeCurrent}) {
    if (canBeCurrent && currentIndex == stepIndex) return _NodeState.current;
    return currentIndex >= stepIndex ? _NodeState.done : _NodeState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIndex = _statusOrder[status] ?? 0;

    final steps = [
      (label: l10n.bookingConfirmedTitle, state: _stateFor(0, currentIndex, canBeCurrent: false)),
      (label: l10n.trackingTimelineAssignedLabel, state: _stateFor(1, currentIndex, canBeCurrent: false)),
      (label: l10n.technicianOnTheWayTitle, state: _stateFor(1, currentIndex, canBeCurrent: true)),
      (label: l10n.serviceInProgressTitle, state: _stateFor(2, currentIndex, canBeCurrent: true)),
      (label: l10n.serviceCompletedTitle, state: _stateFor(3, currentIndex, canBeCurrent: true)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineNode(label: steps[i].label, state: steps[i].state, isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.label, required this.state, required this.isLast});

  final String label;
  final _NodeState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      _NodeState.done => AppColors.success,
      _NodeState.current => AppColors.primary,
      _NodeState.pending => AppColors.border,
    };
    final icon = switch (state) {
      _NodeState.done => Icons.check_circle,
      _NodeState.current => Icons.radio_button_checked,
      _NodeState.pending => Icons.radio_button_unchecked,
    };

    return Semantics(
      label: switch (state) {
        _NodeState.done => '$label — done',
        _NodeState.current => '$label — in progress',
        _NodeState.pending => '$label — pending',
      },
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(icon, color: color, size: 22),
                if (!isLast) Expanded(child: Container(width: 2, color: color.withValues(alpha: state == _NodeState.pending ? 1 : 0.4))),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 20, top: 1),
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: state == _NodeState.pending ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: state == _NodeState.current ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
