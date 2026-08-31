import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../notifications/application/notification_providers.dart';
import '../../application/home_providers.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(homeUserProvider);
    // BE-08: unread count is derived from whatever's already loaded — see
    // unreadNotificationCountProvider's own doc comment — so this never
    // triggers its own fetch, it just reflects notificationsListProvider's
    // current value (0 until that's loaded at least once).
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Row(
      children: [
        Expanded(
          child: userAsync.when(
            data: (user) => Text(
              l10n.homeGreeting(user.name),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            loading: () => const LoadingPlaceholder(height: 28, width: 180, borderRadius: 8),
            // The header is the app's own chrome, so a failed user fetch
            // still shows the app name rather than an error state.
            error: (_, _) => Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: l10n.notifications,
              onPressed: () => context.push(AppRoutes.notifications()),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
            if (unreadCount > 0)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: IgnorePointer(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
