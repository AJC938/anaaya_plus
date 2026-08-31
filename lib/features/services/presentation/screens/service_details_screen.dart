import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../../booking/application/booking_draft_controller.dart';
import '../../../cars/application/cars_providers.dart';
import '../../application/service_selection_controller.dart';
import '../../application/services_providers.dart';
import '../../domain/compatibility.dart';
import '../../domain/models/service.dart';
import '../../domain/models/service_option.dart';
import '../../domain/models/service_selection_state.dart';
import '../../domain/pricing.dart';
import '../../domain/service_cta.dart';
import '../widgets/included_items_list.dart';
import '../widgets/price_summary.dart';
import '../widgets/product_option_card.dart';
import '../widgets/service_hero.dart';
import '../widgets/vehicle_selector.dart';

/// Service overview → what's included → vehicle → compatible options →
/// price → CTA. The future Booking Flow is out of scope — the CTA is a
/// clean handoff, never a fake booking.
class ServiceDetailsScreen extends ConsumerWidget {
  const ServiceDetailsScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final serviceAsync = ref.watch(serviceByIdProvider(serviceId));

    return Scaffold(
      appBar: AppBar(title: Text(serviceAsync.value?.name(locale) ?? l10n.sectionServices)),
      body: SafeArea(
        child: serviceAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              LoadingPlaceholder(height: 220),
              SizedBox(height: 16),
              LoadingPlaceholder(height: 110),
            ],
          ),
          error: (_, _) => FullScreenMessage(
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            message: l10n.sectionErrorMessage,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(serviceByIdProvider(serviceId)),
          ),
          data: (service) => service == null
              ? FullScreenMessage(icon: Icons.block, message: l10n.serviceUnavailableMessage)
              : _ServiceDetailsBody(service: service),
        ),
      ),
    );
  }
}

class _ServiceDetailsBody extends ConsumerWidget {
  const _ServiceDetailsBody({required this.service});

  final Service service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final selection = ref.watch(serviceSelectionProvider(service.id));
    final selectionNotifier = ref.read(serviceSelectionProvider(service.id).notifier);

    // Only fetched for services that actually offer product options — a
    // service like Car Wash never touches this provider.
    final optionsAsync = service.requiresProductSelection ? ref.watch(serviceOptionsProvider(service.id)) : null;
    final allOptions = optionsAsync?.value ?? const <ServiceOption>[];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ServiceHero(service: service),
        if (service.includedItems(locale).isNotEmpty) ...[
          const SizedBox(height: 20),
          IncludedItemsList(items: service.includedItems(locale)),
        ],
        if (service.requiresVehicle) ...[
          const SizedBox(height: 20),
          _VehicleSection(
            selectedVehicleId: selection.selectedVehicleId,
            onSelectVehicle: (vehicleId) => selectionNotifier.selectVehicle(vehicleId, allOptions),
          ),
        ],
        if (service.requiresProductSelection && selection.selectedVehicleId != null) ...[
          const SizedBox(height: 20),
          _OptionsSection(
            service: service,
            optionsAsync: optionsAsync!,
            selection: selection,
            onSelectOption: selectionNotifier.selectOption,
            onRetry: () => ref.invalidate(serviceOptionsProvider(service.id)),
          ),
        ],
        const SizedBox(height: 24),
        _PrimaryCta(service: service, selection: selection),
      ],
    );
  }
}

class _VehicleSection extends ConsumerWidget {
  const _VehicleSection({required this.selectedVehicleId, required this.onSelectVehicle});

  final String? selectedVehicleId;
  final ValueChanged<String> onSelectVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The user's real Cars data — the single source of truth for vehicle
    // selection throughout Booking (see carsControllerProvider's own doc
    // comment). Not servicesVehiclesProvider/VehicleSummary: that was a
    // Services-local mock catalog whose ids ('v1', 'v2', ...) never matched
    // a real users/{uid}/cars/{carId} document, which is what made Review
    // fail to resolve the selected vehicle.
    final vehiclesAsync = ref.watch(carsControllerProvider);

