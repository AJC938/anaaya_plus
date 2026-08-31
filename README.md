# Anaaya Plus (عناية بلس)

A mobile car-service booking app for the Saudi market — a customer books a service, a
technician comes to them. Built with Flutter, Firebase, and Supabase Edge Functions as a
software-engineering portfolio project.

## Overview

Anaaya Plus implements a full customer-facing booking lifecycle: browse services, pick a
vehicle and time slot, confirm a location, complete a (simulated) payment, and track the
booking through a simulated technician-dispatch lifecycle — with real push notifications and a
custom phone/OTP authentication flow behind it.

**This is a test/portfolio project, not a production service.** Two subsystems are explicitly
simulated rather than real:

- **Payment** is a local test simulation — there is no payment gateway integration. Pressing
  "Simulate Payment" writes a `paid` record directly to Firestore. No card data, no gateway
  credentials, no money moves anywhere.
- **SMS delivery** uses Twilio's zero-cost TEST credentials — no real SMS is ever sent. The
  backend can optionally echo the generated OTP back to the client in test mode so the flow is
  fully verifiable without a real phone.

Everything else — Firebase Authentication sessions, Firestore data, FCM push notifications,
Firestore security rules, the booking/scheduling state machine — is real and enforced the same
way it would be in a production app; only the two external-money/external-SMS integration
points are stubbed out.

## Key Features

- Custom phone-number + OTP sign-in (not Firebase's native phone auth — see Architecture)
- Vehicle management (add/edit/delete)
- Service catalog with per-service options and dynamic pricing
- Saved locations, current-location detection, and a map picker
- Slot-based scheduling with atomic, race-safe slot claiming
- Local test payment simulation with a real Firestore-backed payment record
- Simulated technician-dispatch tracking lifecycle (assigned → on the way → in progress →
  completed) with booking cancellation
- Push notifications (FCM) tied to booking/payment lifecycle events
- Full Arabic (RTL, primary) and English (LTR) localization

## Architecture

```
Flutter (Riverpod + go_router)
  │
  ├─ Firebase Authentication  — session of record for the whole app
  ├─ Cloud Firestore          — bookings, vehicles, locations, payments, notifications, device tokens
  ├─ Firebase Cloud Messaging — push notifications
  │
  └─ Supabase Edge Functions (Deno) — backend execution for the OTP flow only
       ├─ send-otp     → generates + hashes an OTP, calls Twilio TEST API
       ├─ verify-otp   → validates the OTP, mints a Firebase Custom Token
       └─ Firebase Custom Token → FirebaseAuth.signInWithCustomToken() → real Firebase session
```

**Why a custom OTP flow instead of Firebase's native phone auth?** Firebase's own phone
verification requires Play Integrity / SafetyNet and a real SMS provider, which isn't practical
for a zero-cost portfolio demo. Instead: a Supabase Edge Function generates and hashes a
one-time code, sends it through Twilio's official TEST credentials (magic numbers that are
validated but never actually deliver or bill), and — once verified — mints a Firebase Custom
Token that the Flutter app exchanges for a real, fully-functional Firebase Authentication
session. From that point on, the app behaves exactly as if the user had signed in through any
other Firebase Auth method: the same `authStateChanges()` stream, the same ID tokens, the same
Firestore security-rule enforcement.

**Payment is intentionally client-authoritative.** `PaymentController.submitPayment` writes
directly to `bookings/{id}/payment/latest`, gated only by Firestore security rules (the owning
user may write their own payment document). There is no server-side verification step — a real
production integration would need one. This is documented in code (see
`lib/features/payment/data/payment_repository.dart`) and called out explicitly here so it's
never mistaken for a production-ready payment path.

**OTP security controls** (enforced server-side, in `supabase/functions/_shared/otpStore.ts`):
5-minute expiry, a maximum of 5 verification attempts, a 60-second resend cooldown, a 3 sends/
hour rate limit per phone number, one-time use, and replay rejection after a successful
verification.

## Technology Stack

| Layer | Technology |
|---|---|
| Client | Flutter (Dart), Riverpod, go_router |
| Auth session | Firebase Authentication (Custom Token sign-in) |
| Database | Cloud Firestore |
| Push notifications | Firebase Cloud Messaging |
| Backend execution | Supabase Edge Functions (Deno) |
| OTP delivery (test mode) | Twilio TEST Messaging API |
| Maps | flutter_map / OpenStreetMap |
| Location | geolocator, geocoding |
| Localization | Flutter's official `gen-l10n` (Arabic + English) |

## Application Flow

