/// Trims, collapses internal whitespace, and uppercases a license plate
/// (uppercasing is a no-op on Arabic script, so this is safe for both).
String normalizePlate(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
}

/// A lightweight plausibility check, not government-grade validation — this
/// is deliberately loose: it just rejects empty/garbage input while working
/// for both Saudi Latin-script plates ("ABC 1234") and Arabic script.
bool isValidPlate(String input) {
  final normalized = normalizePlate(input);
  if (normalized.length < 4 || normalized.length > 12) return false;
  final hasLetter = RegExp('[A-Za-z؀-ۿ]').hasMatch(normalized);
  final hasDigit = RegExp('[0-9٠-٩]').hasMatch(normalized);
  return hasLetter && hasDigit;
}