    return vehiclesAsync.when(
      loading: () => const LoadingPlaceholder(height: 88),
      error: (_, _) => SectionErrorState(onRetry: () => ref.invalidate(carsControllerProvider)),
      data: (vehicles) => vehicles.isEmpty
          ? const _NoVehiclePrompt()
          : VehicleSelector(vehicles: vehicles, selectedVehicleId: selectedVehicleId, onSelect: onSelectVehicle),
    );
  }
}

class _NoVehiclePrompt extends StatelessWidget {
  const _NoVehiclePrompt();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.garage_outlined, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.addVehicleToContinuePrompt, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: 12),
          // Reuses the existing shell navigation — no separate routing logic.
          FilledButton(onPressed: () => context.go(AppRoutes.cars), child: Text(l10n.addVehicleCta)),
        ],
      ),
    );
  }
}

class _OptionsSection extends StatelessWidget {
  const _OptionsSection({
    required this.service,
    required this.optionsAsync,
    required this.selection,
    required this.onSelectOption,
    required this.onRetry,
  });

  final Service service;
  final AsyncValue<List<ServiceOption>> optionsAsync;
  final ServiceSelectionState selection;
  final ValueChanged<String> onSelectOption;
  final VoidCallback onRetry;

  static ServiceOption? _findById(List<ServiceOption> options, String? id) {
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    return optionsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.compatibleOptionsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          const LoadingPlaceholder(height: 76),
          const SizedBox(height: 10),
          const LoadingPlaceholder(height: 76),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.compatibleOptionsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SectionErrorState(onRetry: onRetry),
        ],
      ),
      data: (allOptions) {
        final compatible = compatibleOptions(allOptions, selection.selectedVehicleId);
        final selectedOption = _findById(allOptions, selection.selectedOptionId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.compatibleOptionsTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (compatible.isEmpty)
              Container(
                padding: const EdgeInsetsDirectional.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.noCompatibleOptionsMessage, style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              )
            else
              for (final option in compatible)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 10),
                  child: ProductOptionCard(
                    option: option,
                    selected: option.id == selection.selectedOptionId,
                    onSelect: () => onSelectOption(option.id),
                  ),
                ),
            if (selectedOption != null)
              PriceSummary(
                breakdown: calculatePrice(basePrice: service.startingPrice, selectedOption: selectedOption),
                optionName: selectedOption.name(locale),
              ),
          ],
        );
      },
    );
  }
}

class _PrimaryCta extends ConsumerWidget {
  const _PrimaryCta({required this.service, required this.selection});

  final Service service;
  final ServiceSelectionState selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctaState = resolveCtaState(service: service, selection: selection);

    if (ctaState == ServiceCtaState.unavailable) {
      return Row(
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.serviceUnavailableMessage, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      );
    }

    final label = switch (ctaState) {
      ServiceCtaState.selectVehicle => l10n.selectVehicleAction,
      ServiceCtaState.selectOption => l10n.selectOptionAction,
      ServiceCtaState.ready => l10n.bookThisServiceCta,
      ServiceCtaState.unavailable => '', // unreachable — handled above
    };

    // Every service in the current catalog requires a vehicle, so `ready`
    // always has one selected — this guard is a defensive fallback, not the
    // expected path, in case a future vehicle-less service ever exists.
    final vehicleId = selection.selectedVehicleId;
    final canStartBooking = ctaState == ServiceCtaState.ready && vehicleId != null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canStartBooking
            ? () {
                ref
                    .read(bookingDraftControllerProvider.notifier)
                    .startOrUpdateDraft(serviceId: service.id, serviceOptionId: selection.selectedOptionId, vehicleId: vehicleId);
                context.push(AppRoutes.bookingLocation(service.id));
              }
            : null,
        child: Text(label),
      ),
    );
  }
}
