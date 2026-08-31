import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/notification_controller.dart';
import '../../application/notification_providers.dart';
import '../../domain/models/app_notification.dart';

/// Notification history — reached from the Home bell icon (see
/// `home_header.dart`). Deliberately a single flat list, not a new product
/// surface: the same read-only-summary-plus-tap-to-navigate shape My
/// Bookings already uses, matching Phase 9's "do not create an elaborate
/// new notifications product."
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsScreenTitle)),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const LoadingPlaceholder(height: 76),
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.unableToLoadNotificationsMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(notificationsListProvider),
          ),
          data: (notifications) =>
              notifications.isEmpty ? const _EmptyNotificationsState() : _NotificationsList(notifications: notifications),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(l10n.noNotificationsTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.noNotificationsSubtitle, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _NotificationTile(notification: notifications[index]),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref.read(notificationControllerProvider.notifier).markAsRead(notification.id);
    }
    if (!context.mounted) return;
    final bookingReference = notification.bookingReference;
    if (bookingReference != null) {
      context.push(AppRoutes.bookingTracking(bookingReference));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final dateTimeFormat = DateFormat.yMMMd(locale.toString()).add_jm();

    return Semantics(
      button: true,
      label: '${notification.title}, ${notification.body}',
      child: InkWell(
        onTap: () => _handleTap(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsetsDirectional.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: notification.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4, end: 10),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: notification.isRead ? Colors.transparent : AppColors.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(
                      dateTimeFormat.format(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
