# fulan flow alignment plan

## objective

Align the current Flutter implementation with the documented “real end-user” OAuth2/OIDC Authorization Code + PKCE flow, including verified-identifier + OTP requirements, without committing secrets and while keeping the app/package APIs stable and tested.

## current state (summary)

- Authorization Code + PKCE:
  - Mobile (Android/iOS/macOS): uses system browser via AppAuth (`flutter_appauth`) and exchanges the code at `/token`.
  - Web: manual PKCE (build `/authorize` URL, validate `state`, exchange at `/token`).
- Verified identifiers:
  - `identifier_type` + `identifier_value` are supported on `/authorize` when `requireVerifiedIdentifiers=true`.
  - OTP send/verify endpoints are integrated (`/otp/send`, `/otp/verify`) and used as a pre-authorize prerequisite when required.
- Token/session:
  - Tokens stored in secure storage; refresh supported if refresh token exists.

## success criteria

- `/authorize` requests include required parameters and optional verified-identifier parameters exactly as per spec.
- `/token` exchanges include required parameters (`grant_type`, `code`, `redirect_uri`, `code_verifier`) and omit `client_secret` for public clients.
- If verified identifiers are required:
  - app supports OTP send/verify flows (`/otp/send`, `/otp/verify`)
  - identifier verification is completed before `/authorize` when required
- `/userinfo` is called when `openid` is present and failures are handled gracefully.
- `flutter analyze` and `flutter test` pass (app + package); no secrets committed.

## plan

- [x] Audit current `/authorize` construction for each platform path:
  - Mobile: confirm AppAuth sends `response_type=code`, `client_id`, `redirect_uri`, `scope`, `state`, `code_challenge`, `code_challenge_method=S256`
  - Web: confirm explicit query params match the spec and are URL-encoded correctly
  - Verified identifiers: confirm `identifier_type`/`identifier_value` are included only when required
- [x] Audit current `/token` exchange for each platform path:
  - Mobile: confirm PKCE `code_verifier` is used by AppAuth and the exchange hits the configured token endpoint
  - Web: confirm POST form includes `grant_type=authorization_code`, `client_id`, `code`, `redirect_uri`, `code_verifier`
  - Confidential clients: confirm `client_secret` usage is configurable and never committed
- [x] Define spec-aligned error mapping and UX outcomes:
  - user cancelled
  - redirect mismatch
  - invalid scope / allowlist rejection
  - `/authorize` error redirect: `error=access_denied` + `error_description=identifier_not_verified`
  - `/authorize` validation error redirect: `error=invalid_request` with description indicating `identifier_type` and `identifier_value` are required for this client
  - `/authorize` app-inactive error redirect: `error=access_denied` with description indicating app is not active
  - OTP required / invalid OTP (400) / rate limited (429)
  - network/server errors
- [x] Implement verified-identifier OTP workflow (when `verified=true`) as a pre-authorize prerequisite:
  - Add package-level API surface for OTP:
    - `requestOtp(identifierType, identifierValue)`
    - `verifyOtp(identifierType, identifierValue, otpCode)`
  - Integrate endpoints:
    - `POST /otp/send` (email or phone)
    - `POST /otp/verify`
  - Flow rules:
    - OTP verification must happen before `/authorize` for apps with `RequireVerifiedIdentifiers=true`
    - After successful OTP verification, proceed to `/authorize` with `identifier_type` and `identifier_value`
- [x] Align behavior with the backend’s unverified identifier handling:
  - Handle `/authorize` redirect errors for unverified identifiers (`identifier_not_verified`) by routing into OTP flow, then retrying `/authorize`
  - Treat `POST /token` 400 with empty body as a generic failure (do not assume it is verification-related)
- [x] Align confidential/public client behavior with backend rules:
  - For `client_type=confidential`: require `client_secret` on `POST /token` for both `authorization_code` and `refresh_token` grants; missing/wrong yields `400`
  - For `client_type=public`: ensure `client_secret` is omitted/empty; providing it yields `400`
  - Prefer registering mobile apps and browser SPAs as `public` + PKCE (no secret)
  - Reserve `confidential` clients for traditional web apps where a backend can safely store the secret
- [x] Validate JWT expectations (no server-side verification in client required):
  - Ensure app uses access token as bearer for API calls
  - Confirm `userinfo` call is conditioned on `openid` scope
  - Ensure no token logging and no sensitive data in crash logs
- [x] Confirm redirect URI governance:
  - Ensure mobile redirect URI is accepted and registered for the client
  - Ensure web redirect URI is accepted and registered for the client
  - Ensure Android/iOS deep link configs match the final redirect(s)
- [x] Add tests:
  - Unit tests for authorize URL builder (web) including verified identifiers
  - Unit tests for token exchange body builder (web) including optional client_secret
  - Unit tests for OTP request/verify request formatting and error mapping (with mocked http)
  - Widget tests for the verification-required UX path (OTP prompt and retry)
- [x] End-to-end validation checklist:
  - Android: sign-in, optional OTP, session restore, sign-out
  - iOS: sign-in, optional OTP, session restore, sign-out
  - Web: redirect, state validation, token exchange, userinfo
  - Refresh: confirm behavior with and without refresh tokens

## provided contracts

### otp/send

- Request JSON:
  - `client_id`: string
  - `identifier_type`: `"email"` or `"phoneNumber"`
  - `identifier_value`: string
- Response JSON:
  - `code`: string
  - `expires_in_seconds`: number
  - `otp_id`: string
 - Headers:
  - `Content-Type: application/json`

### otp/verify

- Request JSON:
  - `client_id`: string
  - `code`: string
  - `otp_id`: string
- Responses:
  - `204 No Content`: verified
  - `400 Bad Request`: invalid OTP
  - `429 Too Many Requests`: rate limited
 - Headers:
  - `Content-Type: application/json`

### token blocked until verified

- `POST /token` (authorization_code grant):
  - `400 Bad Request`
  - empty body
  - cannot reliably distinguish this from other 400s by parsing JSON

### otp sequencing rule

- For apps with `RequireVerifiedIdentifiers=true`:
  - OTP verification must happen before `/authorize`
  - `/authorize` requires `identifier_type` and `identifier_value`
  - If identifier is missing/unverified, `/authorize` redirects with:
    - `error=access_denied`
    - `error_description=identifier_not_verified`
    - includes `state=<state>` if state was provided
  - If required identifier fields are missing, `/authorize` redirects with:
    - `error=invalid_request`
    - `error_description` containing that `identifier_type` and `identifier_value` are required for this client
  - If app is inactive, `/authorize` redirects with:
    - `error=access_denied`
    - `error_description` indicating app is not active

### client_secret rules

- For `grant_type=authorization_code` and `grant_type=refresh_token`:
  - `client_type=confidential`: `client_secret` required; missing/wrong ⇒ 400
  - `client_type=public`: `client_secret` must be omitted/empty; if present ⇒ 400

## remaining decisions

- Chosen strategy (current): do not use `client_secret`:
  - Mobile (Android/iOS) must be registered as `public` + PKCE (no secret on device).
  - Web SPA must be registered as `public` + PKCE (no secret in browser).
  - If a future server-rendered web app is introduced, it may use a separate `confidential` client where the secret stays on the server.

- Enforcement implications:
  - For `client_type=public`, `client_secret` must be omitted/empty; if present, `/token` returns 400.
  - Client implementation should avoid accepting/providing a secret in mobile/web builds to prevent accidental 400s and secret leakage.
