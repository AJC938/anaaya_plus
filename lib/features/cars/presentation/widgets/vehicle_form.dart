import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/make_model_catalog.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/vehicle_validation.dart';

/// Owns the Add/Edit vehicle form's local state — no Riverpod providers for
/// individual fields, per the approved architecture. The screen creates one
/// per form session and disposes it when done.
class VehicleFormController {
  VehicleFormController({Vehicle? initialVehicle})
    : make = ValueNotifier(initialVehicle?.make),
      model = ValueNotifier(initialVehicle?.model),
      yearController = TextEditingController(text: initialVehicle?.year.toString() ?? ''),
      plateController = TextEditingController(text: initialVehicle?.plateNumber ?? '');

  final ValueNotifier<String?> make;
  final ValueNotifier<String?> model;
  final TextEditingController yearController;
  final TextEditingController plateController;

  /// Changing Make resets Model whenever the current Model isn't offered
  /// for the new Make — the dependency is enforced here, not in the UI.
  void onMakeChanged(String? newMake) {
    make.value = newMake;
    if (!getModelsForMake(newMake).contains(model.value)) {
      model.value = null;
    }
  }

  VehicleFormErrors validate() {
    return validateVehicleForm(
      make: make.value,
      model: model.value,
      yearText: yearController.text,
      plateNumber: plateController.text,
    );
  }

  void dispose() {
    make.dispose();
    model.dispose();
    yearController.dispose();
    plateController.dispose();
  }
}

String? _fieldErrorText(AppLocalizations l10n, VehicleFieldError? error) {
  return switch (error) {
    null => null,
    VehicleFieldError.required => l10n.fieldRequiredError,
    VehicleFieldError.invalidYear => l10n.invalidYearError,
    VehicleFieldError.invalidPlate => l10n.invalidPlateError,
  };
}

/// Make/Model/Year/License Plate — the one reusable form for both Add and
/// Edit. Errors are passed in (recomputed by the screen on submit) rather
/// than owned here.
class VehicleForm extends StatelessWidget {
  const VehicleForm({super.key, required this.controller, required this.errors});

  final VehicleFormController controller;
  final VehicleFormErrors? errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.makeLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: Listenable.merge([controller.make, controller.model]),
          builder: (context, _) {
            final selectedMake = controller.make.value;
            final availableModels = getModelsForMake(selectedMake);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedMake,
                  decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.make)),
                  items: [for (final make in getMakes()) DropdownMenuItem(value: make, child: Text(make))],
                  onChanged: controller.onMakeChanged,
                ),
                const SizedBox(height: 16),
                Text(l10n.modelLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  // Remounts (and re-seeds from initialValue) whenever Make
                  // changes, so a Model reset by onMakeChanged is reflected.
                  key: ValueKey('model-dropdown-$selectedMake'),
                  initialValue: controller.model.value,
                  decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.model)),
                  items: [for (final model in availableModels) DropdownMenuItem(value: model, child: Text(model))],
                  onChanged: selectedMake == null ? null : (value) => controller.model.value = value,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(l10n.yearLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.yearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.year)),
        ),
        const SizedBox(height: 16),
        Text(l10n.licensePlateLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.plateController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(border: const OutlineInputBorder(), errorText: _fieldErrorText(l10n, errors?.plateNumber)),
        ),
      ],
    );
  }
}
