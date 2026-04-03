from app.db.session import SessionLocal
from app.db.models.user import User, PurchaseHistory
import json

def check_user_subscriptions():
    db = SessionLocal()
    try:
        # Get all users to see their tiers
        users = db.query(User).all()
        print(f"--- Users ({len(users)}) ---")
        for u in users:
            print(f"UID: {u.id}, Email: {u.email}, Tier: {u.subscription_tier}, Limit: {u.storage_limit_bytes}")
        
        # Get recent purchase history
        history = db.query(PurchaseHistory).order_by(PurchaseHistory.created_at.desc()).limit(20).all()
        print("\n--- Recent Purchase History ---")
        for h in history:
            print(f"ID: {h.id}, UID: {h.user_id}, Event: {h.event_type}, Product: {h.product_id}, Time: {h.created_at}")
            # print(f"  Payload: {h.payload[:100]}...")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_user_subscriptions()
