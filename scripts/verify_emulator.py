import os
import sys

backend_path = os.path.abspath("../lib/admin_console/backend")
sys.path.append(backend_path)
os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:9090"
os.environ["GCLOUD_PROJECT"] = "canteen-app-e1c8d"

from config.firebase import db

docs = list(db.collection("Menu").stream())
print(f"Total documents in emulator: {len(docs)}")
print("\nFirst 10 document IDs and names:")
for d in docs[:10]:
    data = d.to_dict()
    print(f"  {d.id:40s}  {data.get('name', '?')}")
