/// Result of [calculateBookingPrice] — a breakdown, not just a total, so the
/// UI can show "base + option + fees = total" without doing arithmetic
/// itself. See domain/pricing.dart.
class BookingPriceBreakdown {
  const BookingPriceBreakdown({
    required this.basePrice,
    required this.optionPrice,
    required this.fees,
    required this.total,
  });

  final double basePrice;
  final double optionPrice;
  final double fees;
  final double total;
}
