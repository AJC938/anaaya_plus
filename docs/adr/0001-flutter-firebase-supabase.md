# ADR 0001: Flutter + Firebase + Supabase Edge Functions

- Status: Accepted
- Scope: Application architecture

## Context

The application needs a cross-platform mobile client, authenticated user sessions, persistent application data, push notifications, and a custom phone/OTP flow. The project also targets a zero-cost portfolio/test environment rather than a production deployment.

## Decision

Use Flutter/Dart for the mobile client, Firebase for authentication/session state, Firestore for application data and security rules, Firebase Cloud Messaging for push notifications, and Supabase Edge Functions for backend execution around the custom OTP workflow.

## Consequences

### Positive

- One Flutter codebase covers the primary mobile UI.
- Firebase Auth provides a well-defined session boundary after OTP verification.
- Firestore security rules provide a server-enforced authorization layer for application data.
- FCM integrates naturally with Firebase-backed booking events.
- Supabase Edge Functions provide isolated backend execution without requiring a separate server deployment.

### Trade-offs

- The application spans two backend platforms.
- Local development requires understanding both Firebase and Supabase configuration.
- The custom OTP path has more moving parts than native Firebase phone authentication.
- Production payment and SMS integrations would require additional trusted backend infrastructure.

## Rejected alternatives

### Firebase native phone authentication

Not selected for the portfolio's zero-cost test setup because the desired verification flow depends on external SMS behavior and device-integrity requirements.

### A single custom monolithic server

Not selected because it would add operational complexity without providing meaningful portfolio value for the current project scope.
