import sys
import os

# Provide dummy environment variables for Settings
os.environ["FIREBASE_PROJECT_ID"] = "test-project"
os.environ["S3_ENDPOINT"] = "http://localhost:9000"
os.environ["S3_ACCESS_KEY"] = "access"
os.environ["S3_SECRET_KEY"] = "secret"
os.environ["S3_BUCKET_NAME"] = "bucket"

from fastapi.testclient import TestClient

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app.main import app

client = TestClient(app)

def test_get_providers():
    print("Testing GET /api/v1/storage/providers...")
    response = client.get("/api/v1/storage/providers")
    
    if response.status_code != 200:
        print(f"FAILED: Status code {response.status_code}")
        print(response.text)
        sys.exit(1)
        
    data = response.json()
    if len(data) != 5:
        print(f"FAILED: Expected 5 providers, got {len(data)}")
        sys.exit(1)
    
    providers = {p['id']: p for p in data}
    expected_ids = ['icloud', 'gdrive', 'onedrive', 'nas', 'smb']
    
    for eid in expected_ids:
        if eid not in providers:
            print(f"FAILED: Provider {eid} missing")
            sys.exit(1)
            
    # Check specific metadata
    if providers['icloud']['auth_type'] != 'none':
        print(f"FAILED: iCloud auth_type should be 'none', got {providers['icloud']['auth_type']}")
        sys.exit(1)
        
    if providers['gdrive']['auth_type'] != 'oauth':
        print(f"FAILED: Google Drive auth_type should be 'oauth', got {providers['gdrive']['auth_type']}")
        sys.exit(1)

    if providers['nas']['auth_type'] != 'credentials':
        print(f"FAILED: NAS auth_type should be 'credentials', got {providers['nas']['auth_type']}")
        sys.exit(1)
    
    print("SUCCESS: All providers found with correct metadata.")
    for p in data:
        print(f"  - {p['name']} ({p['id']}): auth_type={p['auth_type']}, icon={p['icon']}")

if __name__ == "__main__":
    test_get_providers()
