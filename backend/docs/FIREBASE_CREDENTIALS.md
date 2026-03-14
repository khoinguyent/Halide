# Firebase credentials for the backend

The backend uses **Firebase Admin SDK** to verify ID tokens sent by the app (`verify_id_token`). To do that, it needs credentials. You can use either a **service account** or **Application Default Credentials**.

---

## Option 1: Service account (recommended for local + production)

### 1. Get the service account JSON

1. Open [Firebase Console](https://console.firebase.google.com) → your project (**halide-ae374**).
2. Click the gear icon → **Project settings**.
3. Go to the **Service accounts** tab.
4. Click **Generate new private key** (or use an existing service account and **Manage service account permissions** in Google Cloud Console to create a key).
5. Save the downloaded JSON somewhere safe (e.g. `backend/keys/firebase-service-account.json`).  
   **Do not commit this file to git.** Add it to `.gitignore` (e.g. `keys/` or `*.json` under `backend/keys/`).

### 2. Point the backend at the JSON

**Option A – Use `FIREBASE_SERVICE_ACCOUNT_JSON` (path)**

In `backend/.env`:

```env
# Path to the JSON file (absolute or relative to where you run uvicorn)
FIREBASE_SERVICE_ACCOUNT_JSON=/path/to/backend/keys/firebase-service-account.json
```

If your backend code only supports a path string, keep it like this. If it supports **inline JSON**, see Option B.

**Option B – Use `GOOGLE_APPLICATION_CREDENTIALS` (env standard)**

In `backend/.env` or in your shell before starting the server:

```env
GOOGLE_APPLICATION_CREDENTIALS=/path/to/backend/keys/firebase-service-account.json
```

Then ensure the backend uses default credentials (e.g. `firebase_admin.initialize_app()` with no credential argument). Firebase Admin will automatically use `GOOGLE_APPLICATION_CREDENTIALS` when set.

**Option C – Inline JSON (if your app supports it)**

Some setups let you put the whole JSON in an env var. Only do this if your config explicitly supports it and you’re not logging env vars. Prefer a **file path** (Option A or B).

### 3. Turn off the dev-only bypass

In `backend/.env`:

```env
# Remove or set to false when using a real service account
DEV_SKIP_FIREBASE_VERIFY=false
```

Restart the backend; it will use the service account and verify tokens properly.

---

## Option 2: Application Default Credentials (ADC) – local only

Use this when you want to use your own Google user identity (e.g. on your laptop) instead of a key file.

### 1. Install Google Cloud CLI

- **macOS (Homebrew):** `brew install google-cloud-sdk`
- Or download: [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)

### 2. Log in and set default credentials

```bash
gcloud auth application-default login
```

A browser window opens; sign in with the Google account that has access to the Firebase project. This writes credentials to a well-known location (e.g. `~/.config/gcloud/application_default_credentials.json`).

### 3. Set the project (optional but recommended)

```bash
gcloud config set project halide-ae374
```

### 4. Run the backend

- Do **not** set `FIREBASE_SERVICE_ACCOUNT_JSON` (or leave it empty).
- Firebase Admin’s `initialize_app()` (with no credential) will use ADC.
- Set `DEV_SKIP_FIREBASE_VERIFY=false` so the backend uses real verification.

ADC is for **local development** only. In production (e.g. Cloud Run, GCE), use a **service account** (Option 1) or the environment’s built-in ADC (no key file on your machine).

---

## Quick reference

| Goal                         | What to do |
|-----------------------------|------------|
| Local dev, no key file      | `DEV_SKIP_FIREBASE_VERIFY=true` in `.env` (insecure; dev only). |
| Local dev, proper verification | Option 1 (service account path in `.env`) or Option 2 (ADC). |
| Production                  | Option 1: service account JSON path or ADC provided by the platform (e.g. GCP). Never use `DEV_SKIP_FIREBASE_VERIFY=true`. |

---

## Security

- Never commit the service account JSON to git. Add `backend/keys/` (or the path you use) to `.gitignore`.
- In production, prefer mounting the JSON as a file or using the runtime’s ADC (e.g. GCP Workload Identity) instead of env vars containing the raw JSON.
