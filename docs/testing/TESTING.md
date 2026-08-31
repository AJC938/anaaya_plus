# Testing Strategy

Anaaya Plus uses automated tests at multiple levels so feature behavior can be verified without relying only on manual emulator testing.

## Flutter

Run:

```bash
flutter analyze
flutter test
```

The current documented baseline is:

- `flutter test`: 629 passed, 0 failed.
- `flutter analyze`: 1 info-level style finding, 0 errors, 0 warnings.

## Backend

Run the relevant Deno tests under:

```text
supabase/functions/_shared/
```

The current documented baseline is 70 passed, 0 failed for the backend shared-function test suite.

## What is covered

### Authentication

- Phone-number normalization and validation.
- OTP generation and verification.
- Expiry handling.
- Attempt limits.
- Resend cooldown and rate limiting.
- Replay rejection.
- Firebase Custom Token exchange behavior.

### Data and repositories

- Bookings.
- Vehicles.
- Locations.
- Payments.
- Notifications.
- Device tokens.

### Business behavior

- Booking state transitions.
- Payment state transitions.
- Notification lifecycle.
- Scheduling and slot claiming.
- Cancellation rules.

### UI

Major screens and flows are covered by widget tests, including Arabic/RTL and English/LTR scenarios.

## Test philosophy

Tests should verify observable behavior and meaningful business rules rather than implementation details. When a feature changes, update the smallest relevant test layer first and add an integration-style test when a change crosses feature boundaries.

## Manual verification

Automated tests do not replace device verification for platform-specific behavior such as maps, location permissions, FCM delivery, keyboard/IME behavior, or native Android integration. These should be recorded as manual verification when relevant to a release.
