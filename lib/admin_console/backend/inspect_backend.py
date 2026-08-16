import os, firebase_admin
from firebase_admin import firestore
from config.firebase import _detect_mode
print('GCLOUD_PROJECT:', os.environ.get('GCLOUD_PROJECT'))
print('GOOGLE_CLOUD_PROJECT:', os.environ.get('GOOGLE_CLOUD_PROJECT'))
mode, path = _detect_mode()
print('Firebase mode:', mode)
print('Firebase path:', path)
import config.firebase
db = firestore.client()
print('Project:', db.project)
collections = [c.id for c in db.collections()]
print('Collections:', collections)
if 'Menu' in collections:
  docs = db.collection('Menu').limit(2).get()
  print('Menu doc count (sample):', len(docs))
  for d in docs:
    print('  -', d.id, '=>', d.to_dict())
else:
  print('Menu collection NOT FOUND')

