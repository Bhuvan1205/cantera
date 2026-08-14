import firebase_admin
from firebase_admin import credentials, firestore
firebase_admin.initialize_app()
db = firestore.client()
docs = db.collection('Menu').get()
print('Menu documents found:', len(docs))
for doc in docs[:5]:
    print(f'Read document: {doc.id} - {doc.to_dict().get("name", "Unknown")}')
