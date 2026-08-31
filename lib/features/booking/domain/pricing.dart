import 'models/booking_price_breakdown.dart';

/// Flat mock service fee. A real backend would compute this (distance,
/// time-of-day, etc.) — this mock milestone uses one constant so the Review
/// screen has a real (non-zero) fees line, matching the approved example.
const double bookingServiceFee = 10;

/// Pure pricing logic — no widget, provider, or repository touches
/// arithmetic directly. Mirrors Services' `calculatePrice` shape with an
/// added fees line, without coupling Booking to Service Details UI.
BookingPriceBreakdown calculateBookingPrice({
  required double basePrice,
  double optionPrice = 0,
  double fees = bookingServiceFee,
}) {
  return BookingPriceBreakdown(basePrice: basePrice, optionPrice: optionPrice, fees: fees, total: basePrice + optionPrice + fees);
}
