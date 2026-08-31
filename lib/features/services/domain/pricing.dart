import 'models/service_option.dart';

/// Result of [calculatePrice] — a breakdown, not just a total, so the UI can
/// show "base + option = total" without doing arithmetic itself.
class PriceBreakdown {
  const PriceBreakdown({required this.basePrice, required this.optionPrice, required this.total});

  final double basePrice;
  final double optionPrice;
  final double total;
}

/// Pure pricing logic — no widget, provider, or repository touches
/// arithmetic directly. A backend will become the final pricing authority
/// later; this is the one seam that call would replace.
PriceBreakdown calculatePrice({required double basePrice, ServiceOption? selectedOption}) {
  final optionPrice = selectedOption?.price ?? 0;
  return PriceBreakdown(basePrice: basePrice, optionPrice: optionPrice, total: basePrice + optionPrice);
}
