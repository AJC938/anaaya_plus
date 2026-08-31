# Security Policy

## Scope

Anaaya Plus is a portfolio/test application and is not presented as a production security baseline. Security-sensitive behavior is nevertheless documented and tested where practical.

## Reporting a vulnerability

Please do not publish credentials, tokens, service-account keys, OTPs, or other sensitive material in a public issue.

For a genuine security concern, contact the repository owner privately through GitHub before opening a public issue. Include a concise description, affected component/path, reproduction steps, and potential impact.

## Important project limitations

- Payment is a local client-side simulation and is not suitable for real financial transactions.
- OTP delivery is configured around test-mode SMS behavior and is not production SMS infrastructure.
- Firebase/Supabase credentials and service-account secrets must never be committed.
- Local build artifacts, generated files, and debug recordings should remain ignored by Git.
