# fulan oidc pkce integration plan

## goal

Implement Authorization Code + PKCE sign-in for Fulan in the Flutter app, using the cookbook flow: open system browser at `/authorize`, receive deep link callback with `code` + `state`, exchange at `/token`, and persist tokens securely.

## scope

- Platforms: Android + iOS + Web (macOS supported; Windows/Linux fallback to mock)
- Redirect strategy: custom scheme deep link (initially)
- Session: secure token storage + in-memory auth state stream for UI gating

## non-goals (for first iteration)

- Universal Links / App Links
- Full backend API client integration beyond attaching `Authorization: Bearer <access_token>`
- Advanced multi-account support

## assumptions

- Fulan acts as an OIDC provider with:
  - discovery: `https://fulan.dawahtours.com/.well-known/openid-configuration`
  - authorize: `https://fulan.dawahtours.com/authorize`
  - token: `https://fulan.dawahtours.com/token`
  - userinfo: `https://fulan.dawahtours.com/userinfo`
  - jwks: `https://fulan.dawahtours.com/.well-known/jwks.json`
- App is already configured with a custom scheme redirect and Android manifest placeholder for `appAuthRedirectScheme`.

## success criteria

- Tapping “Sign in” performs OIDC Authorization Code + PKCE and returns to the app.
- `state` is validated; mismatches fail sign-in safely.
- Tokens are stored in platform secure storage and loaded on app start.
- App can call `userinfo` (or decode id_token if provided) to show a signed-in user identity.
- `flutter analyze` and `flutter test` pass; no secrets committed.

## implementation approach options

### option A (recommended): use system browser + appauth

Use `flutter_appauth` to handle:
- opening the system browser
- generating PKCE internally
- handling the deep-link return (Android/iOS)
- exchanging `code` at `/token`

You still implement:
- session persistence (secure storage)
- user profile fetch (`userinfo`)
- UI auth gate + sign-out

### option B: manual pkce + browser + deep link

Implement the cookbook literally:
- generate and store `code_verifier` + `state`
- compute `code_challenge` (S256)
- build authorize URL and open browser
- parse callback deep link
- POST form to `/token`

This is more code and more ways to get edge cases wrong, but gives full control.

## execution plan

- [x] Confirm target platform support (Android/iOS/Web) and choose approach (Option A vs Option B).
- [x] Collect required configuration values (see “inputs needed”).
- [x] Normalize redirect URI strategy:
  - decide final custom scheme + host + path (exact redirect URI string)
  - ensure it is registered in the Fulan Portal (exact match)
- [x] Configure deep links:
  - Android: ensure intent-filter matches scheme/host/path and `appAuthRedirectScheme` placeholder is set
  - iOS: ensure URL scheme is declared and matches the redirect URI
- [x] Implement PKCE auth flow:
  - Option A: configure `flutter_appauth` with discovery URL, client_id, redirect_uri, scopes
  - Option B: implement PKCE + authorize URL + callback parsing + token exchange call
- [x] Implement token/session model:
  - access token, refresh token (if issued), expiry, id token (if issued), token type, scopes
  - explicit error mapping (network/auth/server/unknown)
- [x] Implement secure persistence:
  - store tokens and expiry in keychain/keystore-backed storage
  - on app start, load session and expose via a session stream
- [x] Implement user identity:
  - fetch from `userinfo_endpoint` using access token
  - handle missing `email` gracefully (fall back to `sub`)
- [x] Implement refresh + logout:
  - refresh when access token expires (or near expiry) using refresh token (if provided)
  - logout clears stored tokens and any pending login state
- [x] Wire UI:
  - “Sign in” triggers the flow
  - auth gate switches between signed-out (login) and signed-in screens
- [x] Testing & validation:
  - unit tests for state validation + storage roundtrip
  - happy-path sign-in on Android + iOS
  - negative cases: state mismatch, user cancels, token endpoint errors
- [x] Security review checklist:
  - no secrets in repo
  - no tokens logged
  - redirect URI exact match
  - state validation enforced

## inputs needed

- `client_id` for the mobile app (from the Portal)
- Exact `redirect_uri` registered in the Portal (string), e.g. `com.fulan.dawahtours.fulan_auth://oauthredirect`
- Allowed `scopes` for this client (minimum: `openid`; commonly: `openid profile email offline_access`)
- Whether refresh tokens are enabled for this client (and if `offline_access` is required)
- Expected user identity fields from `userinfo` (is `email` always present? or only `sub`?)
- Any special requirements:
  - `audience` parameter needed at `/authorize` or `/token`
  - required `prompt`, `login_hint`, or extra params
  - token endpoint auth method (public client w/ PKCE vs confidential)
- Target platforms: Android only, iOS only, or both (and whether Web is required)
