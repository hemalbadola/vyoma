# Secrets & CI — what must never be in git

## Never commit

| Secret | Where it lives |
|--------|----------------|
| `NVIDIA_API_KEYS`, `GEMINI_API_KEYS` | Heroku env only |
| `RAZORPAY_KEY_SECRET` | Heroku / Firebase Functions |
| `FIREBASE_PRIVATE_KEY` / service account JSON | Heroku, GitHub `FIREBASE_SERVICE_ACCOUNT` |
| `VYOMA_DESKTOP_CLIENT_SECRET` | Local `.env` / `--dart-define` |
| `VYOMA_*_API_KEYS` (LLM) | Local `.env` only; release APK uses Heroku proxy |
| `android/app/google-services.json` | Local + GitHub `GOOGLE_SERVICES_JSON_B64` |
| `vyoma-ui/.env.production` | Local + GitHub `FIREBASE_WEB_ENV_B64` |

## Safe to commit

- `lib/core/secrets.dart` — reads env only, no key literals
- `lib/firebase_options.dart` — Firebase **client** IDs (restrict in Firebase Console)
- `vyoma-ui/.env.example` — placeholders only
- `android/app/google-services.json.example` — placeholders only

## GitHub Actions secrets

```bash
# Android Firebase (from Firebase Console → Android app)
base64 -i android/app/google-services.json | gh secret set GOOGLE_SERVICES_JSON_B64 --repo hemalbadola/vyoma

# Web build (Firebase web config + public Razorpay key id)
base64 -i vyoma-ui/.env.production | gh secret set FIREBASE_WEB_ENV_B64 --repo hemalbadola/vyoma

# Already required
# FIREBASE_TOKEN — firebase login:ci
# FIREBASE_SERVICE_ACCOUNT — optional, for in-app version sync
```

## If keys were pushed by mistake

1. Remove the file from git (do not rely on delete alone — rotate the key).
2. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → restrict or rotate API keys.
3. Rotate Heroku / Razorpay / LLM keys if those were ever committed.

Public repo: assume anything that was committed is known; rotate client keys if unsure.
