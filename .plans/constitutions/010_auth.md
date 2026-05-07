# Constitution: Auth feature rules

## scope

These rules apply to the `fulan` auth feature and its package.

## rules

1. Any long-lived credentials (refresh tokens, session tokens) must be stored using platform-backed secure storage.
2. Expose an interface-first design (`AuthRepository`) so the backend/provider can be swapped without changing the app.
3. Model errors explicitly (e.g., invalid credentials, network error, server error, unknown).
4. Provide a minimal UI surface that the host app can integrate without coupling to internal implementation details.

