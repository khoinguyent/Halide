# Remote branch API key / secrets scan

**Branch scanned:** `origin/develop`  
**Date:** 2026-03-14

## Summary

| Item | Status | Action |
|------|--------|--------|
| `backend/.env` tracked on remote | ⚠️ Risk | Remove from git tracking |
| Firebase client API keys in repo | ✅ Expected | Restrict in Firebase Console |
| Backend secrets (S3, DB, JWT) | ✅ Placeholders only | Keep in `.env`, never commit |
| Test/default secrets in code | ✅ Safe | `seed.py` / docker use test values only |

---

## 1. `backend/.env` is tracked on remote

**Finding:** `backend/.env` is committed on `origin/develop` (it appears in `git ls-tree`).  
**Content on remote:** Currently placeholder-style values (`user:password`, `your-access-key`, `your-secret-key`), plus real `FIREBASE_PROJECT_ID=halide-ae374`. No production DB or S3 secrets were found in the scanned content.

**Risk:** Any future real secrets added to `.env` would be pushed to the remote unless the file is untracked.

**Recommendation:** Remove `.env` from git tracking and keep it only in `.gitignore`:

```bash
git rm --cached backend/.env
git commit -m "chore: stop tracking backend/.env"
git push origin develop
```

If real secrets were ever committed in the past, rotate those secrets and consider removing them from history (e.g. `git filter-repo` or BFG).

---

## 2. Firebase client API keys (frontend)

**Finding:** Firebase client config is on the remote in:

- `frontend/lib/firebase_options.dart` — `apiKey` for iOS, Android, macOS
- `frontend/android/app/google-services.json` — `api_key` / `current_key`

**Assessment:** For mobile/client apps, these keys are meant to be in the app bundle. They are not server-side secrets. Security is enforced by:

- Firebase Security Rules (Firestore, Storage, etc.)
- Application restrictions / API key restrictions in Google Cloud Console

**Recommendation:** Ensure in [Firebase Console](https://console.firebase.google.com) → Project settings → Your apps:

- API key restrictions are set (e.g. limit to Android/iOS app IDs or bundle IDs).
- No unrestricted usage for production.

No change required in the repo for this; just verify restrictions.

---

## 3. Other files checked

- **backend/scripts/seed.py** — Uses env defaults like `test_key` / `test_secret`; safe for dev.
- **backend/docker-compose.yml** — `POSTGRES_PASSWORD: password`; acceptable for local dev only.
- **backend/app/core/config.py** — Reads from env; no hardcoded production secrets.
- **Auth/API usage** — Token/credential handling uses Firebase ID tokens or env-based config; no raw API keys leaked in logic.

---

## 4. Ongoing practice

- Keep **backend** secrets only in `backend/.env` (and ensure `.env` is in `.gitignore` and not tracked).
- Do **not** commit:
  - Real `DATABASE_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `SECRET_KEY`, or Firebase service account JSON.
- Use `.env.example` with placeholders; developers copy to `.env` and fill locally.
