# Architecture

## System overview

Anaaya Plus is organized as a Flutter client backed by Firebase services, with Supabase Edge Functions providing the custom OTP backend execution path.

```text
┌───────────────────────────────────────────────────────────────┐
│                         Flutter Client                        │
│                                                               │
│  go_router ─ Presentation ─ Application/Controllers           │
│                     │                                         │
│                 Repositories                                  │
└───────────────┬───────────────┬───────────────┬───────────────┘
                │               │               │
                ▼               ▼               ▼
        Firebase Auth      Cloud Firestore       FCM
        Custom Token      bookings/vehicles     Push
                ▲          locations/payments   notifications
                │
                │
        Supabase Edge Functions
                │
        ┌───────┴────────┐
        │                │
     send-otp         verify-otp
        │                │
        ▼                ▼
   Twilio TEST     Firebase Admin
      API          Custom Token
```

## Client layers

### Presentation

Screens, routing, widgets, localization, and user interaction live at the presentation boundary. Screens should not contain direct Firestore or HTTP concerns.

### Application

Controllers/providers coordinate user actions and state transitions. They orchestrate repositories and expose UI-ready state.

### Data

Repositories isolate Firebase, Supabase, local simulation, and other infrastructure from the application layer.

### Domain behavior

Feature-level models and state machines represent business concepts such as bookings, payments, notifications, scheduling, and authentication states.

## Feature boundaries

The current repository separates major product areas into feature modules under `lib/features/`, including authentication, booking, cars, location, notifications, payment, profile, scheduling, services, and home.

This structure is intended to keep feature code cohesive and make infrastructure changes less likely to leak into presentation code.

## Authentication sequence

```text
1. User submits a normalized phone number.
2. Flutter calls the OTP backend.
3. Supabase Edge Function generates and hashes a one-time code.
4. Test-mode Twilio integration handles the verification flow.
5. User submits the OTP.
6. Backend validates expiry, attempts, resend/rate limits, and one-time use.
7. Backend mints a Firebase Custom Token.
8. Flutter exchanges the token with FirebaseAuth.signInWithCustomToken().
9. Firebase Auth becomes the application session of record.
```

The OTP controls documented by the project include a five-minute expiry, five verification attempts, a 60-second resend cooldown, a three-sends-per-hour phone-number limit, and replay rejection after successful verification.

## Booking lifecycle

The booking flow is represented as a sequence of explicit application states rather than a single opaque operation:

```text
Service selection
      ↓
Vehicle + options
      ↓
Location
      ↓
Date/time slot
      ↓
Review
      ↓
Payment simulation
      ↓
Confirmation
      ↓
Assigned → On the way → In progress → Completed
```

Cancellation is handled as a separate transition where permitted by the current booking state.

## Scheduling consistency

Slot claiming uses Firestore transactions so concurrent clients do not blindly overwrite an already-claimed slot. The repository documents this as a race-safe resource-claiming mechanism.

## Payment boundary

Payment is deliberately a local simulation. The current client writes a payment record to Firestore and does not contact a real gateway or move money. A production implementation would move payment authorization and verification to a trusted backend and integrate a real gateway.

## Security boundaries

Firestore security rules are part of the application's authorization boundary. Client-side validation is treated as a UX aid, not as the sole security mechanism.

The repository must never contain service-account private keys, production secrets, or real payment credentials.
