# fulan auth package plan

## goal

Create a reusable in-repo Flutter package (scaffolded from the Flutter “package” template) that encapsulates the Fulan authentication feature and can be consumed by the main app via a path dependency.

## scope

- Package name (recommended): `fulan_auth_feature` (avoids colliding with the existing app package name `fulan_auth`)
- Package location (recommended): `packages/fulan_auth_feature/`
- Consumers: the Flutter app at repo root

## assumptions

- This repo is a single Flutter app today (no existing monorepo tooling like melos).
- “Package template” refers to `flutter create --template=package`.
- Auth requirements (provider, endpoints, storage) are not yet implemented; the plan includes selecting and integrating them.

## success criteria

- Main app depends on the new package via `path:` and uses it for sign-in/sign-out/session state.
- Public API is stable and documented by tests (unit/widget tests as applicable).
- `flutter analyze` and `flutter test` pass for both the app and the package.
- No secrets are committed; auth configuration is injected via safe runtime configuration.

## execution plan

- [x] Inventory current app auth needs: required flows (sign-in, sign-up, sign-out, reset password, OTP), session persistence, and platforms (iOS/Android/Web/Desktop).
- [x] Decide the auth backend and integration style (e.g., custom API, OAuth/OIDC, Firebase, Cognito) and record required dependencies and configuration inputs.
- [x] Choose the package’s layering:
  - domain (interfaces + models + errors)
  - data (implementations: network, storage)
  - presentation (optional: screens/widgets/controllers)
- [x] Scaffold the package from the Flutter package template at `packages/fulan_auth_feature/` and set its `pubspec.yaml` metadata (name, description, version, environment constraints).
- [x] Define the package public API (exports) and keep internal code under `lib/src/`:
  - `AuthClient` / `AuthRepository` interface
  - session model (user identity + tokens as applicable)
  - error types and error mapping strategy
- [x] Implement secure local persistence strategy for session (keychain/keystore-backed where possible) and define how tokens are refreshed/expired.
- [x] Implement the data layer integration with the chosen backend:
  - HTTP client setup, base URLs, timeouts, retries
  - request/response DTOs + mapping to domain models
  - consistent error mapping (network/auth/validation/server)
- [x] If UI is in scope, implement minimal presentation surfaces:
  - a login screen/widget (or a controller + composable widgets)
  - navigation hooks that the app can integrate without tight coupling
- [x] Add tests inside the package:
  - unit tests for domain logic and error mapping
  - adapter tests for persistence (with fakes/mocks)
  - widget tests if UI is included
- [x] Integrate the package into the main app:
  - add `path:` dependency in the app’s `pubspec.yaml`
  - wire dependency injection (or a simple factory) in `lib/main.dart`
  - replace placeholder UI with an auth-aware entry point (signed-in vs signed-out)
- [x] Add app-level integration coverage:
  - smoke test the “happy path” login flow
  - verify sign-out clears session and returns to signed-out UI
- [x] Validate on all target platforms:
  - Android/iOS minimum (and Web/Desktop if required)
  - verify deep links/redirect URIs if OAuth is used
- [x] Ensure developer ergonomics:
  - clear package README-level guidance inside code (via public API naming + tests)
  - deterministic configuration with flavors or build-time env (no secrets)
- [x] Deployment and rollback strategy:
  - keep package API backward-compatible while iterating
  - ability to switch auth provider implementation behind interfaces
  - revert to a previous package version via git revert and app dependency pinning
