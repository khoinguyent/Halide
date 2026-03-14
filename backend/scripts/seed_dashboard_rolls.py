#!/usr/bin/env python3
"""Seed DB with exactly 2 Shooting, 2 At Lab, 1 Scanned (5 images). Run from backend/ with .env set.
Usage: python scripts/seed_dashboard_rolls.py [firebase_user_id]
If no user_id given, uses first user in DB or creates a test user.
"""
import os
import sys

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db.session import SessionLocal
from app.services.seed_service import SeedService

def main():
    user_id = (sys.argv[1] if len(sys.argv) > 1 else None)
    db = SessionLocal()
    try:
        if not user_id:
            from app.db.models.user import User
            u = db.query(User).first()
            if not u:
                user_id = "seed_test_user"
                print(f"No user in DB. Create one by logging in from the app, then run: python scripts/seed_dashboard_rolls.py <your_firebase_uid>")
                print(f"Or we'll create test user: {user_id}")
            else:
                user_id = u.id
                print(f"Using first user: {user_id}")
        SeedService.seed_dashboard_rolls(db, user_id)
        print(f"Done. Seeded 2 Shooting, 2 At Lab, 1 Scanned (5 images) for user {user_id}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
