from app.db.session import SessionLocal
from app.db import models
from app.services import roll_service
from uuid import UUID

def verify_shot_log():
    db = SessionLocal()
    try:
        # Find a shooting roll for test_user_123
        roll = db.query(models.Roll).filter(
            models.Roll.user_id == "test_user_123",
            models.Roll.status == "shooting"
        ).first()

        if not roll:
            print("No shooting roll found for test_user_123. Run seed_data.py first.")
            return

        print(f"Testing on Roll: {roll.id} ({roll.title})")
        
        # Test logging a shot
        shot = roll_service.log_shot(
            db=db,
            roll_id=str(roll.id),
            aperture=1.4,
            shutter_speed="1/500",
            lat=10.762622,
            lng=106.660172,
            user_id="test_user_123"
        )
        
        print(f"Shot logged successfully. ID: {shot.id}")
        assert shot.aperture == 1.4
        assert shot.shutter_speed == "1/500"
        assert shot.image_url is None
        
        # Verify it appears in dashboard
        dashboard = roll_service.get_roll_for_dashboard_by_id(db, str(roll.id), "test_user_123")
        print(f"Dashboard shots count: {len(dashboard.shots)}")
        
        found = False
        for s in dashboard.shots:
            if str(s.id) == str(shot.id):
                found = True
                print(f"Verified shot in dashboard: f/{s.aperture}, {s.shutter_speed}, at {s.location_lat}, {s.location_lng}")
                break
        
        assert found, "Shot not found in dashboard response"
        print("Backend Shot Logging Verification SUCCESS!")

    except Exception as e:
        print(f"Verification FAILED: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    verify_shot_log()
