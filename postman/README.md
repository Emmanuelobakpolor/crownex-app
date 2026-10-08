# CrownEx – Postman Documentation

This folder contains a complete Postman collection covering the CrownEx Django backend: the mobile-app-facing API **and** the Admin Panel API used by `crownex-admin`.

## Files

- `CrownEx.postman_collection.json` — 86 requests across 9 top-level folders (Auth, Profile, Wallet, VTU, Gift Cards, Crypto, KYC, Virtual Cards, Admin Panel with 9 sub-folders).
- `CrownEx-Local.postman_environment.json` — matching environment with `base_url` pointed at `http://127.0.0.1:8000` and every variable the requests reference, pre-wired.

## Import

1. Postman → **Import** → drag in both JSON files (or File → Import).
2. Select the **CrownEx – Local** environment in the top-right environment dropdown.
3. If testing against Railway instead of local, edit `base_url` in the environment (or duplicate the environment for "Staging"/"Production").

## Auth flow (do this first)

**User side:**
1. Run `Auth → Register` → `Verify OTP` (grab the OTP from the Django console log in dev, since `EMAIL_BACKEND` defaults to console) → `Complete Profile`. This last call **auto-saves `access_token`/`refresh_token`** into the environment via a test script.
2. Alternatively, if a user already exists, just run `Auth → Login`.
3. Run `Auth → Set Transaction PIN` once — most money-moving endpoints require it.

**Admin side (separate token pair, so you can hold both sessions at once):**
1. Set `admin_registration_secret` in the environment to match `ADMIN_REGISTRATION_SECRET` in the backend's `.env`.
2. Run `Admin Panel → Admin – Auth → Create Admin Account (bootstrap)` once to create the first staff account.
3. Run `Admin – Auth → Admin Login` — auto-saves `admin_access_token`/`admin_refresh_token`.

Every other request in the collection is pre-configured with the right bearer token (user vs. admin) via each request's **Authorization** tab, so once the two logins above have run, everything else just works.

## Notes

- **Transaction PIN**: sent as `pin` or `transaction_pin` depending on endpoint — each request body already uses the right field name.
- **File uploads** (KYC selfie/ID, crypto payment proof, profile picture): those requests use `multipart/form-data` with empty file fields — click into the body tab and select a real file before sending.
- **Webhooks** (Flutterwave, PluginNG, Reloadly, Quidax): included for reference/replay, but they're called *by* those providers, not by the app. Each needs a secret/signature that must match your backend's `.env` — the Quidax one requires a `quidax-signature: t=<timestamp>,s=<HMAC-SHA256 of "<timestamp>.<body>">` header you'd need to compute outside Postman.
- **Public, no-auth endpoints**: `GET /api/crypto/prices/`, `GET /api/crypto/fees/`, and the webhook receivers above.
- Error responses follow `{ "detail": "...", "code": "..." }` for business-logic errors, or DRF's standard `{ "field": ["message"] }` for validation errors (HTTP 400).

Full endpoint-by-endpoint description, required fields, and behavior notes are in each request's description panel inside Postman — this file is just the quick-start.
