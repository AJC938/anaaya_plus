import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/full_screen_message.dart';
import '../../../../core/widgets/section_states.dart';
import '../../application/cars_providers.dart';
import '../../data/cars_repository.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/vehicle_association.dart';
import '../widgets/delete_vehicle_dialog.dart';
import '../widgets/vehicle_card.dart';

/// My Cars — the vehicles the user services with Anaaya Plus. Not a
/// vehicle-management admin table: the default vehicle gets the strongest
/// visual hierarchy, and everything else is a scannable, lightweight card.
class CarsScreen extends ConsumerStatefulWidget {
  const CarsScreen({super.key});

  @override
  ConsumerState<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends ConsumerState<CarsScreen> {
  // At most one mutation is ever in flight from this screen at a time —
  // tracking just its vehicle id keeps the affected card busy without
  // flashing the whole list to a skeleton for a quick action.
  String? _busyVehicleId;

  Future<void> _handleDeleteRequested(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    final status = await ref.read(vehicleAssociationProvider(vehicle.id).future);
    if (!mounted) return;

    if (!canDeleteVehicle(status)) {
      await showCannotDeleteVehicleDialog(context);
      return;
    }

    final confirmed = await showDeleteVehicleDialog(context, vehicleName: vehicle.displayName);
    if (!confirmed || !mounted) return;

    setState(() => _busyVehicleId = vehicle.id);
    try {
      await ref.read(carsControllerProvider.notifier).deleteVehicle(vehicle.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vehicleDeletedMessage)));
    } on VehicleDeleteBlockedException {
      if (!mounted) return;
      await showCannotDeleteVehicleDialog(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.deleteVehicleErrorMessage)));
    } finally {
      if (mounted) setState(() => _busyVehicleId = null);
    }
  }

  Future<void> _handleSetDefault(Vehicle vehicle) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busyVehicleId = vehicle.id);
    try {
      await ref.read(carsControllerProvider.notifier).setDefaultVehicle(vehicle.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.vehicleActionErrorMessage)));
    } finally {
      if (mounted) setState(() => _busyVehicleId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(carsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickAccessCarsTitle)),
      body: SafeArea(child: _buildBody(context, l10n, vehiclesAsync)),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, AsyncValue<List<Vehicle>> vehiclesAsync) {
    if (vehiclesAsync.hasValue) {
      return _CarsList(
        vehicles: vehiclesAsync.value!,
        busyVehicleId: _busyVehicleId,
        onAdd: () => context.push(AppRoutes.addVehicle()),
        onEdit: (vehicle) => context.push(AppRoutes.editVehicle(vehicle.id)),
        onSetDefault: _handleSetDefault,
        onDeleteRequested: _handleDeleteRequested,
      );
    }

    if (vehiclesAsync.hasError) {
      return FullScreenMessage(
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        message: l10n.unableToLoadVehiclesMessage,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(carsControllerProvider),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const LoadingPlaceholder(height: 110),
    );
  }
}

class _CarsList extends StatelessWidget {
  const _CarsList({
    required this.vehicles,
    required this.busyVehicleId,
    required this.onAdd,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDeleteRequested,
  });

  final List<Vehicle> vehicles;
  final String? busyVehicleId;
  final VoidCallback onAdd;
  final ValueChanged<Vehicle> onEdit;
  final ValueChanged<Vehicle> onSetDefault;
  final ValueChanged<Vehicle> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (vehicles.isEmpty) {
      return _EmptyCarsState(onAdd: onAdd);
    }

    Vehicle? defaultVehicle;
    final others = <Vehicle>[];
    for (final vehicle in vehicles) {
      if (vehicle.isDefault) {
        defaultVehicle = vehicle;
      } else {
        others.add(vehicle);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (defaultVehicle != null) ...[_buildCard(defaultVehicle), const SizedBox(height: 24)],
        if (others.isNotEmpty) ...[
          Text(l10n.otherVehiclesTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final vehicle in others) Padding(padding: const EdgeInsetsDirectional.only(bottom: 12), child: _buildCard(vehicle)),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(l10n.addVehicleCta)),
        ),
      ],
    );
  }

  Widget _buildCard(Vehicle vehicle) {
    final isBusy = vehicle.id == busyVehicleId;
    return Opacity(
      opacity: isBusy ? 0.6 : 1,
      child: IgnorePointer(
        ignoring: isBusy,
        child: VehicleCard(
          vehicle: vehicle,
          onEdit: () => onEdit(vehicle),
          onSetDefault: vehicle.isDefault ? null : () => onSetDefault(vehicle),
          onDeleteRequested: () => onDeleteRequested(vehicle),
        ),
      ),
    );
  }
}

class _EmptyCarsState extends StatelessWidget {
  const _EmptyCarsState({required this.onAdd});

  final VoidCallback onAdd;

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
            const Icon(Icons.directions_car_outlined, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(l10n.noVehiclesTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l10n.noVehiclesSubtitle, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAdd, child: Text(l10n.addFirstVehicleCta)),
          ],
        ),
      ),
    );
  }
}
