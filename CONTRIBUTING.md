# Contributing to Anaaya Plus

Thank you for your interest in Anaaya Plus.

This repository is primarily a personal software-engineering portfolio project, but the project follows a professional contribution workflow so that changes remain reviewable and maintainable.

## Development workflow

1. Create a focused branch from `main`.
2. Make one coherent change per branch.
3. Run formatting, static analysis, and the relevant tests locally.
4. Update documentation when behavior, architecture, or public setup instructions change.
5. Open a pull request with a concise description of the problem, implementation, and verification.

## Local verification

```bash
flutter pub get
flutter analyze
flutter test
```

For Supabase/Deno changes, also run the relevant tests under `supabase/functions/_shared/`.

## Commit style

Use concise, imperative commit subjects. Conventional Commit prefixes are recommended:

- `feat:` new functionality
- `fix:` bug fix
- `refactor:` internal restructuring without behavior change
- `test:` tests only
- `docs:` documentation only
- `chore:` tooling or maintenance
- `ci:` continuous-integration changes

## Pull requests

A good pull request should:

- Explain why the change is needed.
- Identify the main files or layers affected.
- Include test/verification results.
- Include screenshots or recordings for meaningful UI changes when practical.
- Explicitly call out security, data-model, or authentication implications.

## Scope

Do not add production claims to the documentation unless the corresponding implementation and verification exist. In particular, the current project intentionally uses simulated payment and test-mode SMS flows.
