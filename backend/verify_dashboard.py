from app.db.session import SessionLocal
from app.db import models
from app.graphql.schema import Query

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

        context = {"db": db, "user": user}
        info = MockInfo(context=context)

        from app.graphql.resolvers.dashboard_resolvers import resolve_user_dashboard
        dashboard = resolve_user_dashboard(None, info)

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
