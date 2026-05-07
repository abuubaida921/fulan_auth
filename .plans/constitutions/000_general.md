# Constitution: General engineering rules

## scope

These rules apply to all implementation work in this repository.

## rules

1. Prefer small, reviewable changes that keep the app runnable at all times.
2. Match existing Dart/Flutter conventions and formatting (`dart format`).
3. Do not commit secrets (API keys, client secrets, tokens). All configuration must be injected via safe runtime configuration.
4. Avoid adding dependencies unless clearly justified and kept minimal.
5. Public APIs must be stable, typed, and tested.
6. Keep package internals under `lib/src/` and expose only via `lib/<package>.dart`.
7. Ensure `flutter analyze` and `flutter test` pass for both the app and any in-repo packages.

