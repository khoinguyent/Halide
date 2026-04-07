#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -x .venv/bin/python ]]; then
  echo "Create the venv first: python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
  exit 1
fi
exec .venv/bin/python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
