import requests
import os
import json

base_url = "http://localhost:8000/api/v1"

# We assume a test user exists or we can get an admin token. 
# For now, let's just make the request and see if we get a 401 or expected response schema error.
# We'll use a dummy token "test_uid_123" which might work if auth is mocked or we can observe the logging.

headers = {
    "Authorization": "Bearer test_uid_123"
}

# Create a dummy image
with open("test_avatar.jpg", "wb") as f:
    f.write(os.urandom(1024))

files = {
    'avatar': ('test_avatar.jpg', open('test_avatar.jpg', 'rb'), 'image/jpeg')
}

data = {
    'name': 'Test User',
    'professional_nickname': 'The Tester',
    'bio': 'I am testing the new profile endpoint.'
}

try:
    print("Sending PATCH request to /api/v1/user/profile...")
    response = requests.patch(f"{base_url}/user/profile", headers=headers, data=data, files=files)
    
    print(f"Status Code: {response.status_code}")
    try:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except:
        print(f"Response text: {response.text}")
        
finally:
    # Cleanup
    if os.path.exists("test_avatar.jpg"):
        os.remove("test_avatar.jpg")
