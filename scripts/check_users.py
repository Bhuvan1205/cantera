import os, sys
backend_path = os.path.abspath("../lib/admin_console/backend")
sys.path.insert(0, backend_path)
os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:9090"
os.environ["GCLOUD_PROJECT"] = "canteen-app-e1c8d"
from config.firebase import db

docs = list(db.collection("Users").stream())
print(f"Users in emulator: {len(docs)}")
for d in docs:
    data = d.to_dict()
    print(f"  uid={d.id}")
    print(f"  all fields: {data}")
