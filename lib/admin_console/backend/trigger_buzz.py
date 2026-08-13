import asyncio
from features.orders.repository import OrderRepository
from firebase_admin import firestore
import firebase_admin
from firebase_admin import credentials
import json

# Ensure initialized
if not firebase_admin._apps:
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, {'projectId': 'canteen-app-e1c8d'})

db = firestore.client()

async def manual_trigger():
    print("Manually triggering Canteen Buzz aggregation...")
    
    # 1. Fetch exactly 30 latest orders
    orders_snap = db.collection("Orders").order_by("timestamp", direction=firestore.Query.DESCENDING).limit(30).stream()
    
    frequencies = {}
    
    for doc in orders_snap:
        data = doc.to_dict()
        items = data.get("items", [])
        for item in items:
            name = item.get("name")
            if name:
                name = name.lower().strip()
                qty = item.get("quantity")
                try:
                    qty = int(qty) if qty is not None else 1
                except:
                    qty = 1
                frequencies[name] = frequencies.get(name, 0) + qty

    # 3. Sort and get Top 5
    sorted_items = sorted(frequencies.items(), key=lambda x: (-x[1], x[0]))[:5]
    top_items = [{"name": k, "count": v} for k, v in sorted_items]
    
    # 4. Write CanteenBuzz document
    doc_ref = db.collection("Recommendations").document("CanteenBuzz")
    doc_ref.set({
        "topItems": top_items,
        "updatedAt": firestore.SERVER_TIMESTAMP
    })
    
    print(f"Successfully updated CanteenBuzz with Top 5 items: {top_items}")

if __name__ == "__main__":
    asyncio.run(manual_trigger())
