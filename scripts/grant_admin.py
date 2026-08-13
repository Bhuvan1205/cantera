import os, sys
backend_path = os.path.abspath("../lib/admin_console/backend")
sys.path.insert(0, backend_path)
os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:9090"
os.environ["GCLOUD_PROJECT"] = "canteen-app-e1c8d"
from config.firebase import db

# The user's UID that just tried to login and got 403
target_uid = "ted3NxVvveVrNGsVk5dykk0EWA43"

doc_ref = db.collection("Users").document(target_uid)
doc = doc_ref.get()

if doc.exists:
    doc_ref.update({
        "isAdmin": True,
        "role": "admin"
    })
    print(f"Updated existing user {target_uid} to admin.")
else:
    doc_ref.set({
        "isAdmin": True,
        "role": "admin"
    })
    print(f"Created new admin user {target_uid}.")
