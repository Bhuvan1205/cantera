import firebase_admin
from firebase_admin import credentials, firestore
import json
firebase_admin.initialize_app()
db = firestore.client()
orders = db.collection('Orders').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(1).get()
if not orders:
    print('No orders found')
else:
    order = orders[0]
    print('Order ID:', order.id)
    print('Order Data:', json.dumps({k: str(v) if k == 'createdAt' else v for k, v in order.to_dict().items()}, indent=2))
    tokens = db.collection('Orders').document(order.id).collection('tokens').get()
    print('Tokens count:', len(tokens))
    for token in tokens:
        print(f'Token ID: {token.id}')
        print(f'Token Data: {json.dumps({k: str(v) for k,v in token.to_dict().items()}, indent=2)}')
