# Secrets Management

## Keys currently used

- Cerebras API key
- Supermemory API key
- Firebase config (project/app identifiers)

## Production placement policy

- Cerebras API key: backend proxy only (never ship in client bundle).
- Supermemory API key: backend proxy only (never ship in client bundle).
- Firebase config: client-visible by design, but still inject via build config (`--dart-define`) for environment separation.
- Firebase Remote Config: use for non-secret runtime flags/tuning only; not a secret vault.

## Local developer setup

1. Do not add `.env` under `flutter/assets`.
2. Use Dart defines for local/dev:
   - Example:
     - `flutter run --dart-define=VYOMA_SUPERMEMORY_API_KEY=... --dart-define=VYOMA_CEREBRAS_API_KEY=...`
3. Prefer `--dart-define-from-file=<path>` with local untracked file for convenience.
4. Keep `.env` or define file untracked (`.gitignore` already covers `.env` and `.env.*`).
5. For production, move provider secrets to backend endpoints and call backend from app.
