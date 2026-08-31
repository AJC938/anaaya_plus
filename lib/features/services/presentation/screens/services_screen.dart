import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/services_providers.dart';
import '../widgets/service_list_card.dart';

/// The Services catalog. A clean handoff to Service Details — the future
/// Booking Flow is out of scope here.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servicesAsync = ref.watch(servicesListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sectionServices)),
      body: SafeArea(
        child: servicesAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const LoadingPlaceholder(height: 84),
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.sectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(servicesListProvider),
          ),
          data: (services) => services.isEmpty
              ? FullScreenMessage(icon: Icons.inventory_2_outlined, message: l10n.servicesEmptyMessage)
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: services.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return ServiceListCard(
                      service: service,
                      onTap: () => context.push(AppRoutes.serviceDetails(service.id)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
