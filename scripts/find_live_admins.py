import os
from google.cloud import firestore

# Remove emulator env vars so we connect to LIVE production Firestore
if "FIRESTORE_EMULATOR_HOST" in os.environ:
    del os.environ["FIRESTORE_EMULATOR_HOST"]
os.environ["GCLOUD_PROJECT"] = "canteen-app-e1c8d"

db = firestore.Client()
print("Querying LIVE Firestore for admins...")

users = db.collection("Users").where("isAdmin", "==", True).stream()
admin_count = 0
for u in users:
    data = u.to_dict()
    print(f"UID: {u.id}, Email: {data.get('email', 'unknown')}, Role: {data.get('role', 'unknown')}")
    admin_count += 1

print(f"Found {admin_count} admins in LIVE Firestore.")

users_role = db.collection("Users").where("role", "==", "admin").stream()
role_count = 0
for u in users_role:
    data = u.to_dict()
    print(f"UID: {u.id}, Email: {data.get('email', 'unknown')}, isAdmin: {data.get('isAdmin', 'unknown')}")
    role_count += 1

print(f"Found {role_count} admins via role field.")
