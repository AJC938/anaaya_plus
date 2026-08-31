import 'plate.dart';

/// Field-level error codes — the domain layer stays free of localized
/// strings; the form widget maps each code to the right l10n message.
enum VehicleFieldError { required, invalidYear, invalidPlate }

bool isValidYear(int year) {
  final currentYear = DateTime.now().year;
  return year >= 1980 && year <= currentYear + 1;
}

/// Errors for one form submission, keyed by field. All null means the form
/// is valid.
class VehicleFormErrors {
  const VehicleFormErrors({this.make, this.model, this.year, this.plateNumber});

  final VehicleFieldError? make;
  final VehicleFieldError? model;
  final VehicleFieldError? year;
  final VehicleFieldError? plateNumber;

  bool get isValid => make == null && model == null && year == null && plateNumber == null;
}

/// Pure validation for the Add/Edit vehicle form — no widget/BuildContext
/// involved, so it's fully unit-testable.
VehicleFormErrors validateVehicleForm({
  required String? make,
  required String? model,
  required String yearText,
  required String plateNumber,
}) {
  VehicleFieldError? makeError;
  VehicleFieldError? modelError;
  VehicleFieldError? yearError;
  VehicleFieldError? plateError;

  if (make == null || make.isEmpty) makeError = VehicleFieldError.required;
  if (model == null || model.isEmpty) modelError = VehicleFieldError.required;

  final trimmedYear = yearText.trim();
  if (trimmedYear.isEmpty) {
    yearError = VehicleFieldError.required;
  } else {
    final year = int.tryParse(trimmedYear);
    if (year == null || !isValidYear(year)) yearError = VehicleFieldError.invalidYear;
  }

  final trimmedPlate = plateNumber.trim();
  if (trimmedPlate.isEmpty) {
    plateError = VehicleFieldError.required;
  } else if (!isValidPlate(trimmedPlate)) {
    plateError = VehicleFieldError.invalidPlate;
  }

  return VehicleFormErrors(make: makeError, model: modelError, year: yearError, plateNumber: plateError);
}
