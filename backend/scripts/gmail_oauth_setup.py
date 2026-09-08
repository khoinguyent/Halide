#!/usr/bin/env python3
"""
One-time OAuth setup: get a Gmail refresh token for Halide transactional email.

Uses the same GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET as Drive (Web client).

Prerequisites (Google Cloud Console → APIs & Services):
  1. Enable "Gmail API" for the project.
  2. OAuth consent screen: add scope
       https://www.googleapis.com/auth/gmail.send
     (and add halide.app.notify@gmail.com as a test user if app is in Testing).
  3. Credentials → your Web client → Authorized redirect URIs → add:
       http://localhost:8090/

Run from backend/ (with venv activated):

    python -m scripts.gmail_oauth_setup

Sign in as halide.app.notify@gmail.com, allow send permission, then paste
GMAIL_REFRESH_TOKEN into .env / .env.staging / .env.prod.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# Allow `python -m scripts.gmail_oauth_setup` from backend/
_BACKEND = Path(__file__).resolve().parent.parent
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

os.chdir(_BACKEND)

from google_auth_oauthlib.flow import InstalledAppFlow

from app.core.config import settings

GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"
REDIRECT_PORT = 8090


def main() -> int:
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        print("Missing GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET in backend/.env")
        return 1

    print("Sign in as the Halide notify mailbox (e.g. halide.app.notify@gmail.com).")
    print(f"Ensure redirect URI http://localhost:{REDIRECT_PORT}/ is on the OAuth client.")
    print()

    client_config = {
        "installed": {
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": [f"http://localhost:{REDIRECT_PORT}/"],
        }
    }
    flow = InstalledAppFlow.from_client_config(
        client_config,
        scopes=[GMAIL_SEND_SCOPE],
    )
    creds = flow.run_local_server(
        port=REDIRECT_PORT,
        access_type="offline",
        prompt="consent",  # force refresh_token even if previously authorized
    )

    if not creds.refresh_token:
        print("No refresh_token returned. Revoke app access at")
        print("  https://myaccount.google.com/permissions")
        print("then run this script again with prompt=consent.")
        return 1

    print()
    print("Add this to .env, .env.staging, and .env.prod:")
    print()
    print(f"GMAIL_REFRESH_TOKEN={creds.refresh_token}")
    if settings.EMAIL_USER:
        print(f"EMAIL_USER={settings.EMAIL_USER}")
    print()
    print("Also set EMAIL_FROM_ADDRESS / EMAIL_FROM_NAME if not already present.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
