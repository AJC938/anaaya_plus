import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/asset_visual.dart';
import '../../application/cars_providers.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/vehicle_validation.dart';
import '../widgets/vehicle_form.dart';

/// One reusable screen for both Add and Edit — Edit prefills from the
/// already-loaded vehicle list (no separate fetch-by-id call, matching the
/// approved repository contract).
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  /// Null means Add mode.
  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  late final VehicleFormController _formController;
  Vehicle? _editingVehicle;
  VehicleFormErrors? _errors;
  bool _isSaving = false;

  bool get _isEditMode => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final vehicles = ref.read(carsControllerProvider).value ?? const <Vehicle>[];
      for (final vehicle in vehicles) {
        if (vehicle.id == widget.vehicleId) {
          _editingVehicle = vehicle;
          break;
        }
      }
    }
    _formController = VehicleFormController(initialVehicle: _editingVehicle);
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return; // guards against duplicate submissions

    final errors = _formController.validate();
    if (!errors.isValid) {
      setState(() => _errors = errors);
      return;
    }

    setState(() {
      _errors = null;
      _isSaving = true;
    });

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(carsControllerProvider.notifier);
    final year = int.parse(_formController.yearController.text.trim());

    try {
      if (_isEditMode && _editingVehicle != null) {
        await notifier.updateVehicle(
          _editingVehicle!.copyWith(
            make: _formController.make.value,
            model: _formController.model.value,
            year: year,
            plateNumber: _formController.plateController.text,
          ),
        );
      } else {
        await notifier.addVehicle(
          make: _formController.make.value!,
          model: _formController.model.value!,
          year: year,
          plateNumber: _formController.plateController.text,
        );
      }
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(SnackBar(content: Text(_isEditMode ? l10n.vehicleUpdatedMessage : l10n.vehicleSavedMessage)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveVehicleErrorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? l10n.editVehicleTitle : l10n.addVehicleCta)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: AssetVisual(assetKey: _editingVehicle?.imageAsset ?? 'vehicle_sedan', size: 72)),
              const SizedBox(height: 24),
              VehicleForm(controller: _formController, errors: _errors),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                            ),
                            const SizedBox(width: 10),
                            Text(l10n.savingLabel),
                          ],
                        )
                      : Text(_isEditMode ? l10n.saveChangesCta : l10n.saveVehicleCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
