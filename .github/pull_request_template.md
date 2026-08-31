## Summary

Describe the change and why it is needed.

## Scope

- [ ] Flutter UI
- [ ] Application/business logic
- [ ] Repository/data layer
- [ ] Firebase
- [ ] Supabase/Deno
- [ ] Tests
- [ ] Documentation
- [ ] CI/tooling

## Verification

Commands/results:

```text
flutter analyze
flutter test
```

For backend changes, include the relevant Deno test command and result.

## UI evidence

If the change affects the UI, add screenshots or a short description of the manual verification performed.

## Security / data impact

Describe any authentication, authorization, secret-handling, Firestore-rule, or data-model implications. Write `None` if not applicable.

## Checklist

- [ ] Tests added/updated where behavior changed
- [ ] Documentation updated where needed
- [ ] No secrets or credentials were committed
- [ ] Payment/SMS behavior is not described as production functionality
- [ ] `flutter analyze` passes without errors
