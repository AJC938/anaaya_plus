import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/home_providers.dart';
import 'service_card.dart';

class ServicesSection extends ConsumerWidget {
  const ServicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final servicesAsync = ref.watch(homeServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.sectionServices,
          actionLabel: l10n.viewAll,
          // Reuses the existing go_router setup — no separate routing logic.
          onAction: () => context.push(AppRoutes.services()),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: servicesAsync.when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const LoadingPlaceholder(width: 128, height: 150),
            ),
            error: (_, _) => SectionErrorState(height: 150, onRetry: () => ref.invalidate(homeServicesProvider)),
            data: (services) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final service = services[index];
                return ServiceCard(
                  service: service,
                  onTap: () => context.push(AppRoutes.serviceDetails(service.id)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
