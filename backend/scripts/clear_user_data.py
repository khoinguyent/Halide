import os
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.db.session import SessionLocal, engine
from app.db import models

def clear_user_data():
    """
    Truncates all user-specific tables in the database.
    Preserves master data like FilmStock and Camera.
    """
    db = SessionLocal()
    try:
        print("Clearing user data...")
        
        # Order matters for foreign key constraints if not using CASCADE
        # However, TRUNCATE with CASCADE is safer and easier.
        tables_to_clear = [
            "images",
            "rolls",
            "storage_credentials",
            "user_lenses",
            "user_cameras",
            "purchase_history",
            "users",
        ]
        
        for table in tables_to_clear:
            print(f"Truncating table: {table}")
            db.execute(text(f'TRUNCATE TABLE "{table}" CASCADE;'))
        
        db.commit()
        print("User data cleared successfully.")
        
    except Exception as e:
        print(f"Error clearing user data: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    confirm = input("This will DELETE ALL USER DATA from the database. Type 'yes' to proceed: ")
    if confirm.lower() == 'yes':
        clear_user_data()
    else:
        print("Operation cancelled.")
