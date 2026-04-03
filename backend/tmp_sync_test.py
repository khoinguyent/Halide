import asyncio
from app.db.session import SessionLocal
from app.db.models.user import User
from app.api.v1.billing import sync_billing_status

async def run_sync():
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == 'khoinguyent@gmail.com').first()
        if not user:
            print('User not found in production DB')
            return
        
        print(f'Syncing user {user.email} (Current Tier: {user.subscription_tier})...')
        # We can look at the logs of the local backend if we want, OR just print here if we modify billing.py.
        # But I can just use a manual curl to see the raw data.
        import httpx
        from app.core.config import settings
        url = f"https://api.revenuecat.com/v2/projects/{settings.REVENUE_CAT_PROJECT_ID}/customers/{user.id}"
        headers = {"Authorization": f"Bearer {settings.REVENUE_CAT_SECRET_KEY}", "Content-Type": "application/json"}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=headers)
            print(f'RAW RC V2 RESPONSE: {resp.text}')
            
        result = await sync_billing_status(current_user=user, db=db)
        print(f'Result: {result}')
        
        # Verify final state
        db.refresh(user)
        print(f'Final Tier in DB: {user.subscription_tier}')
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(run_sync())
