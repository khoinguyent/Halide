# Code security check & .gitignore for sensitive data

This document summarizes the security review and .gitignore rules used to avoid committing sensitive data.

---

## 1. What is ignored (do not commit)

These patterns are in `.gitignore` across the repo so they are **never** committed:

| Category | Patterns | Where |
|----------|----------|--------|
| **Environment** | `.env`, `.env.local`, `.env.*.local`, `.env.*.example.local` | Root, backend, frontend |
| **Key directories** | `**/keys/`, `**/secrets/`, `**/credentials/` | Root, backend, frontend |
| **Key/cert files** | `*.pem`, `*.p12`, `*.p8` | Root, backend, frontend |
| **Firebase service account** | `*-service-account*.json`, `*firebase*adminsdk*.json`, `*adminsdk*.json` | Root, backend |
| **Android signing** | `**/*.keystore`, `**/*.jks`, `key.properties` | frontend/android |
| **Backend** | `/data/`, `/venv/`, `__pycache__/`, `*.pyc` | backend |

**Important:** Never remove these from .gitignore or force-add files matching these patterns.

---

## 2. Files currently tracked (intentional or low risk)

| File | Risk | Note |
|------|------|------|
| `backend/.env.example` | None | Template only; no real secrets. |
| `frontend/android/app/google-services.json` | Low | Firebase **client** config (API key, project id). Public by design; protect with Firebase Security Rules and API restrictions. Optional: add to .gitignore and inject in CI if you prefer. |
| `frontend/ios/Runner/GoogleService-Info.plist` | Low | Same as above for iOS. |
| `frontend/lib/firebase_options.dart` | Low | FlutterFire-generated client config (API keys). Same as above. |

No hardcoded passwords, server-side API keys, or private keys were found in source code.

---

## 3. Developer checklist

- [ ] Do **not** commit `.env` or any file under `keys/`, `secrets/`, or `credentials/`.
- [ ] Do **not** commit Firebase **service account** JSON (server-side key). Use `backend/keys/` (gitignored) and set `FIREBASE_SERVICE_ACCOUNT_JSON` in `.env`.
- [ ] Do **not** commit Android keystores (`.keystore`, `.jks`) or `key.properties`; frontend/android/.gitignore already excludes them.
- [ ] Before pushing, run:  
  `git status` and `git diff --cached` and confirm no `.env`, `keys/`, or key files are staged.
- [ ] In CI/deploy, inject secrets via environment or a secret manager; never put production secrets in the repo.

---

## 4. Verify nothing sensitive is tracked

From the repo root:

```bash
# List files that look sensitive (should be empty or only .env.example / client configs)
git ls-files | grep -iE '\.env$|/keys/|\.pem|\.p12|service-account|adminsdk.*\.json|\.keystore|\.jks|key\.properties'

# Confirm backend service account is ignored
git check-ignore -v backend/keys/firebase-service-account.json
```

If `backend/keys/firebase-service-account.json` is not ignored, ensure `backend/.gitignore` contains `/keys/` and that the file has not been force-added.

---

## 5. .gitignore layout

- **Root (`.gitignore`):** Global env and key patterns so any new subproject is covered.
- **`backend/.gitignore`:** Backend-specific (venv, data, keys, env, certs).
- **`frontend/.gitignore`:** Frontend env and key/cert patterns.
- **`frontend/android/.gitignore`:** Keystores and `key.properties` (already present).

Adding new secrets (e.g. a new `secrets/` folder or `*.pem` usage) should be reflected in the appropriate .gitignore so they are never committed.
