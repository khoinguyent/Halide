import strawberry
from strawberry.types import Info
from sqlalchemy.orm import Session
from database import SessionLocal
import models
from graphql_schema import schema, Query, Context

def test_user_dashboard():
    db = SessionLocal()
    try:
        user = db.query(models.User).filter(models.User.id == "test_user_123").first()
        if not user:
            print("Test user not found. Run seed_data.py first.")
            return

        # Mock Strawberry Info/Context
        class MockInfo:
            def __init__(self, context):
                self.context = context

        context = Context(db=db, user=user)
        info = MockInfo(context=context)

        query = Query()
        dashboard = query.user_dashboard(info)

        print(f"User: {dashboard.user.display_name}")
        print(f"Cameras: {len(dashboard.cameras)}")
        print(f"Recent Rolls: {len(dashboard.recent_rolls)}")

        assert dashboard.user.id == "test_user_123"
        assert len(dashboard.cameras) >= 1
        assert len(dashboard.recent_rolls) >= 5
        
        print("UserDashboard resolver verification SUCCESS!")

    except Exception as e:
        print(f"Verification FAILED: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_user_dashboard()