```
Phone number → OTP (Twilio TEST) → Firebase Custom Token → Firebase session
  → Home → pick a service → pick a vehicle/options → pick a location
  → pick a date/time slot → review → Simulate Payment → Confirmation
  → Tracking (simulated technician dispatch) → Completed
```

Every step from vehicle selection onward reads/writes real Firestore documents scoped to the
signed-in user's UID and enforced by `firestore.rules`.

## Screenshots

Not included in this repository snapshot. The app can be run directly via `flutter run` on an
Android emulator or a physical device to see the full flow end to end.

## Testing

Latest results, run locally against this repository:

| Suite | Command | Result |
|---|---|---|
| Flutter unit/widget tests | `flutter test` | **629 passed**, 0 failed |
| Flutter static analysis | `flutter analyze` | **1 info-level lint**, 0 errors, 0 warnings |
| Supabase/Deno backend tests | `deno test --allow-net --allow-env supabase/functions/_shared/` | **70 passed**, 0 failed |

The single remaining `flutter analyze` finding is a `prefer_initializing_formals` style
suggestion, not a correctness issue.

Test coverage includes: phone number validation, OTP request/verification (success, expiry,
rate-limiting, replay), Firebase Custom Token minting/exchange, Firestore repository behavior
(bookings, vehicles, locations, payments, notifications, device tokens) against realistic
fakes, booking/payment/notification status-transition state machines, and full-screen widget
tests for every major flow in both Arabic and English.

## Project Structure

```
lib/
  app/                    # MaterialApp.router, go_router route table
  core/
    localization/         # gen-l10n output + locale provider
    supabase/              # Supabase Edge Function HTTP clients (OTP)
    theme/                 # ThemeData
    widgets/                # shared UI components
  features/
    auth/                  # phone/OTP sign-in, Firebase Auth session
    booking/                # booking creation, status lifecycle, tracking, cancellation
    bookings/               # bookings list screen
    cars/                   # vehicle management
    home/                   # home dashboard
    location/               # saved locations, current location, map picker
    notifications/          # FCM registration, in-app notification history
    payment/                # local payment simulation
    profile/                # account/profile settings
    scheduling/             # slot availability + atomic slot claiming
    services/               # service catalog + options
  l10n/                    # .arb translation source files
  firebase_options.dart     # FlutterFire-generated Firebase config (public identifiers only)
  main.dart

supabase/
  functions/
    send-otp/              # requests an OTP (Supabase + Twilio TEST)
    verify-otp/             # verifies an OTP, mints a Firebase Custom Token
    verify-firebase-auth/   # verifies a Firebase ID token server-side
    health-check/           # trivial liveness check
    _shared/                # phone normalization, OTP store, Twilio/Firebase clients, tests

android/, ios/              # native platform projects
test/                       # mirrors lib/ — unit, widget, and repository tests
firestore.rules             # Firestore security rules
firestore.indexes.json      # Firestore composite index definitions
```

## Getting Started

```bash
flutter pub get
flutter run
```

Localization (`lib/core/localization/app_localizations*.dart`) is generated from
`lib/l10n/*.arb` via `flutter gen-l10n` and is not committed — it regenerates automatically on
`flutter pub get` / `flutter run` / `flutter build`.

The Supabase backend (`supabase/functions/`) is deployed separately via the Supabase CLI
(`npx supabase functions deploy <name>`) and is not required to build the Flutter app itself —
it's only needed for the phone/OTP sign-in flow to reach a real backend.

## Demo / Portfolio Notes

This project was built to demonstrate:

- A real, working Firebase Authentication integration built on a **custom** credential flow
  (OTP → Custom Token) rather than a stock SDK method
- Backend logic (OTP generation/hashing/rate-limiting, JWT-bearer service-account tokens) written
  and tested independently of the Flutter client, in Deno/TypeScript
- Firestore security rules as the actual enforcement boundary, not just client-side checks
- Atomic, race-safe resource claiming (booking slots) using Firestore transactions
- A layered, testable architecture (domain / data / application / presentation) applied
  consistently across every feature
- Comprehensive automated test coverage across both the Flutter client and the Deno backend

## Known Scope & Limitations

- **No real payment processing.** Payment status is decided and written by the client. This is
  explicitly unsuitable for real money and would need a genuine gateway integration plus
  server-side verification in any production use.
- **No real SMS delivery.** Twilio TEST credentials never send or bill for a real message.
- **No real technician dispatch.** Tracking status changes are simulated by the customer's own
  app (there is no technician-facing app or role in this project).
- **No real-time GPS tracking of a technician** — location features cover the customer's own
  saved/current location only.
- Not hardened, load-tested, or reviewed for production/enterprise deployment.

## Author

Built as a personal software-engineering portfolio project.
